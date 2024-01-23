//
//  Service.swift
//  Altid
//
//  Created by halfwit on 2024-01-08.
//

import SwiftUI
import Network
import Observation

struct Handle {
    let fid: UInt32
    let tag: UInt16
    let name: String
    
    init(fid: UInt32, tag: UInt16, name: String) {
        self.fid = fid
        self.tag = tag
        self.name = name
    }
}

@Observable
class Service: Hashable, Identifiable {
    private var browser: Result
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
        return browser.name
    }

    var connected: Bool {
        return session?.initiatedConnection ?? false
    }

    init(result: Result) {
        self.buffers = [Buffer]()
        self.browser = result
    }
    
    static func == (lhs: Service, rhs: Service) -> Bool {
        return lhs.displayName == rhs.displayName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    func connect() {
        self.session = PeerConnection(result: self.browser, delegate: self)
        self.session?.startConnection()
    }
    
    func selectBuffer(buffer: Buffer) {
        self.current = buffer
        self.working = true
        if let session = session {
            let bytes = "buffer \(buffer.displayName)".data(using: .utf8)!
            session.write(["ctrl"], data: bytes) { error in
                if error == .success {
                    self.working = false
                    session.read(["title"], fid: 1, tag: 1) { data in
                        print("In callback")
                        buffer.title = data
                    }
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
                tmp.append(Buffer(displayName: String(parts[0])))
            }
        }
        buffers = tmp
    }
}

extension Service: PeerConnectionDelegate {
    func connectionReady() {
        if let session = session {
            session.connect(uname: "halfwit")
            session.read(["tabs"]) { data in
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
