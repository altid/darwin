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
        Section("Connected") {
            ForEach(services.list) { service in
                ServiceListItemView(service: service)
                    .contextMenu {
                        Button("Disconnect") {
                            services.removeService(service: service)
                            //service.disconnect()
                        }
                        Button("Reconnect") {
                            //service.reconnect()
                        }
                    }
            }
        }
    }
}


#Preview {
    ConnectedServicesView()
        .environment(\.services, ServiceManager())
}

