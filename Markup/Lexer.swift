//
//  Markdown.swift
//  Altid
//
//  Created by halfwit on 2024-01-28.
//

import Foundation

enum MarkupType {
    case NormalText
    case ColorCode
    case ColorText
    case ColorTextBold
    case ColorTextStrong
    case ColorTextStrike
    case ColorTextEmphasis
    case URLLink
    case URLText
    case ImagePath
    case ImageText
    case ImageLink
    case BoldText
    case StrikeText
    case EmphasisText
    case StrongText
    case NewLine
    case ErrorText
    case EOF
}

var escapable = "\\!#([])*_~`"

struct Item {
    var data: String
    var type: MarkupType
}

class Lexer {
    var queue = Queue<Item>()
    var src: String
    var start: Int
    var pos: Int
    var state: (Lexer) -> Bool
    
    init(src: String) {
        self.src = src
        self.start = 0
        self.pos = 0
        self.state = lexText
    }
    
    func Next() -> Item {
        while queue.size == 0 {
            if !state(self) {
                break
            }
        }

        if let item = queue.dequeue() {
            return item
        }
        return Item(data: "Unknown error occured", type: .ErrorText)
    }
    
    func push(_ type: MarkupType) {
        if pos <= start && type != .EOF {
            return
        }

        let item = Item(data: src[start..<pos], type: type)
        queue.enqueue(item)
        start = pos
    }
    func ignore() { start = pos }
    func backup() { pos -= 1 }
    func peek() -> String { return src[pos] }
    func nextchar() -> String {
        let ch = src[pos]
        pos += 1
        return ch
    }
    
    @discardableResult
    func accept(_ valid: String) -> Bool {
        let c = src[pos]
        for i in valid {
            if i == c.first {
                pos += 1
                return true
            }
        }
        return false
    }
    
    func acceptRun(valid: String) {
        while accept(valid) {}
    }
    
    func escape() {
        self.accept("\\")
        self.ignore()
        self.accept(escapable)
    }
    
    func error(err: String) {
        src = err
        start = 0
        pos = src.count
        push(.ErrorText)
    }
}

func lexText(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "\\", "%", "[", "!", "*", "~", "_":
            l.push(.EmphasisText)
        default:
            break
        }
        switch l.nextchar() {
        case "":
            l.push(.NormalText)
            l.push(.EOF)
            return false
        case "\\":
            l.escape()
        case "~":
            l.accept("~")
            l.ignore()
            l.state = lexStrike
        case "_":
            l.accept("_")
            l.ignore()
            l.state = lexEmphasis
            return true
        case "%":
            l.state = lexMaybeColor
            return true
        case "[":
            l.state = lexMaybeURL
            return true
        case "!":
            l.state = lexMaybeImage
            return true
        case "*":
            l.state = lexMaybeBold
            return true
        case "\n":
            l.backup()
            l.push(.NormalText)
            l.accept("\n")
            l.push(.NewLine)
        default:
            break
        }

    }
}

func lexStrike(l: Lexer) -> Bool {
    while true {
        // Fire off Strike on match
        switch l.peek() {
        case "~", "\\":
            l.push(.StrikeText)
        default:
            break
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: no closing stikeout tag")
            return false
        case "\\":
            l.escape()
        case "~":
            l.accept("~")
            l.ignore()
            l.state = lexText
            return true
        default:
            break
        }
    }
}

func lexEmphasis(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "_", "\\", "*":
            l.push(.EmphasisText)
        default:
            break
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: no closing emphasis tag")
            return false
        case "\\":
            l.escape()
        case "_", "*":
            l.accept("_*")
            l.ignore()
            l.state = lexText
            return true
        default:
            break
        }
    }
}

func lexMaybeBold(l: Lexer) -> Bool {
    l.ignore()
    switch l.nextchar() {
    case "":
        l.error(err: "found no closing tag for '*'")
        return false
    case "*":
        l.accept("*")
        l.ignore()
        l.state = lexBold
        return true
    case "\n":
        l.push(.NewLine)
        l.state = lexText
        return true
    default:
        l.state = lexEmphasis
        return true
    }
}

