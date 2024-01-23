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

@Observable class Navigation {
    var selected: Selected = .none
    func none() { selected = .none }
    func settings() { selected = .settings }
    func details(buffer: Buffer) { selected = .details(buffer) }
}

extension EnvironmentValues {
    var navigation: Navigation {
        get { self[NavigationKey.self] }
        set { self[NavigationKey.self] = newValue }
    }
}

private struct NavigationKey: EnvironmentKey {
    static var defaultValue: Navigation = Navigation()
}
