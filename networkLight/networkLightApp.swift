//
//  networkLightApp.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI

struct Speed{
    var id = UUID()
    var speed: Double?
    var unit: String?
    var date: Date?
}

@main

struct networkLightApp: App {
    let persistenceController = PersistenceController.shared
    
    @State var currentNumber: String = "1"
    

    @State  var Speeds = [String:Speed]()
    @State var running:Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        
        MenuBarExtra(currentNumber, systemImage: "\(currentNumber).circle") {
            if let upload = Speeds["Upload"]{
                if let speed =  upload.speed{
                    Text("Upload: \(String(speed)) \(upload.unit ?? "Mbps")")
                }
            }
            if let download = Speeds["Download"]{
                if let speed =  download.speed{
                    Text("Upload: \(String(speed)) \(download.unit ?? "Mbps")")
                    Text("Last Test: \(download.date?.formatted() ?? "unknown")")
                }
            }
            Divider()
            if running == false {
                Button("Run Test") {
                    Task{
                        await readNetworkStatus()
                    }
                }
            }else{
                Text("running")
            }
            
            Button("Export Data") {
            }.disabled(true)
            Button("Settings") {
            }.keyboardShortcut(",").disabled(true)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
                
            }.keyboardShortcut("q")

        }
    }
    
    func readNetworkStatus() async{
        running = true
        do {
            try await networkquality()
            running = false
        } catch {
            running = false
        }
    }
    
    private func networkquality() async throws{
        
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
        
        let UploadKeyword = "Uplink capacity: "
        let DownloadKeyword = "\nDownlink capacity: "
        let EndKeyword = "\nResponsiveness:"
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
    
}
