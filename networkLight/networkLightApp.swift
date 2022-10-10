//
//  networkLightApp.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI
import CoreData


struct Speed{
    var id = UUID()
    var speed: Double?
    var unit: String?
    var date: Date?
    var icon: String?
}
struct SpeedLimit: Identifiable, Codable{
    var upperlimit: Double?
    var lowerlimit: Double?
    var icon: String?
    var id = UUID()
    
    enum CodingKeys: CodingKey{
        case upperlimit, lowerlimit, icon, id
    }
    
    init(upperlimit: Double, lowerlimit: Double, icon: String){
        self.upperlimit = upperlimit
        self.lowerlimit = lowerlimit
        self.icon = icon
    }
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self){
            self.upperlimit = try! container.decode(Double.self, forKey: .upperlimit)
            self.lowerlimit = try! container.decode(Double.self, forKey: .lowerlimit)
            self.icon = try! container.decode(String.self, forKey: .icon)
            self.id = UUID()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(upperlimit, forKey: .upperlimit)
        try container.encode(lowerlimit, forKey: .lowerlimit)
        try container.encode(icon, forKey: .icon)
        
    }
}

@main

struct networkLightApp: App {

    
    let persistenceController = PersistenceController.shared
    let viewContext = PersistenceController.shared.container.viewContext
    
    @State var currentNumber: String = "1"
    
    @State var Speeds = [String:Speed]()
    @State var running:Bool = false
    @State var SpeedLimits:[SpeedLimit]?
    
    @State var timer:Timer? = nil
    @State var timerrunning:Bool = false
    var repleattime = 10*60 // in seconds
    


    var maxSpeeds:[String:Speed] = [
        "Download":Speed(id: UUID(), speed: 100, unit: "Mbps", date: Date(), icon: nil),
        "Upload":Speed(id: UUID(), speed: 30, unit: "Mbps", date: Date(), icon: nil)
    ]
    
