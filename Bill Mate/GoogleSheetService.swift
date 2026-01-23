//
//  GoogleSheetService.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/22/26.
//

import Foundation
import GoogleSignIn

final class GoogleSheetsService {

    static let shared = GoogleSheetsService()
    private init() {}

    private let storedSpreadsheetIdKey = "billmate_spreadsheet_id"

    func getStoredSpreadsheetId() -> String? {
        UserDefaults.standard.string(forKey: storedSpreadsheetIdKey)
    }

    func storeSpreadsheetId(_ id: String) {
        UserDefaults.standard.set(id, forKey: storedSpreadsheetIdKey)
    }

    /// Creates the spreadsheet if you don't already have one stored.
    /// Returns the spreadsheetId.
    func createSpreadsheetIfNeeded(completion: @escaping (Result<String, Error>) -> Void) {
        if let existing = getStoredSpreadsheetId() {
            DispatchQueue.main.async { completion(.success(existing)) }
            return
        }

        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            DispatchQueue.main.async {
                completion(.failure(NSError(
                    domain: "BillMate",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "No signed-in user"]
                )))
            }
            return
        }

        // Refresh tokens if needed, then use access token for Sheets API calls
        currentUser.refreshTokensIfNeeded { [weak self] user, error in
            guard let self else { return }

            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let user = user else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "BillMate",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "No user returned from refresh"]
                    )))
                }
                return
            }

            // ✅ tokenString is a NON-optional String (no guard-let needed)
            let accessToken = user.accessToken.tokenString

            self.createSpreadsheet(accessToken: accessToken, completion: completion)
        }
    }

    private func createSpreadsheet(accessToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "properties": ["title": "Bill Mate"],
            "sheets": [
                ["properties": ["title": "Bills"]],
                ["properties": ["title": "Payments"]]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "BillMate",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No HTTP response"]
                    )))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "BillMate",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "No data returned"]
                    )))
                }
                return
            }

            // Helpful debug if API fails
            guard (200...299).contains(http.statusCode) else {
                let raw = String(data: data, encoding: .utf8) ?? "(unreadable)"
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "BillMate",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Google API error \(http.statusCode): \(raw)"]
                    )))
                }
                return
            }

            do {
                let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let spreadsheetId = obj?["spreadsheetId"] as? String {
                    DispatchQueue.main.async { completion(.success(spreadsheetId)) }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "BillMate",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Could not find spreadsheetId in response"]
                        )))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
