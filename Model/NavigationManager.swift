//
//  NavigationManager.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftUI
import Observation

enum Selected: Hashable {
    case details(Buffer)
    case none
    case settings
}

@Observable class NavigationManager {
    var selected: Selected = .none
    func none() { selected = .none }
    func settings() { selected = .settings }
    func details(buffer: Buffer) { selected = .details(buffer) }
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
