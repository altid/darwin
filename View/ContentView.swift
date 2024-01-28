//
//  ContentView.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftUI
import Network

struct ContentView: View {
    
    var body: some View {
        NavigationSplitView {
            List {
                ConnectedServicesView()
                AvailableServicesView()
            }
#if os(iOS)
            .listStyle(.grouped)
#else
            .listStyle(.sidebar)
#endif
            .navigationTitle("Altid")
        } detail: {
            BufferView()
        }
    }
}

/*
#Preview {
    ContentView()
}
*/
