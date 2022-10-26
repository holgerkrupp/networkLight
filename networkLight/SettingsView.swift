//
//  SettingsView.swift
//  networkLight
//
//  Created by Holger Krupp on 10.10.22.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    

    @Binding var maxUpload: Double
    @Binding var maxDownload: Double
    
    @Binding var SpeedLimits : [SpeedLimit]
    @Binding var repleattime :Int
    
    @State var notificationSettings: UNNotificationSettings?
    
    
    @State var refresh: Bool = false
    @FocusState private var focus: Int?
    
    var body: some View {
        VStack(alignment: .center, spacing: 12){
            Text("Default Speeds").bold()

            HStack{
                Text("Upload:")
                TextField("Upload Speed", value: $maxUpload, format: .number).frame(width: 60)

                Text("Mbps")
                Divider()
                Text("Download:")
                TextField("Download Speed", value: $maxDownload, format: .number).frame(width: 60)

                Text("Mbps")
            }.frame(height: 20).padding()
                
        }
            Divider()
        Text("Autorun").bold()
        VStack{
            HStack{
                
                Text("Autorun every ")
                
                TextField("Autorun", value: $repleattime, formatter: NumberFormatter()).frame(width: 60)
                Text(" Seconds.")
            }.padding()
            
        }
            Divider()
                Text("Limits [%]").bold()
       
                ForEach($SpeedLimits) { $limit in
                    
                    HStack{
                        
                        TextField("upperlimit", value: $limit.upperlimit, format: .number).frame(width: 60)
                        TextField("Icon", text: $limit.icon).multilineTextAlignment(.center).frame(width: 30)
                        TextField("lowerlimit", value: $limit.lowerlimit, format: .number).frame(width: 60)
                    }.padding().frame(width: 100, alignment: .center).onChange(of: $limit.wrappedValue) { newValue in
                        self.refresh.toggle()
                    }
                }
        Divider().onAppear(){
            getNotificationSettings()
        }
        Text("Notifications").bold()

        if notificationSettings?.authorizationStatus != .authorized{
            Button("Allow Notifications"){
                if notificationSettings?.authorizationStatus == .denied{
                    openSystemPrefs()
                }else{
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
                        if success {
                            print("All set!")
                        } else if let error = error {
                            print(error.localizedDescription)
                        }
                    }
                }
   
            }
        }else{
            
            Button("Manage Notification Settings"){
                
                openSystemPrefs()
            }

        }

        let
    VersionNumber = "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0") - (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0000"))"
    Text(VersionNumber)
        
    }
    
    func openSystemPrefs(){
        let prefsURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?\(Bundle.main.bundleIdentifier ?? "")")!
        print(prefsURL)
        
        NSWorkspace.shared.open(prefsURL)
    }
    func getNotificationSettings(){
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.notificationSettings = settings
        }
    }

}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let Speedlimits = Binding<[SpeedLimit]> {
            [SpeedLimit(upperlimit: 100.0,lowerlimit: 70.0,icon: "🟢"),
            SpeedLimit(upperlimit: 70.0,lowerlimit: 20.0,icon: "🟡"),
            SpeedLimit(upperlimit: 20.0,lowerlimit: 0.0,icon: "🔴")]
        } set: { speed in
            dump(speed)
        }
        let repeattime = Binding<Int> {
            50
        } set: { time in
            dump(time)
        }
        
        let maxDownload = Binding<Double>{
            100.0
        } set:{ speed in
            dump(speed)
        }
        
        let maxUpload = Binding<Double>{
            20.0
        } set:{ speed in
            dump(speed)
        }

        SettingsView(maxUpload: maxUpload, maxDownload: maxDownload, SpeedLimits: Speedlimits, repleattime: repeattime)
        
    }
}
