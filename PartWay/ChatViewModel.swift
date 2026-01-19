//
//  ChatViewModel.swift
//  PartWay
//
//  Created by ʝє¢ку кυкα∂ιуα on 19/01/26.
//

import SwiftUI
import Combine
import PubNubSDK

// Helper function to generate readable username from UUID
func generateUsername(from uuid: String) -> String {
    // Extract last 4 characters from UUID for a short identifier
    let suffix = String(uuid.suffix(4))
    return "User\(suffix)"
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var username: String
    @Published var onlineUsers: [String] = []
    @Published var typingUsers: Set<String> = []
    
    private let pubnubService = PubNubService.shared
    private let channelName = "part-chat"
    private var listener: SubscriptionListener?
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    
    init() {
        // Generate username from PubNub userId (UUID)
        self.username = UUID().uuidString
        
        setupPubNub()
        setupTypingObserver()
    }
    
    private func setupTypingObserver() {
        $messageText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                
                // Cancel previous timer
                self.typingTimer?.invalidate()
                
                if !text.isEmpty {
                    // Send typing indicator
                    self.sendTypingIndicator(isTyping: true)
                    
                    // Set timer to send stopped typing after 2 seconds
                    self.typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                        self?.sendTypingIndicator(isTyping: false)
                    }
                } else {
                    // Send stopped typing immediately when text is cleared
                    self.sendTypingIndicator(isTyping: false)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPubNub() {
        // Create a subscription listener
        listener = SubscriptionListener()
        
        // Subscribe to messages
        listener?.didReceiveMessage = { [weak self] message in
            Task { @MainActor in
                self?.handleReceivedMessage(message)
            }
        }
        
        // Subscribe to presence events
        listener?.didReceivePresence = { [weak self] presence in
            Task { @MainActor in
                self?.handlePresenceEvent(presence)
            }
        }
        
        // Subscribe to signals (for typing indicators)
        listener?.didReceiveSignal = { [weak self] signal in
            Task { @MainActor in
                self?.handleSignal(signal)
            }
        }
        
        // Add the listener before subscribing
        pubnubService.pubnub.add(listener!)
        
        // Subscribe to the channel with presence
        pubnubService.pubnub.subscribe(to: [channelName], withPresence: true)
        
        // Get current online users
        fetchOnlineUsers()
        
        // Fetch message history
        fetchHistory()
    }
    
    private func handleReceivedMessage(_ messageEvent: PubNubMessage) {
        print("📨 Received message: \(messageEvent.payload)")
        
        // Extract dictionary from JSONCodable payload
        var payloadDict: [String: String] = [:]
        
        // Try different payload extraction methods
        if let dict = messageEvent.payload as? [String: String] {
            payloadDict = dict
        } else if let dict = messageEvent.payload as? [String: Any] {
            // Convert Any values to String
            for (key, value) in dict {
                payloadDict[key] = "\(value)"
            }
        } else {
            // Try to encode and decode the payload
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(messageEvent.payload)
                if let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                    payloadDict = dict
                } else if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    for (key, value) in dict {
                        payloadDict[key] = "\(value)"
                    }
                }
            } catch {
                print("❌ Failed to decode payload: \(error)")
                return
            }
        }
        
        guard let text = payloadDict["text"],
              let userId = payloadDict["userId"],
              let username = payloadDict["username"],
              let timestampString = payloadDict["timestamp"],
              let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
            print("❌ Failed to parse message: \(payloadDict)")
            return
        }
        
        let messageId = UUID().uuidString
        let message = Message(
            id: messageId,
            text: text,
            userId: userId,
            username: username,
            timestamp: timestamp
        )
        
        print("✅ Parsed message from \(username): \(text)")
        
        // Avoid duplicate messages (check by timestamp and user for recent duplicates)
        let isDuplicate = messages.contains { existingMessage in
            existingMessage.text == message.text &&
            existingMessage.userId == message.userId &&
            abs(existingMessage.timestamp.timeIntervalSince(message.timestamp)) < 1
        }
        
        if !isDuplicate {
            messages.append(message)
            messages.sort { $0.timestamp < $1.timestamp }
            print("💬 Total messages: \(messages.count)")
        } else {
            print("⚠️ Duplicate message ignored")
        }
    }
    
    private func handlePresenceEvent(_ presence: PubNubPresenceChange) {
        print("👤 Presence event on channel: \(presence.channel)")
        
        // Refresh the entire online users list on any presence change
        fetchOnlineUsers()
    }
    
    private func handleSignal(_ signal: PubNubMessage) {
        print("🔔 Signal received from \(signal.publisher ?? "unknown")")
        print("🔔 Signal payload: \(signal.payload)")
        print("🔔 Current userId: \(pubnubService.userId)")
        
        guard let publisher = signal.publisher,
              publisher != pubnubService.userId else { 
            print("🔔 Ignoring signal from self")
            return 
        }
        
        // Signal is now just "1" for typing or "0" for stopped
        let isTyping: Bool
        if let stringValue = signal.payload as? String {
            isTyping = stringValue == "1"
            print("🔔 Parsed signal as string: \(stringValue), isTyping: \(isTyping)")
        } else if let intValue = signal.payload as? Int {
            isTyping = intValue == 1
            print("🔔 Parsed signal as int: \(intValue), isTyping: \(isTyping)")
        } else {
            print("🔔 Failed to parse signal payload")
            return
        }
        
        if isTyping {
            typingUsers.insert(publisher)
            print("✅ Added \(publisher) to typingUsers. Total: \(typingUsers.count)")
        } else {
            typingUsers.remove(publisher)
            print("✅ Removed \(publisher) from typingUsers. Total: \(typingUsers.count)")
        }
    }
    
    func fetchOnlineUsers() {
        pubnubService.pubnub.hereNow(
            on: [channelName],
            completion: { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let response):
                        guard let self = self else { return }
                        // Extract UUIDs from the response
                        var allUsers: [String] = []
                        for (_, presence) in response {
                            // Occupants are already strings (UUIDs)
                            allUsers.append(contentsOf: presence.occupants)
                        }
                        self.onlineUsers = allUsers
                        print("👥 Fetched \(self.onlineUsers.count) online users")
                    case .failure(let error):
                        print("❌ Failed to fetch online users: \(error)")
                    }
                }
            }
        )
    }
    
    func sendTypingIndicator(isTyping: Bool) {
        // Send minimal signal - just 0 or 1
        let signal = isTyping ? "1" : "0"
        
        print("📤 Sending typing indicator: \(signal) on channel: \(channelName)")
        
        pubnubService.pubnub.signal(
            channel: channelName,
            message: AnyJSON(signal),
            completion: { result in
                switch result {
                case .success(let timetoken):
                    print("✅ Typing indicator sent: \(isTyping) at \(timetoken)")
                case .failure(let error):
                    print("❌ Failed to send typing indicator: \(error)")
                }
            }
        )
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let timestamp = Date()
        let messageDict: [String: String] = [
            "text": messageText,
            "userId": pubnubService.userId,
            "username": username,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        
        print("📤 Sending message: \(messageDict)")
        
        pubnubService.pubnub.publish(
            channel: channelName,
            message: AnyJSON(messageDict),
            completion: { result in
                switch result {
                case .success(let timetoken):
                    print("✅ Message sent successfully with timetoken: \(timetoken)")
                case .failure(let error):
                    print("❌ Failed to send message: \(error)")
                }
            }
        )
        
        // Stop typing indicator
        sendTypingIndicator(isTyping: false)
        typingTimer?.invalidate()
        
        messageText = ""
    }
    
    func fetchHistory() {
        print("📜 Fetching message history...")
        pubnubService.pubnub.fetchMessageHistory(
            for: [channelName],
            completion: { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let response):
                        guard let self = self else { return }
                        print("📜 History response received")
                        if let channelMessages = response.messagesByChannel[self.channelName] {
                            print("📜 Found \(channelMessages.count) historical messages")
                            for messageEvent in channelMessages {
                                self.handleReceivedMessage(messageEvent)
                            }
                        } else {
                            print("📜 No messages in channel \(self.channelName)")
                        }
                    case .failure(let error):
                        print("❌ Failed to fetch history: \(error)")
                    }
                }
            }
        )
    }
    
    deinit {
        typingTimer?.invalidate()
        
        // Send stopped typing signal (minimal payload)
        pubnubService.pubnub.signal(
            channel: channelName,
            message: AnyJSON("0"),
            completion: { _ in }
        )
        
        pubnubService.pubnub.unsubscribeAll()
    }
}
