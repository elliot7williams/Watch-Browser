//
//  ContentView.swift
//  Watch Browser
//
//  Created by Elliot Williams on 2025-07-16.
//

import SwiftUI
import WatchConnectivity
import Foundation

@main
struct WebCompanionApp: App {
    @StateObject private var session = PhoneSessionManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var lastError = ""
    private var pendingRequests: [String: (Result<String, Error>) -> Void] = [:]
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession,
                activationDidCompleteWith activationState: WCSessionActivationState,
                error: Error?) {
        if let error = error {
            lastError = "Activation failed: \(error.localizedDescription)"
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    
    // Handle watch requests
    func session(_ session: WCSession,
                didReceiveMessage message: [String : Any],
                replyHandler: @escaping ([String : Any]) -> Void) {
        
        guard let urlString = message["url"] as? String,
              let requestId = message["id"] as? String else {
            replyHandler(["error": "Invalid request"])
            return
        }
        
        fetchWebContent(urlString: urlString) { result in
            switch result {
            case .success(let content):
                replyHandler(["content": content, "id": requestId])
            case .failure(let error):
                replyHandler(["error": error.localizedDescription, "id": requestId])
            }
        }
    }
    
    private func fetchWebContent(urlString: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 400, userInfo: nil)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "Data Error", code: 500, userInfo: nil)))
                return
            }
            
            // Extract readable text
            let plainText = html
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Limit to 5000 characters for watch
            let trimmedContent = String(plainText.prefix(5000))
            completion(.success(trimmedContent))
        }
        task.resume()
    }
}

struct ContentView: View {
    @EnvironmentObject var session: PhoneSessionManager
    
    var body: some View {
        VStack {
            Text("Web Companion Active")
                .font(.title)
            Text("Keep this app running in background")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !session.lastError.isEmpty {
                Text("Last Error:")
                    .padding(.top)
                Text(session.lastError)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
