//
//  LoginView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with enhanced animations, haptic feedback, and asynchronous login simulation.

import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isAuthenticated = false
    @State private var authenticationError: String? = nil
    @State private var isLoading = false
    
    // Haptic feedback generator for login outcomes
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(NSLocalizedString("Welcome to Furfolio", comment: "Welcome message on login screen"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
                .accessibilityAddTraits(.isHeader)
                .transition(.opacity)
            
            // Username Input
            TextField(NSLocalizedString("Username", comment: "Placeholder for username input"), text: $username)
                .padding()
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                .accessibilityLabel(NSLocalizedString("Username", comment: "Accessibility label for username field"))
                .transition(.move(edge: .leading))
            
            // Password Input
            SecureField(NSLocalizedString("Password", comment: "Placeholder for password input"), text: $password)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                .accessibilityLabel(NSLocalizedString("Password", comment: "Accessibility label for password field"))
                .transition(.move(edge: .trailing))
            
            // Login Button
            Button(action: {
                login()
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text(NSLocalizedString("Login", comment: "Button label for logging in"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.blue)
            .cornerRadius(8)
            .accessibilityLabel(NSLocalizedString("Login Button", comment: "Accessibility label for login button"))
            .disabled(isLoading)
            .transition(.scale)
            
            // Authentication Error Message
            if let error = authenticationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.top, 10)
                    .accessibilityLabel(NSLocalizedString("Error Message", comment: "Accessibility label for error message"))
                    .transition(.opacity)
            }
            
            // Successful Authentication Message
            if isAuthenticated {
                Text(NSLocalizedString("Successfully Authenticated!", comment: "Message for successful login"))
                    .foregroundColor(.green)
                    .font(.headline)
                    .accessibilityLabel(NSLocalizedString("Success Message", comment: "Accessibility label for success message"))
                    .transition(.opacity)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .animation(.easeInOut, value: isAuthenticated)
    }
    
    /// Initiates the login process with an asynchronous simulation.
    private func login() {
        isLoading = true
        authenticationError = nil
        
        // Simulate a network authentication delay (e.g., 1.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            authenticateUser(username: username, password: password)
            isLoading = false
        }
    }
    
    /// Authenticates the user with provided credentials.
    private func authenticateUser(username: String, password: String) {
        // Example: Replace with actual secure authentication logic (e.g., using a backend service)
        let storedCredentials: [String: String] = [
            "lvconcepcion": "jesus2024" // Replace this with securely stored and hashed credentials
        ]
        
        // Check if username exists in the dictionary and the password matches
        if let storedPassword = storedCredentials[username], storedPassword == password {
            withAnimation {
                isAuthenticated = true
                authenticationError = nil
            }
            feedbackGenerator.notificationOccurred(.success)
        } else {
            withAnimation {
                isAuthenticated = false
                authenticationError = NSLocalizedString("Invalid username or password. Please try again.", comment: "Error message for invalid login credentials")
            }
            feedbackGenerator.notificationOccurred(.error)
        }
    }
}
