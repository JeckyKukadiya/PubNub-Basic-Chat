//
//  PubNubViewModel.swift
//  PartWay
//
//  Created by ʝє¢ку кυкα∂ιуα on 19/01/26.
//

import SwiftUI
import PubNubSDK

final class PubNubService {
    static let shared = PubNubService()
    let pubnub: PubNub
    let userId: String
    
    private init() {
        // Get or create persistent userId from UserDefaults
        if let storedUserId = UserDefaults.standard.string(forKey: "persistentUserId") {
            self.userId = storedUserId
        } else {
            let newUserId = UUID().uuidString
            UserDefaults.standard.set(newUserId, forKey: "persistentUserId")
            self.userId = newUserId
        }
        
        let configuration = PubNubConfiguration(
            publishKey: "pub-c-cc5ae0d7-3298-4f65-a00a-6d89ac8ef3fc",
            subscribeKey: "sub-c-c2f2b7b6-58f8-4c05-a50e-13ec3b840a3b",
            userId: userId
        )
        self.pubnub = PubNub(configuration: configuration)
    }
}