func lexBold(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "_", "\\", "*":
            l.push(.BoldText)
        default:
            break
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: no closing bold tag")
            return false
        case "_":
            l.accept("_")
            l.ignore()
            l.state = lexStrong
            return true
        case "\\":
            l.escape()
        case "*":
            l.ignore()
            // There could be malformed input here with no closing, `**hello world* how are you`
            if l.peek() != "*" {
                l.error(err: "unexpected single '*' inside bold token")
                return false
            }
            l.accept("*")
            l.ignore()
            l.state = lexText
            return true
        default:
            break
        }
    }
}

func lexStrong(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "_", "\\":
            l.push(.StrongText)
        default:
            break;
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: no closing strong tag")
            return false
        case "\\":
            l.escape()
        case "_":
            l.accept("_")
            l.ignore()
            // Exit bold tag as well if we are at the end
            if l.src.hasPrefix("**") {
                l.accept("*")
                l.accept("*")
                l.ignore()
                l.state = lexText
                return true
            }
            l.state = lexBold
            return true
        default:
            break
        }
    }}

func lexMaybeColor(l: Lexer) -> Bool {
    switch l.nextchar() {
    case "":
        // Benign, just send what we have and EOF
        l.push(.NormalText)
        l.push(.EOF)
        return false
    case "[":
        l.accept("[")
        l.ignore()
        l.state = lexColorText
        return true
    case "\n":
        l.push(.NewLine)
        l.state = lexText
        return true
    default:
        l.state = lexText
        return true
    }
}

func lexColorText(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "]", "*", "_", "~", "\\":
            l.push(.ColorText)
        default:
            break
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: no closing color tag")
            return false
        case "]":
            l.accept("]")
            l.ignore()
            l.state = lexColorCode
            return true
        case "*":
            l.accept("*")
            l.ignore()
            l.state = lexColorMaybeBold
            return true
        case "_":
            l.accept("_")
            l.ignore()
            l.state = lexColorEmphasis
            return true
        case "~":
            l.accept("~")
            l.ignore()
            l.state = lexColorStrikeout
            return true
        case "\\": // eat a single slash
            l.escape()
        default:
            break
        }
    }
}


func lexColorStrikeout(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "~", "\\":
            l.push(.ColorTextStrike)
        default:
            break
        }
        switch l.nextchar() {
        case "", "]":
            l.error(err: "incorrect input: no closing strikeout tag")
            return false
        case "\\":
            l.escape()
        case "~":
            l.accept("~")
            l.ignore()
            l.state = lexColorText
            return true
        default:
            break
        }
    }
}

func lexColorEmphasis(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "_", "*", "\\":
            l.push(.ColorTextEmphasis)
        default:
            break
        }
        switch l.nextchar() {
        case "", "]":
            l.error(err: "incorrect input: no closing emphasis tag")
            return false
        case "\\":
            l.escape()
        case "_":
            l.accept("_")
            l.ignore()
            l.state = lexColorText
            return true
        case "*":
            l.accept("*")
            l.ignore()
            l.state = lexColorText
            return true
        default:
            break
        }
    }
}

func lexColorStrong(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "_", "\\":
            l.push(.ColorTextStrong)
        default:
            break
        }
        switch l.nextchar() {
        case "", "]":
            l.error(err: "could not parse: no closing strong tag")
            return false
        case "\\":
            l.escape()
        case "_":
            l.accept("_")
            l.ignore()
            // Exit bold tag as well if we are at the end
            if l.src.hasPrefix("**") {
                l.accept("*")
                l.accept("*")
                l.ignore()
                l.state = lexColorText
                return true
            }
            l.state = lexColorBold
            return true
        default:
            break
        }
    }
}

func lexColorMaybeBold(l: Lexer) -> Bool {
    l.ignore()
    switch l.nextchar() {
    case "", "]":
        l.error(err: "found no closing tag for '*'")
        return false
    case "*":
        l.accept("*")
        l.ignore()
        l.state = lexColorBold
        return true
    default:
        l.state = lexColorEmphasis
        return true
    }
}

