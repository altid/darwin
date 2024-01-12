//
//  ConnectedServicesView.swift
//  Altid
//
//  Created by halfwit on 2024-01-11.
//

import SwiftUI

struct ConnectedServicesView: View {
    @Environment(\.services) var services: ServiceManager
    @Environment(\.navigation) var navigation: NavigationManager
    
    var body: some View {
        Section("Connected"){
            List(services.list) { service in
                Section(service.displayName) {
                    List(service.buffers) { buffer in
                    //ForEach(service.buffers) { buffer in
                        Text(buffer.displayName)
                            .onTapGesture {
                                navigation.selected = Selected.details(buffer)
                            }
                    }
                }
                .contextMenu {
                    Button("Disconnect") {
                        //service.disconnect()
                    }
                    Button("Reconnect") {
                        //service.reconnect()
                    }
                }
            }
#if os(iOS)
            .listStyle(.grouped)
#else
            .listStyle(.sidebar)
#endif
        }
    }
}


#Preview {
    ConnectedServicesView()
        .environment(\.services, ServiceManager())
}

