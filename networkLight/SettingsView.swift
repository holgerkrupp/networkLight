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
    @Binding var SpeedLimits : [SpeedLimit]
    @Binding var repleattime :Int

    
    var body: some View {
        VStack{
            Text("Default Speeds")
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
                
                TextField("Autorun", value: $repleattime, formatter: NumberFormatter())
//                    .onSubmit {
//                        repleattime = Int($repleattime.wrappedValue) * 60
//                        UserDefaults.standard.setValue(repleattime * 60, forKey: "repleattime")
//                        
//                    }
                Text(" Seconds.")
            }
            Divider()

                ForEach($SpeedLimits) { $limit in
                    HStack{
                        TextField("upperLimit", value: $limit.upperlimit, format: .number)
                        TextField("Icon", text: $limit.icon)
                        TextField("lowerlimit", value: $limit.upperlimit, format: .number)
                    }
                }
            
        }
    }
    

}



