//
//  ServiceView.swift
//  Altid
//
//  Created by halfwit on 2024-01-01.
//

import SwiftUI

struct BufferView: View {
    @Namespace var bottom
    @Environment(\.navigation) var navigation
    
    var body: some View {
        switch navigation.selected {
        case .none:
            Text("Select a Service to continue")
        case .details(let buffer):
            ScrollView {
                Spacer()
                buffer.ColorizedText
            }
            .padding(4)
            .navigationTitle(buffer.title)
            InputView(buffer: buffer)
        case .settings:
            //SettingsView()
            Text("Hello")
                .navigationTitle("Settings")
        }
    }
}

struct InputView: View {
    @State private var input: String = ""
    let buffer: Buffer
    
    var body: some View {
        TextField("Enter input", text: $input)
            .onSubmit {
                buffer.handleInput(input)
                input = ""
            }
            .textFieldStyle(.roundedBorder)
            .padding(EdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12))
    }
}

/*
 #Preview {
 BufferView()
 .environment(\.navigation, Navigation())
 }
 */
