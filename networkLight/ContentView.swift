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
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>
    @State  var Speeds = [String:Speed]()
    @State var running:Bool = false

    var body: some View {
        VStack{
            Button(action: readNetworkStatus) {
                if running == false{
                    Text("Test now")
                }else{
                        ProgressView()
                }
            }
            Text("Last Check: \(Speeds["Upload"]?.date?.formatted() ?? "unknown")")
            Text("Upload: \(Speeds["Upload"]?.speed?.description ?? "0.0") \(Speeds["Upload"]?.unit ?? "-")")
            Text("Download: \(Speeds["Download"]?.speed?.description ?? "0.0") \(Speeds["Download"]?.unit ?? "-")")

        }
//        NavigationView {
//            List {
//                ForEach(items) { item in
//                    NavigationLink {
//                        Text("Item at \(item.timestamp!, formatter: itemFormatter)")
//                    } label: {
//                        Text(item.timestamp!, formatter: itemFormatter)
//                    }
//                }
//                .onDelete(perform: deleteItems)
//            }
//            .toolbar {
//                ToolbarItem {
//                    Button(action: addItem) {
//                        Label("Add Item", systemImage: "plus")
//                    }
//                }
//            }
//            Text("Select an item")
//        }
    }
    
    func readNetworkStatus(){
        running = true
        do {
            try networkquality()
            running = false
        } catch {
            running = false
        }
    }
    
    private func networkquality() throws{
        
        // there is the option to use "networkquality -c" which creates machine readable output (JSON). Unfortunatly Mbps has to be calculated manually from the data provided and I don't know how to do that. Therefore I scrap the output of the human readable format until I found a solution.
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", "networkquality"]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.standardInput = nil
        
        try task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        
        let UploadKeyword = "Upload capacity: "
        let DownloadKeyword = "\nDownload capacity: "
        let EndKeyword = "\nUpload flows:"
        let now = Date()

        if let UploadRangeStart = output.range(of: UploadKeyword)?.upperBound, let UploadRangeEnd = output.range(of: DownloadKeyword)?.lowerBound{
            
            let UploadRange = Range(uncheckedBounds: (lower: UploadRangeStart, upper: UploadRangeEnd))
            
            let UploadComponents = output[UploadRange].components(separatedBy: " ")
            
            let Upload = Speed(speed: Double(UploadComponents[0]), unit: UploadComponents[1], date: now)
            Speeds.updateValue(Upload, forKey: "Upload")
        }

        if let DownloadRangeStart = output.range(of: DownloadKeyword)?.upperBound, let DownloadRangeEnd = output.range(of: EndKeyword)?.lowerBound {
            let DownloadRange = Range(uncheckedBounds: (lower: DownloadRangeStart, upper: DownloadRangeEnd))

            let DownloadComponents = output[DownloadRange].components(separatedBy: " ")
            
            let Download = Speed(speed: Double(DownloadComponents[0]), unit: DownloadComponents[1], date: now)
            Speeds.updateValue(Download, forKey: "Download")

        }
        dump(Speeds)
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
            offsets.map { items[$0] }.forEach(viewContext.delete)

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
