//
//  networkLightApp.swift
//  networkLight
//
//  Created by Holger Krupp on 05.10.22.
//

import SwiftUI
import CoreData
import UserNotifications


struct Speed{
    var id = UUID()
    var speed: Double?
    var unit: String?
    var date: Date?
    var icon: String?
}
struct SpeedLimit: Identifiable, Codable, Equatable{

    
    var upperlimit: Double
    var lowerlimit: Double
    var icon: String
    var id: UUID
    
    enum CodingKeys: CodingKey{
        case upperlimit, lowerlimit, icon, id
    }
    
    init(upperlimit: Double, lowerlimit: Double, icon: String){
        self.upperlimit = upperlimit
        self.lowerlimit = lowerlimit
        self.icon = icon
        self.id = UUID()
    }
    
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self){
            self.upperlimit = try! container.decode(Double.self, forKey: .upperlimit)
            self.lowerlimit = try! container.decode(Double.self, forKey: .lowerlimit)
            self.icon = try! container.decode(String.self, forKey: .icon)
            do{
                self.id = try container.decode(UUID.self, forKey: .id)
            }catch{
                self.id = UUID()
            }
        }else{
            self.upperlimit = 0
            self.lowerlimit = 0
            self.icon = "🟣"
            self.id = UUID()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(upperlimit, forKey: .upperlimit)
        try container.encode(lowerlimit, forKey: .lowerlimit)
        try container.encode(icon, forKey: .icon)
        try container.encode(id, forKey: .id)
    }
    
    static func == (lhs: SpeedLimit, rhs: SpeedLimit) -> Bool {
        return
        lhs.upperlimit == rhs.upperlimit &&
        lhs.lowerlimit == rhs.lowerlimit
    }
}

@main

struct networkLightApp: App {

    
    let persistenceController = PersistenceController.shared
    let viewContext = PersistenceController.shared.container.viewContext
    
  //  @State var connected = MonitoringNetworkState()

    @State var Speeds = [String:Speed]()
    @State var running:Bool = false
    
    @State var shouldSendNotification:Bool = false
    
   var SpeedLimits: Binding<[SpeedLimit]> { Binding(
        get: {if let limits = UserDefaults.standard.object(forKey: "SpeedLimits"){
            

            do {
                let decoded =  try JSONDecoder().decode([SpeedLimit].self, from: limits as! Data)
                return decoded
            }catch{
                print("could not decode Speedlimits")
            }
        }
            return  [
                SpeedLimit(upperlimit: 100.0,lowerlimit: 70.0,icon: "🟢"),
                SpeedLimit(upperlimit: 70.0,lowerlimit: 20.0,icon: "🟡"),
                SpeedLimit(upperlimit: 20.0,lowerlimit: 0.0,icon: "🔴")
            ]
        
            
        },
        set: {limits in

            
            do{
                let JSON = try JSONEncoder().encode(limits)
                UserDefaults.standard.set(JSON, forKey: "SpeedLimits")
                
            }catch{
                print("could not save Speedlimits to UserDefaults")
            }
        }
    )
        
    }
    
    
    @State var timer:Timer? = nil
    @State var timerrunning:Bool = false
    
    @State var maxDownload = UserDefaults.standard.object(forKey: "maxDownload") as? Double ?? 100.0
    @State var maxUpload = UserDefaults.standard.object(forKey: "maxUpload") as? Double ?? 20.0

    @State var repleattime = UserDefaults.standard.object(forKey: "repleattime") as? Int ?? 600 {
        willSet{
            UserDefaults.standard.set(repleattime, forKey: "repleattime")
        }
    }

    var maxSpeeds:[String:Speed] = [
        "Download":Speed(id: UUID(), speed: 100, unit: "Mbps", date: Date(), icon: nil),
        "Upload":Speed(id: UUID(), speed: 30, unit: "Mbps", date: Date(), icon: nil)
    ]
    
 
    
    var body: some Scene {
   
        WindowGroup("NetworkLight") {
            VStack{
                Text("Warning").bold()
                Text("For debugging purpose only")
                Text("This App might slow down your Network traffic. Please verify with other users on your network the usage of this app.")
//                Button("Understood") {
//                    //NSApplication.shared.keyWindow?.close()
//                    NSApplication.shared.mainWindow?.close()
//                }
            }
        }.handlesExternalEvents(matching: Set(arrayLiteral: "NetworkLight"))
        
            WindowGroup("Settings") {
                SettingsView( SpeedLimits: SpeedLimits, repleattime: $repleattime)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                    .frame(width: 500, height: 800)
//                    .frame(minWidth: 250, maxWidth: .infinity,
//                           minHeight: 600, maxHeight: .infinity)

            }
            .defaultSize(width: 400, height: 600)
            .handlesExternalEvents(matching: Set(arrayLiteral: "SettingsWindow"))
            
        
        WindowGroup("History") {
            HistoryView(compact: false)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)

        }.defaultSize(width: 500, height: 600)
        .handlesExternalEvents(matching: Set(arrayLiteral: "HistoryWindow"))
        
        MenuBarExtra {
           
         //   Text(connected.isConnected ? "connected" : "no connection")
            
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
                Button("Run Now") {
                    Task{
                        await readNetworkStatus()
                    }
                }.keyboardShortcut("N")
            }else{
                Text("running")
            }
            
