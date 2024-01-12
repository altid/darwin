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
            Text(buffer.displayName)
                .navigationTitle(buffer.displayName)
        case .settings:
            //SettingsView()
            Text("Hello")
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    BufferView()
        .environment(\.navigation, NavigationManager())
}
