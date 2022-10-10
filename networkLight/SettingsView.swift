//
//  SettingsView.swift
//  networkLight
//
//  Created by Holger Krupp on 10.10.22.
//

import SwiftUI

struct SettingsView: View {
    
    
    
    @State var UploadSpeed = ""
    @State var DownloadSpeed = ""
    @State var SpeedLimits:[SpeedLimit]?
    @State var repleattime = String((UserDefaults.standard.object(forKey: "repleattime") as? Int ?? 600)/60)

    
    var body: some View {
        VStack{
            Text("Default Speeds")
                .onAppear(){
                    readSpeedLimits()
                    if let maxUpload = UserDefaults.standard.object(forKey: "MaxUpload") as? Double{
                        UploadSpeed = String(maxUpload)
                    }
                    if let maxDownload = UserDefaults.standard.object(forKey: "maxDownload") as? Double{
                        DownloadSpeed = String(maxDownload)
                    }
                }
            HStack{
                Text("Upload:")
                TextField("Upload Speed", text: $UploadSpeed)
                    .onSubmit {
                        if let uploadFloat = Double($UploadSpeed.wrappedValue){
                            UserDefaults.standard.setValue(uploadFloat, forKey: "MaxUpload")
                        }
                    }
                Text("Mbps")
                Divider()
                Text("Download:")
                TextField("Download Speed", text: $DownloadSpeed)
                    .onSubmit {
                        if let downloadFloat = Double($DownloadSpeed.wrappedValue){
                            UserDefaults.standard.setValue(downloadFloat, forKey: "maxDownload")
                        }
                    }
                Text("Mbps")
            }
            Divider()
            HStack{
                Text("Autorun every ")
                TextField("Autorun", text: $repleattime)
                    .onSubmit {
                        if let repleattime = Int($repleattime.wrappedValue){
                            UserDefaults.standard.setValue(repleattime * 60, forKey: "repleattime")
                        }
                    }
                Text(" Minutes.")
            }
            Divider()
            Table(SpeedLimits ?? []){
                TableColumn("Upperlimit [%]") { speed in
                    Text(speed.upperlimit ?? 0, format: .number)
                }
                TableColumn("Icon") { speed in
                    Text(speed.icon ?? "")
                }
                TableColumn("Lowerlimit [%]") { speed in
                    Text(speed.lowerlimit ?? 0, format: .number)
                }
            }
            
           
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
}


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
