//
//  SettingsView.swift
//  networkLight
//
//  Created by Holger Krupp on 10.10.22.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    
    
    
    @State var UploadSpeed = ""
    @State var DownloadSpeed = ""
    @Binding var SpeedLimits : [SpeedLimit]
    @Binding var repleattime :Int
    
    
    @State var refresh: Bool = false
    @FocusState private var focus: Int?
    
    var body: some View {
        VStack(alignment: .center, spacing: 12){
            Text("Default Speeds").bold()
                .onAppear(){
                    
                    if let maxUpload = UserDefaults.standard.object(forKey: "MaxUpload") as? Double{
                        UploadSpeed = String(maxUpload)
                    }
                    if let maxDownload = UserDefaults.standard.object(forKey: "maxDownload") as? Double{
                        DownloadSpeed = String(maxDownload)
                    }
                }
            HStack{
                Text("Upload:")
                TextField("Upload Speed", text: $UploadSpeed).frame(width: 60)
                    .onSubmit {
                        if let uploadFloat = Double($UploadSpeed.wrappedValue){
                            UserDefaults.standard.setValue(uploadFloat, forKey: "MaxUpload")
                        }
                    }
                Text("Mbps")
                Divider()
                Text("Download:")
                TextField("Download Speed", text: $DownloadSpeed).frame(width: 60)
                    .onSubmit {
                        if let downloadFloat = Double($DownloadSpeed.wrappedValue){
                            UserDefaults.standard.setValue(downloadFloat, forKey: "maxDownload")
                        }
                    }
                Text("Mbps")
            }.frame(height: 20).padding()
                
        }
            Divider()
        Text("Autorun").bold()
        VStack{
            HStack{
                
                Text("Autorun every ")
                
                TextField("Autorun", value: $repleattime, formatter: NumberFormatter()).frame(width: 60)
                //                    .onSubmit {
                //                        repleattime = Int($repleattime.wrappedValue) * 60
                //                        UserDefaults.standard.setValue(repleattime * 60, forKey: "repleattime")
                //
                //                    }
                Text(" Seconds.")
            }.padding()
            
        }
            Divider()
                Text("Limits").bold()
       
                ForEach($SpeedLimits) { $limit in
                    
                    HStack{
                        
                        TextField("upperlimit", value: $limit.upperlimit, format: .number).frame(width: 60)
                        TextField("Icon", text: $limit.icon).multilineTextAlignment(.center).frame(width: 30)
                        TextField("lowerlimit", value: $limit.lowerlimit, format: .number).frame(width: 60)
                    }.padding().frame(width: 100, alignment: .center).onChange(of: $limit.wrappedValue) { newValue in
                        self.refresh.toggle()
                    }
                }
        Divider()
       
        Button("Allow Notifications"){
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if success {
                    print("All set!")
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
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

        SettingsView(SpeedLimits: Speedlimits, repleattime: repeattime )
        
    }
}
