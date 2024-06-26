//
//  Buffer.swift
//  Altid
//
//  Created by halfwit on 2024-01-12.
//

import Foundation
import Observation
import SwiftUI

let nullmsg = "Welcome to the Black Parade"

@Observable
class Buffer: Identifiable, Hashable {
    var displayName: String
    var unread: Int = 0
    var title: String
    var status: String = ""
    var ColorizedText: Text?
    var handleInput: (String) -> Void

    // TODO: Append to a given buffer, then re-parse to colorized text based on the trailing 8k section. If we reach the top, parse more.
    static func == (lhs: Buffer, rhs: Buffer) -> Bool {
        lhs.displayName == rhs.displayName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    init(displayName: String, handleInput: @escaping (String) -> Void) {
        self.displayName = displayName
        self.title = displayName
        self.handleInput = handleInput
    }

}

