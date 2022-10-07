//
//  supportfunctions.swift
//  networkLight
//
//  Created by Holger Krupp on 07.10.22.
//

import Foundation


func removeObjectForKeyFromPersistentStorrage(_ key:String){
    UserDefaults.standard.removeObject(forKey: key)
}

func removePersistentStorrage(){
    let appdomain = Bundle.main.bundleIdentifier
    UserDefaults.standard.removePersistentDomain(forName: appdomain!)
}
