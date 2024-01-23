//
//  Buffer.swift
//  Altid
//
//  Created by halfwit on 2024-01-12.
//

import Foundation
import Observation

@Observable
class Buffer: Identifiable, Hashable {
    var displayName: String
    var unread: Int = 0
    var title: String
    var status: String = ""
    var data: String = "Welcome to the Black Parade"

    static func == (lhs: Buffer, rhs: Buffer) -> Bool {
        lhs.displayName == rhs.displayName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    init(displayName: String) {
        self.displayName = displayName
        self.title = displayName
    }

}

