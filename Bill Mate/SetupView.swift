//
//  SetupView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import SwiftUI
import GoogleSignInSwift

enum UserRole: String {
    case accountManager
    case resident
}

struct SetupView: View {
    @EnvironmentObject var auth: GoogleAuthManager

    @State private var selectedRole: UserRole? = nil
    @State private var isWorking: Bool = false

    // Manager name prompt
    @State private var showNamePrompt = false
    @State private var managerNameInput = ""

    // If a user already has a spreadsheet but no manager name, force prompt
    private var hasSpreadsheet: Bool {
        GoogleSheetsService.shared.getStoredSpreadsheetId() != nil
    }

    private var hasValidManagerName: Bool {
        guard let name = GoogleSheetsService.shared.getManagerName() else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Bill Mate")
                    .font(.largeTitle)

                // Role selection
                VStack(spacing: 10) {
                    Text("Choose your role")
                        .font(.headline)

                    Button {
                        selectedRole = .accountManager
                    } label: {
                        HStack {
                            Text("Account Manager")
                            Spacer()
                            if selectedRole == .accountManager {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        selectedRole = .resident
                    } label: {
                        HStack {
                            Text("Resident")
                            Spacer()
                            if selectedRole == .resident {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal)

                // Status (always visible)
                Text(auth.statusText)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Google Sign-In (requires role selection first)
                if auth.email == nil {
                    GoogleSignInButton {
                        auth.signIn()
                    }
                    .frame(height: 48)
                    .padding(.horizontal)
                    .disabled(selectedRole == nil || isWorking)
                    .opacity((selectedRole == nil || isWorking) ? 0.5 : 1.0)
                } else {
                    Text("Signed in as: \(auth.email ?? "")")
                        .font(.subheadline)
                }

                // Account Manager: Create Home
                if selectedRole == .accountManager, auth.email != nil {
                    Button(isWorking ? "Working..." : "Create Home") {
                        // Always start with a clean, editable name
                        managerNameInput = (GoogleSheetsService.shared.getManagerName() ?? "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        showNamePrompt = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                    .opacity(isWorking ? 0.5 : 1.0)
                    .padding(.horizontal)

                    // Helpful hint if spreadsheet exists but manager name is missing
                    if hasSpreadsheet && !hasValidManagerName {
                        Text("This home needs a manager name. Tap Create Home to set it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                // Resident: Join Home (token)
                if selectedRole == .resident, auth.email != nil {
                    NavigationLink {
                        ResidentJoinView()
                    } label: {
                        Text("Enter Invite Token")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }

                // Sign out (only when signed in)
                if auth.isSignedIn {
                    Button("Sign out") {
                        auth.signOut()
                        GoogleSheetsService.shared.clearStoredSpreadsheetId()
                        // If you added clearManagerName(), uncomment:
                        // GoogleSheetsService.shared.clearManagerName()
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
            .onAppear {
                // If user lands here signed in + manager role selected (or already stored),
                // and manager name is missing, force the prompt.
                if auth.isSignedIn,
                   selectedRole == .accountManager,
                   !hasValidManagerName {
                    managerNameInput = ""
                    showNamePrompt = true
                }
            }
            .onChange(of: selectedRole) { newRole in
                // If they pick Account Manager and are already signed in,
                // prompt immediately when manager name is missing.
                if auth.isSignedIn,
                   newRole == .accountManager,
                   !hasValidManagerName {
                    managerNameInput = ""
                    showNamePrompt = true
                }
            }
            .alert("Enter your name", isPresented: $showNamePrompt) {
                TextField("Name", text: $managerNameInput)

                Button("Save") {
                    let name = managerNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else {
                        auth.statusText = "❌ Please enter a name."
                        return
                    }

                    // If they already have a spreadsheet (existing home),
                    // just store the name so Dashboard can work immediately.
                    if hasSpreadsheet {
                        GoogleSheetsService.shared.storeManagerName(name)
                        auth.statusText = "✅ Manager name saved"
                        return
                    }

                    // Otherwise create the home fully (creates spreadsheet + tabs + headers)
                    isWorking = true
                    auth.statusText = "⏳ Creating/loading home..."

                    GoogleSheetsService.shared.createHome(managerName: name) { result in
                        DispatchQueue.main.async {
                            isWorking = false
                            switch result {
                            case .success:
                                auth.statusText = "✅ Home ready"
                            case .failure(let error):
                                auth.statusText = "❌ \(error.localizedDescription)"
                            }
                        }
                    }
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This name will be used as the home manager.")
            }
        }
    }
}
