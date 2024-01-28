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
                Spacer()
                ForEach(buffer.elements) { element in
                    ElementView(element: element)
                }
            }
            .navigationTitle(buffer.title)
            Spacer()
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
        }
        .padding(2)
    }
}

struct ElementView: View {
    let element: RichText
    
    var body: some View {
        switch element.type {
        case .text(let text):
            text
        case .image(let image):
            image
        case .none:
            Spacer()
        }
    }
}

/*
#Preview {
    BufferView()
        .environment(\.navigation, Navigation())
}
*/
