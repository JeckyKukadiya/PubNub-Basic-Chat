//
//  Message.swift
//  PartWay
//
//  Created by ʝє¢ку кυкα∂ιуα on 19/01/26.
//

import Foundation

struct Message: Identifiable, Codable {
    let id: String
    let text: String
    let userId: String
    let username: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, text: String, userId: String, username: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.userId = userId
        self.username = username
        self.timestamp = timestamp
    }
}
