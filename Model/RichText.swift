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
    case image(AsyncImage<Image>)
    case url(Link<Text>)
    case none
}

class RichText: Identifiable {
    var type: RichTextType = .none
    
    init(_ type: RichTextType) {
        self.type = type
    }
}

/* Simple state machine to parse out values */
func fromData(input: String) -> [[RichText]] {
    var final = [[RichText]]()
    var elements = [RichText]()
    
    /* Hold any data needed mid-loop */
    var colorCode: Color = .black
    var urlText = ""
    
    let lexer = Lexer(src: input)
    while true {
        let token = lexer.Next()
        switch token.type {
        case .NormalText:
            let item = Text(token.data)
            elements.append(RichText(.text(item)))
        case .ColorCode:
            switch token.data {
            case "white":
                colorCode = .white
            case "black":
                colorCode = .black
            case "cyan", "lightcyan":
                colorCode = .cyan
            case "pink":
                colorCode = .pink
            case "green", "lightgreen":
                colorCode = .green
            case "brown":
                colorCode = .brown
            case "purple":
                colorCode = .purple
            case "yellow":
                colorCode = .yellow
            case "blue", "lightblue":
                colorCode = .blue
            case "orange":
                colorCode = .orange
            case "red":
                colorCode = .red
            case "grey", "lightgrey":
                colorCode = .gray
            default:
                colorCode = .black
            }
        case .ColorText:
            let item = Text(token.data)
                .foregroundColor(colorCode)
            elements.append(RichText(.text(item)))
        case .ColorTextBold:
            let item = Text(token.data)
                .foregroundColor(colorCode)
                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
            elements.append(RichText(.text(item)))
        case .ColorTextStrong:
            let item = Text(token.data)
                .foregroundColor(colorCode)
                .fontWeight(.heavy)
            elements.append(RichText(.text(item)))
        case .ColorTextStrike:
            let item = Text(token.data)
                .foregroundColor(colorCode)
                .strikethrough()
            elements.append(RichText(.text(item)))
        case .ColorTextEmphasis:
            let item = Text(token.data)
                .foregroundColor(colorCode)
                //italics?
            elements.append(RichText(.text(item)))
        case .URLLink:
            let item = Link(urlText, destination: URL(string: token.data)!)
            elements.append(RichText(.url(item)))
        case .URLText:
            urlText = token.data
        case .ImagePath:
            let item = AsyncImage(url: URL(string: token.data))
            elements.append(RichText(.image(item)))
        case .BoldText:
            let item = Text(token.data)
                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
            elements.append(RichText(.text(item)))
        case .StrikeText:
            let item = Text(token.data)
                .strikethrough()
            elements.append(RichText(.text(item)))
        case .EmphasisText:
            let item = Text(token.data)
                //italics?
            elements.append(RichText(.text(item)))
        case .StrongText:
            let item = Text(token.data)
                .fontWeight(.heavy)
            elements.append(RichText(.text(item)))
        case .NewLine:
            final.append(elements)
            elements = [RichText]()
        case .ErrorText:
            return final
        case .EOF:
            final.append(elements)
            return final
        default:
            break
        }
    }
}
