//
//  network.swift
//  networkLight
//
//  Created by Holger Krupp on 14.10.22.
//

import Foundation
import Network

class MonitoringNetworkState: ObservableObject {
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    
    @Published var isConnected = false
    
    init() {
        monitor.start(queue: queue)
        
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                DispatchQueue.main.async {
                    self.isConnected = true
                    print("connected")
                }
            } else {
                DispatchQueue.main.async {
                    self.isConnected = false
                    print("disconnected")
                }
            }
        }
    }
    
}
