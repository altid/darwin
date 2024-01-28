//
//  Handle.swift
//  Altid
//
//  Created by halfwit on 2024-01-22.
//

import Foundation

/* Handle to an open nine file */
struct Handle {
    let tag: UInt16
    let fid: UInt32
    let name: String
    
    init(fid: UInt32, tag: UInt16, name: String) {
        self.fid = fid
        self.tag = tag
        self.name = name
    }
}
