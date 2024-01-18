//
//  Buffer.swift
//  Altid
//
//  Created by halfwit on 2024-01-12.
//

import Foundation

class Buffer: Identifiable, Hashable {
    static func == (lhs: Buffer, rhs: Buffer) -> Bool {
        lhs.displayName == rhs.displayName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    var displayName: String
    
    init(displayName: String) {
        self.displayName = displayName
    }
}

