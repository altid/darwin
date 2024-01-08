//
//  AltidApp.swift
//  Altid
//
//  Created by halfwit on 2023-12-30.
//

import SwiftData
import SwiftUI

@main
struct AltidApp: App {
    @State private var localServices = [Service]()
    @State private var navigation = NavigationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.localServices, localServices)
                .environment(\.navigation, navigation)
        }
        .modelContainer(for: Service.self)
    }
}
