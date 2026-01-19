//
//  ChatView.swift
//  PartWay
//
//  Created by ʝє¢ку кυкα∂ιуα on 19/01/26.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var isEditingUsername = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Typing indicator below header
                if !viewModel.typingUsers.isEmpty {
                    HStack {
                        HStack(spacing: 4) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.6)
                                    .animation(
                                        Animation.easeInOut(duration: 0.6)
                                            .repeatForever()
                                            .delay(Double(index) * 0.2),
                                        value: viewModel.typingUsers.count
                                    )
                            }
                        }
                        
                        if viewModel.typingUsers.count == 1 {
                            let typingUser = viewModel.typingUsers.first!
                            Text("\(generateUsername(from: typingUser)) is typing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if viewModel.typingUsers.count == 2 {
                            let users = Array(viewModel.typingUsers)
                            Text("\(generateUsername(from: users[0])) and \(generateUsername(from: users[1])) are typing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if viewModel.typingUsers.count == 3 {
                            let users = Array(viewModel.typingUsers)
                            Text("\(generateUsername(from: users[0])), \(generateUsername(from: users[1])) and \(generateUsername(from: users[2])) are typing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            let users = Array(viewModel.typingUsers.prefix(2))
                            let remaining = viewModel.typingUsers.count - 2
                            Text("\(generateUsername(from: users[0])), \(generateUsername(from: users[1])) and \(remaining) others are typing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Online users banner
                if !viewModel.onlineUsers.isEmpty {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 8))
                        Text("\(viewModel.onlineUsers.count) online")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isCurrentUser: message.userId == PubNubService.shared.userId
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Message input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $viewModel.messageText)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit {
                            viewModel.sendMessage()
                        }
                    
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(viewModel.messageText.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(viewModel.messageText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("PartWay Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("\(viewModel.onlineUsers.count)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isEditingUsername = true
                    }) {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .alert("Change Username", isPresented: $isEditingUsername) {
                TextField("Username", text: $viewModel.username)
                Button("Cancel", role: .cancel) { }
                Button("Save") { }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.username)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .cornerRadius(20)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}

#Preview {
    ChatView()
}
