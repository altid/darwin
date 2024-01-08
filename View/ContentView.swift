//
//  ContentView.swift
//  Altid
//
//  Created by halfwit on 2024-01-06.
//

import SwiftUI
import SwiftData
import Network

struct ContentView: View {
    //@Environment(\.navi) var navi
    //@Environment(\.localServices) var localServices

    //@SceneStorage("navigationState") var naviStateData: Data?
    //@Query var remotes: [RemoteService]

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            ContentView()
        }
        //.onAppear {
        //    navi.data = naviStateData
        //    data.setContext(context: modelContext)
        //}
        //.onReceive(navi.$selected.dropFirst()) { _ in
        //    naviStateData = navi.data
        //}
    }
}

#Preview {
    ContentView()
        //.environment(\.navi, NavigationManager())
        //.environment(\.data, [LocalService]())
}
