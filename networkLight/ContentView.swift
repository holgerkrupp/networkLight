//
//  ContentView.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI
import CoreData
import Foundation



struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext


    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SpeedLog.date, ascending: false)],
        
        animation: .default)
    
    
    var SpeedLogs: FetchedResults<SpeedLog>

    @State  var Speeds = [String:Speed]()
    
    @State var baseDownload = "1000"
    @State var baseUpload = "100"
    
    
    
    
    @State var limits: [SpeedLimit]? = nil
    
    var body: some View {
        VStack{
            Text("History")
          
            ForEach(SpeedLogs.prefix(10)){ speedlog in
                Divider()

                Text(speedlog.date?.formatted() ?? "--")

                HStack{
                    Text("U: \(speedlog.upload) Mbps")
                    Text("D: \(speedlog.download) Mbps")

                }
            }
         
        }
    }
    


    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { SpeedLogs[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
