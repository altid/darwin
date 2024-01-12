//
//  AltidApp.swift
//  Altid
//
//  Created by halfwit on 2023-12-30.
//

import SwiftUI

@main
struct AltidApp: App {
    @State private var navigation = NavigationManager()
    @State private var services = ServiceManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.navigation, navigation)
                .environment(\.services, services)
        }
    }
}
