//
//  NavigationManager.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftUI
import Combine
import Observation

enum Selected: Hashable, Codable {
    case details(Service)
    case settings
}

@Observable class NavigationManager {
    var selected: Selected? = nil
    var data: Data? {
        get {
           try? JSONEncoder().encode(selected)
        }
        set {
            guard let data = newValue,
                  let selected = try? JSONDecoder().decode(Selected.self, from: data) else {
                return
            }
            self.selected = selected
        }
    }
    
    func root() { selected = nil }
    func settings() { selected = .settings }
    func details(service: Service) { selected = .details(service) }
}

extension EnvironmentValues {
    var navigation: NavigationManager {
        get { self[NavigationManagerKey.self] }
        set { self[NavigationManagerKey.self] = newValue }
    }
}

private struct NavigationManagerKey: EnvironmentKey {
    static var defaultValue: NavigationManager = NavigationManager()
}
