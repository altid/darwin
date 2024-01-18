//
//  ServicesList.swift
//  Altid
//
//  Created by halfwit on 2024-01-12.
//

import Foundation
import SwiftUI
import Observation

@Observable class ServiceManager {
    var list: [Service] = [Service]()
    
    func addService(service: Service) {
        if let _ = list.firstIndex(where: { $0 == service }) {
            return
        }
        list.append(service)
    }
    
    func removeService(service: Service) {
        if let index = list.firstIndex(where: { $0 == service }) {
            list.remove(at: index)
        }
    }
}

extension EnvironmentValues {
    var services: ServiceManager {
        get { self[ServicesKey.self] }
        set { self[ServicesKey.self] = newValue }
    }
}

private struct ServicesKey: EnvironmentKey {
    static var defaultValue: ServiceManager = ServiceManager()
}
