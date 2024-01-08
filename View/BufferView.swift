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
        if let state = navigation.selected {
            switch state {
            case .details(let service):
                Text(service.name)
            case .settings:
                //SettingsView()
                Text("Hello")
            }
        } else {
            Text("Select a Service to continue")
        }
    }
}

#Preview {
   BufferView()
        .environment(\.navigation, NavigationManager())
}
