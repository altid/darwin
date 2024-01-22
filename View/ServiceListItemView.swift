//
//  ServiceListItemView.swift
//  Altid
//
//  Created by halfwit on 2024-01-12.
//

import SwiftUI

struct ServiceListItemView: View {
    @Environment(\.navigation) var navigation
    
    var service: Service
    var body: some View {
        Section(service.displayName) {
            ForEach(service.buffers) { buffer in
                Text(buffer.displayName)
                    .onTapGesture {
                        service.selectBuffer(buffer: buffer)
                        navigation.selected = Selected.details(buffer)
                    }
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
            }
        }
    }
}

/*
 #Preview {
 ServiceListItemView()
 .environment(\.navigation, NavigationManager())
 }
 */
