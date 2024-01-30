//
//  ServiceView.swift
//  Altid
//
//  Created by halfwit on 2024-01-01.
//

import SwiftUI

struct BufferView: View {
    @Environment(\.navigation) var navigation
    
    var body: some View {
        switch navigation.selected {
        case .none:
            Text("Select a Service to continue")
        case .details(let buffer):
            ScrollView {
                buffer.ColorizedText
            }
            .padding(2)
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
        HStack {
            Image(systemName: "pencil")
            TextField("", text: $input)
                .onSubmit {
                    buffer.handleInput(input)
                    input = ""
                }
                .textFieldStyle(.roundedBorder)
        }
        .padding(4)
    }
}

/*
 #Preview {
 BufferView()
 .environment(\.navigation, Navigation())
 }
 */
