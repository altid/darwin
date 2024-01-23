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
            if service.working {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
#if os(iOS)
                    .scaleEffect(1)
#else
                    .scaleEffect(0.5)
#endif
            } else {
                ForEach(service.buffers) { buffer in
                    Text(buffer.displayName)
                        .onTapGesture {
                            service.selectBuffer(buffer: buffer)
                            navigation.selected = Selected.details(service.current!)
                        }
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 0))
                }
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
