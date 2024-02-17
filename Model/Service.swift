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
            session.open("ctrl", mode: .write) { ctrlHandle in
                session.write(ctrlHandle, data: bytes) { error in
                    self.working = false
                    if error != .success {
                        print("Error trying to write to ctrl file: \(error)")
                        return
                    }
                    session.close(ctrlHandle)
                    /* We read in our callback to fire after changing our buffer */
                    /* Some times file not found error */
                    session.open("title", mode: .read) { handle in
                        if(handle.fid >= 0) {
                            session.read(handle) { title in
                                buffer.title = "\(buffer.displayName): \(title)"
                            }
                        }
                        session.close(handle)
                    }
                    // TODO: A proper feed reader that takes an update delegate
                    session.open("feed", mode: .read) { handle in
                        session.stat(handle) { stat in
                            //print(stat)
                            let offset: UInt64 = 16000 //stat.length > handle.iounit ? stat.length - UInt64(handle.iounit) : 0
                            session.read(handle, offset: offset, count: handle.iounit) { feed in
                                let localized = LocalizedStringKey(feed)
                                buffer.ColorizedText = localized.coloredText()
                                session.close(handle)
                            }
                        }
                    }
                }
            }
            session.run()
        }
    }
    
    func handleInput(_ input: String) -> Void {
        if let session = session {
            session.open("input", mode: .write) { handle in
                session.write(handle, data: input.data(using: .utf8)!) { error in
                    session.close(handle)
                }
            }
            session.run()
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
            session.open("tabs", mode: .read) { fid in
                session.read(fid) { data in
                    self.buildBuffers(data: data)
                }
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
