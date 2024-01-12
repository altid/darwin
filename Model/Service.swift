//
//  Service.swift
//  Altid
//
//  Created by halfwit on 2024-01-08.
//

import Network

class Service: Hashable, Identifiable {
    private var browser: Result
    private var connection: NWConnection?
    var buffers: [Buffer]
    
    enum CodingKeys: CodingKey {
        case browser
        case connection
    }
    
    var displayName: String {
        return browser.name
    }

    var connected: Bool {
        //return browser.connection.status
        return false
    }

    init(result: Result) {
        self.buffers = [Buffer]()
        self.buffers.append(Buffer(displayName: "#altid"))
        self.browser = result
    }
    
    static func == (lhs: Service, rhs: Service) -> Bool {
        return lhs.displayName == rhs.displayName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    func connect() {
        
    }
}
