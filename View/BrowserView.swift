//
//  BrowserView.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftUI

struct BrowserView: View {
    @Environment(\.localServices) var localServices
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
                        //let service = Service(result: result)
                        //data.append(service)
                        browser.ignore(result: result)
                    }
            }
        }
        .task {
            let scanner = Scanner(delegate: browser)
            scanner.startBrowsing()
        }
        .refreshable {
            browser.ignored.removeAll()
            browser.ignoreServices(services: localServices)
            let listener = Scanner(delegate: browser)
            listener.startBrowsing()
        }
    }
}

#Preview {
    BrowserView()
        .environment(\.localServices, [Service]())
}
