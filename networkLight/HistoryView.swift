//
//  HistoryView.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI
import CoreData
import Foundation



struct HistoryView: View {
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
                    Text("Upload: \(String(format: "%.0f",speedlog.upload)) Mbps")
                    Text("Download: \(String(format: "%.0f",speedlog.download)) Mbps")
                }
            }
            Button("Export SpeedLogs"){
                ExportCSV()
            }.keyboardShortcut("S")
         
        }
    }
    
    func ExportCSV(){
        
        
        let headerString: String = "Date, Upload, Download"
        
        
        var exportString: String = ""
        exportString.append(headerString)
        exportString.append("\n")
        
        for speed in SpeedLogs {
            
            let exportLine = "\(speed.date?.ISO8601Format().description ?? ""), \(speed.upload.description), \(speed.download.description)"
            
            
            exportString.append(exportLine)
            exportString.append("\n")
            
            
        }
        
        if let saveURL = showSavePanel(){
            do {
                try exportString.write(to: saveURL, atomically: true, encoding: .utf8)
            }catch{
                print("error creating file")

            }
        }
        
        
        
        
        
//            let fileManager = FileManager.default
//            do {
//                let path = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
//                let fileURL = path.appendingPathComponent("NetworkLightExport.csv")
//                try exportString.write(to: fileURL, atomically: true, encoding: .utf8)
//
//            } catch {
//                print("error creating file")
//            }
        }
        
    
    func showSavePanel() -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = false
        savePanel.title = "Save your data"
        savePanel.message = "Choose a folder and a name to store your results."
        savePanel.nameFieldLabel = "File name:"
        savePanel.nameFieldStringValue = "NetworkLightExport.csv"
        
        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
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
        HistoryView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
