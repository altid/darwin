//
//  RichText.swift
//  Altid
//
//  Created by halfwit on 2024-01-27.
//

import Foundation
import SwiftUI

enum RichTextType {
    case text(Text)
    case image(Image)
    //case url(Link)
    case none
}

class RichText: Identifiable {
    var type: RichTextType = .none

    func text(_ data: String, weight: Font.Weight = .regular, color: Color = .primary) {
        let input = Text(data)
            .fontWeight(weight)
            .foregroundColor(color)
        self.type = .text(input)
    }
    
    func image(_ src: String) {
        let input = Image(src)
        self.type = .image(input)
    }
    
    func url(link: String, label: String) {
        //let input = Link(destination: link, label: -> label)
        //self.type = .url(input)
    }
    
    init(_ type: RichTextType) {
        self.type = type
    }
}

/* Simple state machine to parse out values */
func fromData(input: String) -> [RichText] {
    
    return [RichText]()
}