    var body: some Scene {
   
//        WindowGroup(id: "Settings") {
//            Text("Settings Window")
//        }
            WindowGroup("Settings Window") {
                SettingsView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }.handlesExternalEvents(matching: Set(arrayLiteral: "SettingsWindow"))
        
        
        MenuBarExtra {
            Group{
                if let upload = Speeds["Upload"]{
                    if let speed =  upload.speed{
                        Text("\(upload.icon ?? "") Upload: \(String(format: "%.0f",speed)) \(upload.unit ?? "Mbps")")
                    }
                }
                if let download = Speeds["Download"]{
                    if let speed =  download.speed{
                        Text("\(download.icon ?? "") Download: \(String(format: "%.0f",speed)) \(download.unit ?? "Mbps")")
                        Text("Last Test: \(download.date?.formatted() ?? "unknown")")
                    }
                }
                Divider()
            }
            if running == false {
                Button("Run Test") {
                    Task{
                        await readNetworkStatus()
                    }
                }
            }else{
                Text("running")
            }
            
            if (timerrunning == true){
                Button("Stop autorun"){
                    stopTimer()
                }
            }else{
                Button("Autorun every 10 Minutes"){
                    startTimer()
                }
            }
            

            
            Button("Settings") {
                OpenWindows.Settingsview.open()
            }.keyboardShortcut(",")
            
            
            Divider()
            
            Button("Quit") {
                timer?.invalidate()
                NSApplication.shared.terminate(nil)
                
            }.keyboardShortcut("q")
           
            HistoryView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)

            
        }label: {
            Text(Speeds["Download"]?.icon?.description ?? "⚪️").onAppear(){
                Task{
                    readSpeedLimits()
                }
            }
        }
    }
    
    enum OpenWindows: String, CaseIterable {
        case Settingsview = "SettingsWindow"
        //As many views as you need.
        
        func open(){
            if let url = URL(string: "networkLight://\(self.rawValue)") { //replace myapp with your app's name
                NSWorkspace.shared.open(url)
            }
        }
    }
    
     func startTimer(){
         timerrunning = true
         timer = Timer.init(timeInterval: TimeInterval(repleattime), repeats: true, block: { timer in
                Task{
                    await readNetworkStatus()
                }
            })
            RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
         timer?.fire()
    }
    
    
     func stopTimer(){
         timerrunning = false
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    
    func readSpeedLimits(){
        print("readLimits")
        if let limits = UserDefaults.standard.object(forKey: "SpeedLimits"){
            
            SpeedLimits = try? JSONDecoder().decode([SpeedLimit].self, from: limits as! Data)
        }else{

            SpeedLimits = [
                SpeedLimit(upperlimit: 100.0,lowerlimit: 70.0,icon: "🟢"),
                SpeedLimit(upperlimit: 70.0,lowerlimit: 20.0,icon: "🟡"),
                SpeedLimit(upperlimit: 20.0,lowerlimit: 0.0,icon: "🔴")
            ]
            if let encoded = try? JSONEncoder().encode(SpeedLimits){
                UserDefaults.standard.set(encoded, forKey: "SpeedLimits")
            }else{
                NSLog("Could not encode \(String(describing: SpeedLimits?.debugDescription)) for key \("SpeedLimits")")
            }
        }
    }

    func readNetworkStatus() async{
        print("reading NetworkStatus")
        running = true
        do {
            try await networkquality()
            addItem()
            running = false
        } catch {
            running = false
        }
    }
    
    private func addItem() {
        withAnimation {
            let newSpeedLog = SpeedLog(context: viewContext)
            if let download = Speeds["Download"]?.speed{
                newSpeedLog.download = download
            }
            if let upload = Speeds["Upload"]?.speed{
                newSpeedLog.upload = upload
            }
            if let date = Speeds["Upload"]?.date{
                newSpeedLog.date = date
            }

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
        let ResponsivenessKeyword = "\nResponsiveness: "
   //     let EndKeyword = "\nIdle Latency:"
        let now = Date()
        
        if let UploadRangeStart = output.range(of: UploadKeyword)?.upperBound, let UploadRangeEnd = output.range(of: DownloadKeyword)?.lowerBound{
            
            let UploadRange = Range(uncheckedBounds: (lower: UploadRangeStart, upper: UploadRangeEnd))
            
            let UploadComponents = output[UploadRange].components(separatedBy: " ")
            
            var Upload = Speed(speed: Double(UploadComponents[0]), unit: UploadComponents[1], date: now)
            if let limits = SpeedLimits, let speed = Upload.speed, let max = maxSpeeds["Upload"]?.speed{
                let ratio = speed/max*100
                if ratio > 100{
                    Upload.icon = limits.first?.icon
                }else{
                    let limit = limits.filter { $0.upperlimit ?? 0.0 > ratio && $0.lowerlimit ?? 0.0 < ratio}
                    Upload.icon = limit.first?.icon
                }
            }
            Speeds.updateValue(Upload, forKey: "Upload")
        }
        
        if let DownloadRangeStart = output.range(of: DownloadKeyword)?.upperBound, let DownloadRangeEnd = output.range(of: ResponsivenessKeyword)?.lowerBound {
            let DownloadRange = Range(uncheckedBounds: (lower: DownloadRangeStart, upper: DownloadRangeEnd))
            
            let DownloadComponents = output[DownloadRange].components(separatedBy: " ")
            var Download = Speed(speed: Double(DownloadComponents[0]), unit: DownloadComponents[1], date: now)

            if let limits = SpeedLimits, let speed = Download.speed, let max = maxSpeeds["Download"]?.speed{
                let ratio = speed/max*100
                if ratio > 100{
                    Download.icon = limits.first?.icon
                }else{
                    let limit = limits.filter { $0.upperlimit ?? 0.0 > ratio && $0.lowerlimit ?? 0.0 < ratio}
                    Download.icon = limit.first?.icon
                }


            }
            Speeds.updateValue(Download, forKey: "Download")
            
        }
        
//        if let DownloadRangeStart = output.range(of: ResponsivenessKeyword)?.upperBound, let DownloadRangeEnd = output.range(of: EndKeyword)?.lowerBound {
//            let DownloadRange = Range(uncheckedBounds: (lower: DownloadRangeStart, upper: DownloadRangeEnd))
//
//            let DownloadComponents = output[DownloadRange].components(separatedBy: " ")
//            var Download = Speed(speed: Double(DownloadComponents[0]), unit: DownloadComponents[1], date: now)
//
//            if let limits = SpeedLimits, let speed = Download.speed, let max = maxSpeeds["Download"]?.speed{
//                let ratio = speed/max*100
//
//                let limit = limits.filter { $0.upperlimit ?? 0.0 > ratio && $0.lowerlimit ?? 0.0 < ratio}
//                Download.icon = limit.first?.icon
//            }
//            Speeds.updateValue(Download, forKey: "Download")
//
//        }
        
        dump(Speeds)
    }
    
    
    

    
    
    
}
