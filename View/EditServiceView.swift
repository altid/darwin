//
//  EditServiceView.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftData
import SwiftUI

struct EditServiceView: View {
    @Binding var showingSheet: Bool
    @State private var edited = Service(name: "", addr: "", broadcasting: false, connected: false)
    let service: Service
    
    var body: some View {
        Form {
            TextField(text: $edited.name, prompt: Text("Name of service")) {
                Text("Name")
            }
            TextField(text: $edited.addr, prompt: Text("URL or IP address")) {
                Text("Address")
            }
            HStack {
                Button("cancel") {
                    showingSheet.toggle()
                }
                Button("save") {
                    //data.updateService(service: service, edited: edited)
                    showingSheet.toggle()
                }
            }
        }
        .padding()
    }
}

//#Preview {
//    EditServiceView()
//}
