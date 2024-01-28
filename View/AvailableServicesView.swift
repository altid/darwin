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
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Section("Available") {
            ForEach(browser.results) { result in
                AvailableService(result: result, browser: browser)
            }
        }
        .task {
            self.scan(browser: browser)
        }
        .refreshable {
            self.scan(browser: browser)
        }
    }
    
    func scan(browser: Browser) {
        browser.results.removeAll()
        browser.ignoreServices(services: services)
        let listener = Scanner(delegate: browser)
        listener.startBrowsing()
    }
}

struct AvailableService: View {
    @Environment(\.services) var services
    @State var isLoading = false
    let result: Result
    let browser: Browser

    var body: some View {
            HStack {
                Text(result.name)
                    .onTapGesture {
                        if(!isLoading){
                            connectToService(result: result)
                        }
                    }
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .opacity(isLoading ? 1 : 0)
#if os(iOS)
                    .scaleEffect(1)
#else
                    .scaleEffect(0.5)
#endif
            }
    }

    func connectToService(result: Result) {
        isLoading = true
        DispatchQueue.global(qos: .background).async {
            let service = Service(name: result.name)
            service.connect()
            DispatchQueue.main.async {
                services.addService(service: service)
                browser.ignore(result: result)
                isLoading = false
            }

        }
    }
}

/*
#Preview {
    AvailableServicesView()
        .modelContainer(previewContainer)
}
*/
