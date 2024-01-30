//
//  Service.swift
//  Altid
//
//  Created by halfwit on 2024-01-08.
//

import SwiftUI
import Network
import Observation

@Observable
class Service: Hashable, Identifiable {
    private var name: String
    var buffers: [Buffer]
    var current: Buffer?
    var session: PeerConnection?
    var error: Data?
    var working: Bool = false

    enum CodingKeys: CodingKey {
        case browser
        case connection
    }
    
    var displayName: String {
        return name
    }

    var connected: Bool {
        return session?.initiatedConnection ?? false
    }

    init(name: String) {
        self.buffers = [Buffer]()
        self.name = name
    }
    
    static func == (lhs: Service, rhs: Service) -> Bool {
        return lhs.displayName == rhs.displayName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    func connect() {
        self.session = PeerConnection(name: self.name, delegate: self)
        self.session?.startConnection()
    }
    
    func selectBuffer(buffer: Buffer) {
        self.working = true
        self.current = buffer
        if let session = session {
            let bytes = "buffer \(buffer.displayName)".data(using: .utf8)!
            let ctrlHandle = session.open(["..", "ctrl"], mode: .write)
            session.write(ctrlHandle, data: bytes) { error in
                if error == .success {
                    self.working = false
                    //let titleHandle = session.open(["..", "title"], mode: .read)
                    //session.read(titleHandle) { title in
                    //    buffer.title = title
                    //}
                    let feedHandle = session.open(["..", "feed"], mode: .read)
                    session.read(feedHandle) { feed in
                        let localized = LocalizedStringKey(feed)
                        buffer.ColorizedText = localized.coloredText()
                    }
                    session.close(ctrlHandle)
                    //session.close(titleHandle)
                    session.close(feedHandle)
                }
            }
            session.run()
        }
    }
    
    func handleInput(_ input: String) -> Void {
        if let session = session {
            let handle = session.open(["input"], mode: .write)
            session.write(handle, data: input.data(using: .utf8)!) { error in }
            session.close(handle)
        }
    }
    
    // Probably better to parse this out in a state method. We only have two cases, in name and in unread
    // Use a utility function though as this gets big.
    func buildBuffers(data: String) {
        var tmp = [Buffer]()
        let inputs = data.split(separator: "\n")
        for input in inputs {
            let parts = input.split(separator: " ")
            var seen = false
            for buffer in buffers {
                if buffer.displayName == String(parts[0]) {
                    tmp.append(buffer)
                    //buffer.updateUnread(data: parts[1])
                    seen = true
                }
            }
            if !seen {
                tmp.append(Buffer(displayName: String(parts[0]), handleInput: handleInput))
            }
        }
        buffers = tmp
    }
}

extension Service: PeerConnectionDelegate {
    func connectionReady() {
        if let session = session {
            session.connect()
            let fid = session.open(["tabs"], mode: .read)
            session.read(fid) { data in
                self.buildBuffers(data: data)
            }
            session.run()
        }
    }
    
    func connectionFailed() {
        print("Connection failed")
    }
    
    func displayAdvertiseError(_ error: NWError) {
        print("Advertise Error: \(error)")
    }
    
    
}
