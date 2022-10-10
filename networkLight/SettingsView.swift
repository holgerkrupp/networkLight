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
    

    
    var body: some View {
        VStack{
            Text("Default Speeds")
                .onAppear(){
                    if let maxUpload = UserDefaults.standard.object(forKey: "MaxUpload") as? Float{
                        UploadSpeed = String(maxUpload)
                    }
                    if let maxDownload = UserDefaults.standard.object(forKey: "maxDownload") as? Float{
                        DownloadSpeed = String(maxDownload)
                    }
                }
            HStack{
                Text("Upload:")
                TextField("Upload Speed", text: $UploadSpeed)
                    .onSubmit {
                        if let uploadFloat = Float($UploadSpeed.wrappedValue){
                            UserDefaults.standard.setValue(uploadFloat, forKey: "MaxUpload")
                        }
                    }
                Text("Mbps")
                Divider()
                Text("Download:")
                TextField("Download Speed", text: $DownloadSpeed)
                    .onSubmit {
                        if let downloadFloat = Float($DownloadSpeed.wrappedValue){
                            UserDefaults.standard.setValue(downloadFloat, forKey: "maxDownload")
                        }
                    }
                Text("Mbps")
            }
            Divider()
            
        }
    }
    
    func setMax(key: String){
        
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
