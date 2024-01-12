//
//  BrowserView.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftUI

struct AvailableServicesView: View {
    @Environment(\.services) var services
    var browser = Browser(name: "Default")
    
    var body: some View {
        Section("Available") {
            ForEach(browser.results) { result in
                Text(result.name)
                    .onTapGesture {
                        //guard try result.connect() else {
                        //  showerror
                        //  return
                        //
                        let service = Service(result: result)
                        services.addService(service: service)
                        browser.ignore(result: result)
                    }
            }
        }
        .task {
            let scanner = Scanner(delegate: browser)
            scanner.startBrowsing()
        }
        .refreshable {
            browser.ignoreServices(services: services)
            let listener = Scanner(delegate: browser)
            listener.startBrowsing()
        }
    }
}

/*
#Preview {
    AvailableServicesView()
        .modelContainer(previewContainer)
}
*/
