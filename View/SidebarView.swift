//
//  SidebarView.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.localServices) var localServices
    @Query var remoteServices: [Service]
    @State private var showingSheet = false
    
    var body: some View {
        List {
            Section("Services"){
                ForEach(remoteServices) { service in
                    NavigationLink(service.name, value: Selected.details(service))
                    .onLongPressGesture {
                        showingSheet.toggle()
                    }
                    .contextMenu {
                        Button("delete") {
                            //data.deleteRemote(service: service)
                        }
                    }
                    .sheet(isPresented: $showingSheet) {
                        EditServiceView(showingSheet: $showingSheet, service: service)
                    }
                }
                //.onDelete(perform: )
                ForEach(localServices) { service in
                    NavigationLink("Edit \(service.name)", value: Selected.details(service))
                }
                //.onDelete(perform: deleteLocal)
                Text("Add Service")
                    .onTapGesture {
                        showingSheet.toggle()
                    }
            }

        }
        #if os(iOS)
        .listStyle(.grouped)
        #else
        .listStyle(.sidebar)
        #endif
        .navigationTitle("Sidebar")
    }
}

#Preview {
    SidebarView()
        .environment(\.localServices, [Service]())
        .environment(\.navigation, NavigationManager())

}
