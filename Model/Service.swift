//
//  Service.swift
//  Altid
//
//  Created by halfwit on 2024-01-08.
//

import SwiftUI
import Network

class Service: Hashable, Identifiable {
    private var browser: Result
    var buffers: [Buffer]
    var session: PeerConnection?
    
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
        self.buffers.append(Buffer(displayName: "#altid"))
        self.buffers.append(Buffer(displayName: "##meskarune"))
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
}

extension Service: PeerConnectionDelegate {
    func connectionReady() {
        session?.writeMessage(Tversion())
        //session?.writeMessage(Tauth())
        session?.writeMessage(Tattach(fid: 0, afid: 0xFFFF, uname: "halfwit", aname: "halfwit"))
    }
    
    func connectionFailed() {
        print("Connection failed")
    }

    func receivedMessage(content: Data?, message: NWProtocolFramer.Message) {
        if var data = content {
            do {
                let msg = try nineProc(&data)
                print(msg)
            } catch {
                print("Shit")
            }
        }
        
    }
    
    func displayAdvertiseError(_ error: NWError) {
        print("Advertise Error: \(error)")
    }
    
    
}
