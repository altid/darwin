//
//  Browser.swift
//  Altid
//
//  Created by halfwit on 2024-01-04.
//

import Network
import Observation

final class Result: Identifiable {
    let name: String
    var connecting: Bool = false

    init(name: String) {
        self.name = name
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
            if service.displayName == incoming.name {
                return
            }
        }
        self.results.append(incoming)
    }
    
    func ignoreServices(services: ServiceManager) {
        ignoredServices = services.list
    }
    
    func ignore(result: Result) {
        self.results = self.results.filter { $0.name != result.name }
        self.ignored.append(result)
    }
    
    func connecting(_ result: Result) {
        for item in results {
            if item.name == result.name {
                item.connecting = true
            }
        }
    }
}

extension Browser: ScannerDelegate {
    // When the discovered peers change, update the list.
    func refreshResults(results: Set<NWBrowser.Result>) {
        self.results = [Result]()
        for result in results {
            if case let NWEndpoint.service(name: name, type: "_altid._tcp", domain: "local.", interface: _) = result.endpoint {
                self.addResult(incoming: Result(name: name))
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
