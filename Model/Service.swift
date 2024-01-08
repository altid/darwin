//
//  Service.swift
//  Altid
//
//  Created by halfwit on 2024-01-08.
//
// TODO: Separate these types into local and remote explicitly, make them conform to a protocol that works for anything we need
import Observation
import SwiftData
import SwiftUI

@Model
class Service: Codable {

    enum CodingKeys: CodingKey {
        case name, addr, broadcasting, connected
    }
    
    var name: String
    var addr: String
    var broadcasting: Bool
    var connected: Bool
    
    init(name: String, addr: String, broadcasting: Bool, connected: Bool) {
        self.name = name
        self.addr = addr
        self.broadcasting = broadcasting
        self.connected = connected
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        addr = try container.decode(String.self, forKey: .addr)
        broadcasting = try container.decode(Bool.self, forKey: .broadcasting)
        connected = try container.decode(Bool.self, forKey: .connected)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(addr, forKey: .addr)
        try container.encode(broadcasting, forKey: .broadcasting)
        try container.encode(connected, forKey: .connected)
    }
}

extension EnvironmentValues {
    var localServices: [Service] {
        get { self[DataKey.self] }
        set { self[DataKey.self] = newValue }
    }
}

private struct DataKey: EnvironmentKey {
    static var defaultValue: [Service] = [Service]()
}
