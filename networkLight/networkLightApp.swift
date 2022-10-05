//
//  networkLightApp.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI

@main
struct networkLightApp: App {
    let persistenceController = PersistenceController.shared
    
    @State var currentNumber: String = "1"


    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        
//        MenuBarExtra(currentNumber, systemImage: "\(currentNumber).circle") {
//            // 3
//            Button("One") {
//                currentNumber = "1"
//            }
//            Button("Two") {
//                currentNumber = "2"
//            }
//            Button("Three") {
//                currentNumber = "3"
//            }
//        }
    }
}
