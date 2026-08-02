//
//  Watch_BrowseApp.swift
//  Watch Browse Watch App
//
//  Created by Elliot Williams on 2025-07-16.
//

import SwiftUI

@main
struct BrowserApp: App {
    @StateObject private var viewModel = BrowserViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

// WatchOS: BrowserViewModel.swift
import Foundation
import WatchConnectivity

class BrowserViewModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var pageContent = "Enter URL and tap Load"
    @Published var urlInput = "https://apple.com"
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var session = WCSession.default
    private var requestID = UUID().uuidString
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession,
                activationDidCompleteWith activationState: WCSessionActivationState,
                error: Error?) {
        if let error = error {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }
    }
    
    func loadPage() {
        guard session.isReachable else {
            errorMessage = "iPhone not connected"
            return
        }
        
        isLoading = true
        errorMessage = ""
        requestID = UUID().uuidString
        
        let message: [String: Any] = [
            "url": urlInput,
            "id": requestID
        ]
        
        session.sendMessage(message, replyHandler: { reply in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let content = reply["content"] as? String {
                    self.pageContent = content
                } else if let error = reply["error"] as? String {
                    self.errorMessage = error
                    self.pageContent = "Load failed"
                }
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                self.pageContent = "Comms error"
            }
        })
    }
}

// WatchOS: ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: BrowserViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // URL Input
                TextField("Enter URL", text: $viewModel.urlInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(.bottom, 8)
                
                // Load Button
                Button(action: viewModel.loadPage) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Load Page")
                    }
                }
                .disabled(viewModel.isLoading)
                .buttonStyle(BorderedButtonStyle(tint: .blue))
                .padding(.bottom, 12)
                
                // Content Display
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.pageContent)
                        .font(.system(size: 14))
#if !os(watchOS)
                        .textSelection(.enabled)
#endif
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Error Message
                if !viewModel.errorMessage.isEmpty {
                    Text("Error: \(viewModel.errorMessage)")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Watch Browser")
    }
}

#Preview {
    ContentView()
}
