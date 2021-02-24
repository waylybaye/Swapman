//
//  SwapmanApp.swift
//  Shared
//
//  Created by Baye Wayly on 2021/2/24.
//

import SwiftUI

@main
struct SwapmanApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