            if (timerrunning == true){
                let nextrun = timer?.fireDate.formatted(date: .omitted, time: .shortened)
                Button("Stop autorun - next: \(nextrun ?? "-")"){
                    stopTimer()
                }
            }else{
                
                Button("Autorun every \(String(repleattime/60)) Minutes"){
                    startTimer()
                    setSleepTimerRestart()
                }
                
            }
      

            
            Button("Settings") {
                OpenWindows.Settingsview.open()
            }.keyboardShortcut(",")
            
            Button("History") {
                OpenWindows.Historyview.open()
            }.keyboardShortcut("H")
            
            HistoryView(compact: true)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            
            
            
            
            
            
            Divider()
            
            
            
            Button("Quit") {
                timer?.invalidate()
                NSApplication.shared.terminate(nil)
                
            }.keyboardShortcut("q")



            
        }label: {
                
            Text(running ? "🔘" : Speeds["Download"]?.icon?.description ?? "⚪️")

            //Text(connected.isConnected ? Speeds["Download"]?.icon?.description ?? "⚪️" : "⚫️")
            
//            if connected.isConnected == true { // there should be a check if network is available, but all solutions block the UI.
//
//                if running == true {
//                    Text("🔘").environmentObject(MonitoringNetworkState())
//
//                }else{
//
//                    Text(Speeds["Download"]?.icon?.description ?? "⚪️")

//
//                }
//
//            }else{
//                // no network available
//                Text("⚫️").onAppear(){
//
//                    Speeds["Download"]?.speed = 0.0
//                    Speeds["Upload"]?.speed = 0.0
//                    Speeds["Download"]?.date = Date()
//                    Speeds["Upload"]?.date = Date()
//                    addItem()
//
//                }
//            }
        }
        
    }
    
    enum OpenWindows: String, CaseIterable {
        case Settingsview = "SettingsWindow"
        case Historyview = "HistoryWindow"
        //As many views as you need.
        
        func open(){
//            repleattime = UserDefaults.standard.object(forKey: "repleattime") as? Int ?? 600
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
    
    func setSleepTimerRestart(){
        print("register Notification / Timer")
        let notificationCenter = NSWorkspace.shared.notificationCenter
        let mainQueue = OperationQueue.main
        
        notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification , object: nil, queue: mainQueue) { notification in
            // restart timer if the mac wakes up from sleep
            if self.timerrunning{
                stopTimer()
                startTimer()
            }else{
                print("Timer was not running during sleep")
            }
        }
    }
    
    
    func sendNotification(){
        print("sendNotification")
        if shouldSendNotification == true{
            print("should send")
            let content = UNMutableNotificationContent()
            content.title = "Network speed low"
            content.subtitle = Speeds["Upload"]?.date?.formatted() ?? Date().formatted()
            content.body = "U: \(Speeds["Upload"]?.icon ?? "") \(String(format: "%.0f",Speeds["Upload"]?.speed ?? 0.0)) \(Speeds["Upload"]?.unit ?? "Mbps") \nD: \(Speeds["Download"]?.icon ?? "") \(String(format: "%.0f",Speeds["Download"]?.speed ?? 0.0)) \(Speeds["Download"]?.unit ?? "Mbps")"
            
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "networkLight.lowSpeed", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
            shouldSendNotification = false
        }

    }


    func readNetworkStatus() async{
        
        maxDownload = UserDefaults.standard.object(forKey: "maxDownload") as? Double ?? 100.0
        maxUpload = UserDefaults.standard.object(forKey: "maxUpload") as? Double ?? 20.0
        print("maxDownload: \(maxDownload.description) - maxUpload: \(maxUpload.description)")
        running = true
        do {
            try await networkquality()
            addItem()
            sendNotification()
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
        print("networkquality")
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
            if Upload.unit == "Kbps" {
                Upload.speed = (Upload.speed ?? 0.0)/1000
            }
            if let speed = Upload.speed{
                let ratio = speed/maxUpload*100
                if ratio > 100{
                    Upload.icon = SpeedLimits.first?.icon.wrappedValue
                }else{
                    let limit = SpeedLimits.filter { $0.upperlimit.wrappedValue > ratio && $0.lowerlimit.wrappedValue < ratio}
                    Upload.icon = limit.first?.icon.wrappedValue
                    
                    if Upload.icon == SpeedLimits.last?.icon.wrappedValue {
                        shouldSendNotification = true
                    }
                }
            }
            Speeds.updateValue(Upload, forKey: "Upload")
        }
        
        if let DownloadRangeStart = output.range(of: DownloadKeyword)?.upperBound, let DownloadRangeEnd = output.range(of: ResponsivenessKeyword)?.lowerBound {
            let DownloadRange = Range(uncheckedBounds: (lower: DownloadRangeStart, upper: DownloadRangeEnd))
            
            let DownloadComponents = output[DownloadRange].components(separatedBy: " ")
            var Download = Speed(speed: Double(DownloadComponents[0]), unit: DownloadComponents[1], date: now)

            if Download.unit == "Kbps" {
                Download.speed = (Download.speed ?? 0.0)/1000
            }
            
            if let speed = Download.speed{
                let ratio = speed/maxDownload*100
                if ratio > 100{
                    Download.icon = SpeedLimits.first?.icon.wrappedValue
                }else{
                    let limit = SpeedLimits.filter { $0.upperlimit.wrappedValue > ratio && $0.lowerlimit.wrappedValue < ratio}
                    Download.icon = limit.first?.icon.wrappedValue
                    
                    if Download.icon == SpeedLimits.last?.icon.wrappedValue {
                        shouldSendNotification = true
                    }
                }


            }
            Speeds.updateValue(Download, forKey: "Download")
            
        }

    }
    
    
    

    
    
    
}
