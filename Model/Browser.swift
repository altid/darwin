//
//  Browser.swift
//  Altid
//
//  Created by halfwit on 2024-01-04.
//

import Foundation
import Network
import Observation

@Observable class Result: Identifiable {
    let id: UUID
    let name: String
    var addr: String = ""
    let browser: NWBrowser.Result
    
    init(id: UUID = UUID(), name: String, browser: NWBrowser.Result) {
        self.id = id
        self.name = name
        self.browser = browser
    }
}

@Observable class Browser {
    var name: String = "Default"
    var results: [Result] = [Result]()
    var ignored: [Result] = [Result]()
    var ignoredServices: [Service] = [Service]()

    init(name: String) {
        self.name = name
    }
    
    func addResult(incoming: Result) {
        for result in ignored {
            if result.name == incoming.name {
                return
            }
        }
        for service in ignoredServices {
            if service.name == incoming.name {
                return
            }
        }
        self.results.append(incoming)
    }
    
    func ignoreServices(services: [Service]) {
        ignoredServices = services
    }
    
    func ignore(result: Result) {
        self.results = self.results.filter { $0.name != result.name }
        self.ignored.append(result)
    }
}

extension Browser: ScannerDelegate {
    // When the discovered peers change, update the list.
    func refreshResults(results: Set<NWBrowser.Result>) {
        self.results = [Result]()
        for result in results {
            if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = result.endpoint {
                self.addResult(incoming: Result(name: name, browser: result))
            }
        }
    }

    // Show an error if peer discovery fails.
    func displayBrowseError(_ error: NWError) {
        var message = "Error \(error)"
        if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_NoAuth)) {
            message = "Not allowed to access the network"
        }
        print(message)
    }
}
