//
//  Buffer.swift
//  Altid
//
//  Created by halfwit on 2024-01-12.
//

import Foundation

class Buffer: Identifiable, Hashable {
    var displayName: String
    var unread: Int = 0
    var title: String

    static func == (lhs: Buffer, rhs: Buffer) -> Bool {
        lhs.displayName == rhs.displayName
    }
    
    func setTitle(data: Data?) {
        if let data = data {
            title = ""
            for d in data {
                title.append(d.char)
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    init(displayName: String) {
        self.displayName = displayName
        self.title = displayName
    }

}