func lexColorBold(l: Lexer) -> Bool {
    while true {
        switch l.peek() {
        case "*", "\\", "_":
            l.push(.ColorTextBold)
        default:
            break
        }
        switch l.nextchar() {
        case "", "]":
            l.error(err: "incorrect input: no closing bold tag")
            return false
        case "_":
            l.accept("_")
            l.ignore()
            l.state = lexColorStrong
            return true
        case "\\":
            l.escape()
        case "*":
            l.ignore()
            // There could be malformed input here with no closing tag
            if l.peek() != "*" {
                l.error(err: "unexpected single '*' inside bold token")
                return false
            }
            l.accept("*")
            l.ignore()
            l.state = lexColorText
            return true
        default:
            break
        }
    }
}

func lexColorCode(l: Lexer) -> Bool {
    l.accept("]")
    l.accept("(")
    l.ignore()
    // Hex code
    if l.peek() == "#" {
        l.accept("#")
        l.acceptRun(valid: "1234567890,")
    }
    l.acceptRun(valid: "abcdefghijklmnopqrstuvwxyz,")
    if l.peek() != ")" {
        l.error(err: "Unsupported color tag \(l.src[l.start..<l.pos])")
        return false
    }
    l.push(.ColorCode)
    l.accept(")")
    l.ignore()
    l.state = lexText
    return true
}

func lexMaybeURL(l: Lexer) -> Bool {
    l.ignore()
    switch l.nextchar() {
    case "":
        l.error(err: "incorrect input: malformed URL")
        return false
    case "!":
        l.state = lexImageLinkText
    case "\n":
        l.push(.NewLine)
        l.state = lexText
    default:
        l.state = lexURLText
    }
    return true
}


func lexURLText(l: Lexer) -> Bool {
    while true {
        if l.peek() == "]" {
            l.push(.URLText)
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: malformed URL")
            return false
        case "]":
            l.state = lexURLLink
            return true
        default:
            break
        }
    }
}

func lexURLLink(l: Lexer) -> Bool {
    l.acceptRun(valid: "](")
    l.ignore()
    while true {
        if l.peek() == ")" {
            l.push(.URLLink)
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: malfored URL")
            return false
        case ")":
            l.accept(")")
            l.ignore()
            l.state = lexText
            return true
        default:
            break
        }
    }
}

// [![alt text](/path/to/image)](link)
func lexImageLinkText(l: Lexer) -> Bool {
    l.acceptRun(valid: "[!")
    l.ignore()
    while true {
        if l.peek() == "]" {
            l.push(.ImageText)
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: malformed image tag")
            return false
        case "]":
            l.state = lexImageLinkPath
            return true
        default:
            break
        }
    }
}

func lexImageLinkPath(l: Lexer) -> Bool {
    l.acceptRun(valid: "](")
    l.ignore()
    while true {
        if l.peek() == ")" {
            l.push(.ImagePath)
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: malformed image tag")
            return false
        case ")":
            l.state = lexImageLink
            return true
        default:
            break
        }
    }
}

func lexImageLink(l: Lexer) -> Bool {
    l.acceptRun(valid: ")](")
    l.ignore()
    while true {
        if l.peek() == ")" {
            l.push(.ImageLink)
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: malformed image tag")
            return false
        case ")":
            l.accept(")")
            l.ignore()
            l.state = lexText
            return true
        default:
            break
        }
    }
}


func lexMaybeImage(l: Lexer) -> Bool {
    switch l.nextchar() {
    case "":
        l.push(.EOF)
        return false
    case "[":
        l.state = lexImageText
        return true
    case "\n":
        l.push(.NewLine)
        l.state = lexText
        return true
    default:
        l.state = lexText
        return true
    }
}

func lexImageText(l: Lexer) -> Bool {
    l.accept("[")
    l.ignore()
    while true {
        if l.peek() == "]" {
            l.push(.ImageText)
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: malformed image tag")
            return false
        case "]":
            l.state = lexImagePath
            return true
        default:
            break
        }
    }
}

func lexImagePath(l: Lexer) -> Bool {
    l.acceptRun(valid: "](")
    l.ignore()
    while true {
        if l.peek() == ")" {
            l.push(.ImagePath)
        }
        switch l.nextchar() {
        case "":
            l.error(err: "incorrect input: malformed image tag")
            return false
        case ")":
            l.accept(")")
            l.ignore()
            l.state = lexText
            return true
        default:
            break
        }
    }
}

/* Used everywhere here */
extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
