//
//  LocalizedStringKeyExtension.swift
//  Altid
//
//  Created by halfwit on 2024-01-29.
//

import SwiftUI

extension LocalizedStringKey {
    func coloredText() -> Text {
        // Define a regular expression pattern to match the desired format
        let pattern = "%\\[([^)]+)\\]\\(([^)]+)\\)"
        
        do {
            // Create a regular expression object
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            
            // Convert LocalizedStringKey to String using Mirror
            let stringValue = Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
            
            // Get the matches in the string
            let matches = regex.matches(in: stringValue!, options: [], range: NSRange(location: 0, length: stringValue!.utf16.count))
            
            // Create a SwiftUI Text view with the colored text
            return buildAttributedString(from: stringValue!, matches: matches)
            
        } catch {
            // Handle error if the regular expression is invalid
            return Text(self)
        }
    }
    
    private func buildAttributedString(from originalString: String, matches: [NSTextCheckingResult]) -> Text {
        var attributedText = Text("")
        
        var currentIndex = originalString.startIndex
        
        for match in matches {
            guard
                let coloredTextRange = Range(match.range(at: 1), in: originalString),
                let colorCodeRange = Range(match.range(at: 2), in: originalString)
            else {
                continue
            }
            
            // Add non-matching text between the current index and the match
            let nonMatchingTextRange = currentIndex..<coloredTextRange.lowerBound
            let nonMatchingText = String(originalString[nonMatchingTextRange].trimmingPrefix(")").dropLast(2))
            attributedText = attributedText + Text(LocalizedStringKey(nonMatchingText))
            
            // Update the current index to the end of the match - This accidentally gets a spare )
            currentIndex = colorCodeRange.upperBound
            
            let coloredText = LocalizedStringKey(String(originalString[coloredTextRange]))
            let colorCode = LocalizedStringKey(String(originalString[colorCodeRange]))
            
            // Create a SwiftUI Color from the color code (color name)
            var color: Color = .primary
            switch colorCode {
            case "white":
                color = .white
            case "black":
                color = .black
            case "pink":
                color = .pink
            case "red":
                color = .red
            case "blue":
                color = .blue
            case "grey":
                color = .gray
            case "orange":
                color = .orange
            case "purple":
                color = .purple
            case "brown":
                color = .brown
            default:
                break
            }
            
            // Create a Text view with the colored text
            let coloredTextView = Text(coloredText).foregroundColor(color)
            
            // Concatenate the new Text view with the existing attributedText
            attributedText = attributedText + coloredTextView
        }
        
        // Add the remaining non-matching text after the last match
        let remainingTextRange = currentIndex..<originalString.endIndex
        var remainingText = String(originalString[remainingTextRange])
            .trimmingCharacters(in: .controlCharacters)
            .trimmingPrefix(")")
        attributedText = attributedText + Text(LocalizedStringKey(String(remainingText)))
        
        return attributedText
    }
}
