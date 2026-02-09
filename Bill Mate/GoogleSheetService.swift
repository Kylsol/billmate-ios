//
//  GoogleSheetService.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 1/22/26.
//

import Foundation
import GoogleSignIn

final class GoogleSheetsService {

    // MARK: - Singleton

    static let shared = GoogleSheetsService()
    private init() {}

    // MARK: - Keys

    private let storedSpreadsheetIdKey = "billmate_spreadsheet_id"
    private let managerNameKey = "billmate_manager_name"

    // MARK: - Manager name storage

    func getManagerName() -> String? {
        UserDefaults.standard.string(forKey: managerNameKey)
    }

    func storeManagerName(_ name: String) {
        UserDefaults.standard.set(name, forKey: managerNameKey)
    }
    
    func clearManagerName() {
        UserDefaults.standard.removeObject(forKey: managerNameKey)
    }


    // MARK: - Errors

    enum SheetsError: LocalizedError {
        case notSignedIn
        case noStoredSpreadsheetId
        case badURL
        case badResponse
        case http(status: Int, body: String)
        case missingField(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "No signed-in Google user."
            case .noStoredSpreadsheetId:
                return "No stored spreadsheet ID yet. Create/Load a spreadsheet first."
            case .badURL:
                return "Could not build request URL."
            case .badResponse:
                return "No valid HTTP response."
            case .http(let status, let body):
                return "Google API error \(status): \(body)"
            case .missingField(let field):
                return "Missing field in response: \(field)"
            }
        }
    }

    // MARK: - Storage

    func getStoredSpreadsheetId() -> String? {
        UserDefaults.standard.string(forKey: storedSpreadsheetIdKey)
    }

    func storeSpreadsheetId(_ id: String) {
        UserDefaults.standard.set(id, forKey: storedSpreadsheetIdKey)
    }

    func clearStoredSpreadsheetId() {
        UserDefaults.standard.removeObject(forKey: storedSpreadsheetIdKey)
    }
    
    func clearHomeLocalState() {
        clearStoredSpreadsheetId()
        clearManagerName()
    }

    func spreadsheetURL(for id: String) -> URL? {
        URL(string: "https://docs.google.com/spreadsheets/d/\(id)")
    }

    /// Accepts either a full URL or a raw spreadsheetId.
    func extractSpreadsheetId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        if let url = URL(string: trimmed), let host = url.host, host.contains("google") {
            let path = url.path
            if let range = path.range(of: "/d/") {
                let after = path[range.upperBound...]
                return after.split(separator: "/").first.map(String.init)
            }
        }

        return trimmed
    }
    
    func fetchManagerNameFromHome(completion: @escaping (Result<String, Error>) -> Void) {
        guard let spreadsheetId = getStoredSpreadsheetId() else {
            completion(.failure(SheetsError.noStoredSpreadsheetId))
            return
        }

        withAccessToken { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let token):
                self.batchGetRawValues(
                    spreadsheetId: spreadsheetId,
                    ranges: ["Home!B1"],
                    accessToken: token
                ) { rawResult in
                    switch rawResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let allRanges):
                        let values = allRanges.first ?? []
                        let manager = values.first?.first.map { String(describing: $0) } ?? ""
                        let clean = manager.trimmingCharacters(in: .whitespacesAndNewlines)
                        if clean.isEmpty {
                            completion(.failure(NSError(domain: "BillMate", code: 0, userInfo: [
                                NSLocalizedDescriptionKey: "Home sheet has no manager name (Home!B1)."
                            ])))
                            return
                        }
                        self.storeManagerName(clean)
                        completion(.success(clean))
                    }
                }
            }
        }
    }
    
    
    func fetchRoommates(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let spreadsheetId = getStoredSpreadsheetId() else {
            completion(.failure(SheetsError.noStoredSpreadsheetId))
            return
        }

        withAccessToken { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let token):
                self.batchGetRawValues(
                    spreadsheetId: spreadsheetId,
                    ranges: ["Roommates!A:A"],
                    accessToken: token
                ) { rawResult in
                    switch rawResult {
                    case .failure(let error):
                        completion(.failure(error))

                    case .success(let allRanges):
                        let rows = allRanges.first ?? []

                        // rows like: [["Name"], ["Kyle"], ["Alex"], ...]
                        var names: [String] = []
                        for (index, row) in rows.enumerated() {
                            if index == 0 { continue } // header
                            guard let first = row.first else { continue }
                            let name = String(describing: first)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty { names.append(name) }
                        }

                        // de-dupe while preserving order
                        var seen = Set<String>()
                        let unique = names.filter { seen.insert($0.lowercased()).inserted }

                        completion(.success(unique))
                    }
                }
            }
        }
    }



    // MARK: - Home creation (Manager)

    /// Creates/loads the spreadsheet, ensures all required tabs + headers exist,
    /// writes manager name to Home, and adds manager to Roommates.
    func createHome(
        managerName: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let cleanName = managerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            completion(.failure(NSError(domain: "BillMate", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Manager name cannot be empty."
            ])))
            return
        }

        storeManagerName(cleanName)

        createSpreadsheetIfNeeded { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let spreadsheetId):
                self.storeSpreadsheetId(spreadsheetId)

                // 1) Write headers (idempotent overwrite to row 1)
                self.putValues(range: "Bills!A1:E1", values: [["Date", "PaidBy", "Description", "Amount", "SplitWith"]]) { res1 in
                    if case .failure(let e) = res1 { completion(.failure(e)); return }

                    self.putValues(range: "Payments!A1:D1", values: [["Date", "PaidBy", "Amount", "Note"]]) { res2 in
                        if case .failure(let e) = res2 { completion(.failure(e)); return }

                        self.putValues(range: "Summary!A1:B1", values: [["Name", "Amount Owed ($)"]]) { res3 in
                            if case .failure(let e) = res3 { completion(.failure(e)); return }

                            // 2) Home sheet manager name (overwrite A1:B1)
                            self.putValues(range: "Home!A1:B1", values: [["ManagerName", cleanName]]) { res4 in
                                if case .failure(let e) = res4 { completion(.failure(e)); return }

                                // 3) Roommates header (overwrite row 1)
                                self.putValues(range: "Roommates!A1:A1", values: [["Name"]]) { res5 in
                                    if case .failure(let e) = res5 { completion(.failure(e)); return }

                                    // 4) Add manager to roommates list (append row)
                                    self.appendValues(sheetName: "Roommates", values: [[cleanName]]) { res6 in
                                        switch res6 {
                                        case .success:
                                            completion(.success(()))
                                        case .failure(let e):
                                            completion(.failure(e))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Spreadsheet Creation

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

        currentUser.refreshTokensIfNeeded { [weak self] user, error in
            guard let self else { return }

            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let user else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "BillMate",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "No user returned from refresh"]
                    )))
                }
                return
            }

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

        // ✅ include Home + Roommates tabs now
        let body: [String: Any] = [
            "properties": ["title": "Bill Mate"],
            "sheets": [
                ["properties": ["title": "Bills"]],
                ["properties": ["title": "Payments"]],
                ["properties": ["title": "Summary"]],
                ["properties": ["title": "Home"]],
                ["properties": ["title": "Roommates"]]
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

            guard let data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "BillMate",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "No data returned"]
                    )))
                }
                return
            }

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

    // MARK: - Auth Helper

    private func withAccessToken(_ completion: @escaping (Result<String, Error>) -> Void) {
        guard GIDSignIn.sharedInstance.currentUser != nil else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "BillMate", code: 401, userInfo: [
                    NSLocalizedDescriptionKey: "No signed-in user"
                ])))
            }
            return
        }

        GIDSignIn.sharedInstance.currentUser?.refreshTokensIfNeeded { user, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let user else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "BillMate", code: 401, userInfo: [
                        NSLocalizedDescriptionKey: "Missing Google user after refresh"
                    ])))
                }
                return
            }

            DispatchQueue.main.async { completion(.success(user.accessToken.tokenString)) }
        }
    }

    // MARK: - PUT values (overwrite a specific range)

    private func putValues(
        range: String,
        values: [[Any]],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let spreadsheetId = getStoredSpreadsheetId() else {
            DispatchQueue.main.async {
                completion(.failure(SheetsError.noStoredSpreadsheetId))
            }
            return
        }

        withAccessToken { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let token):
                let encodedRange = range.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? range
                let url = URL(string:
                    "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(encodedRange)?valueInputOption=USER_ENTERED"
                )!

                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "majorDimension": "ROWS",
                    "values": values
                ]

                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                } catch {
                    completion(.failure(error))
                    return
                }

                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        DispatchQueue.main.async { completion(.failure(error)) }
                        return
                    }

                    guard let http = response as? HTTPURLResponse else {
                        DispatchQueue.main.async { completion(.failure(SheetsError.badResponse)) }
                        return
                    }

                    guard (200...299).contains(http.statusCode) else {
                        let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(unreadable)"
                        DispatchQueue.main.async {
                            completion(.failure(SheetsError.http(status: http.statusCode, body: raw)))
                        }
                        return
                    }

                    DispatchQueue.main.async { completion(.success(())) }
                }.resume()
            }
        }
    }

    // MARK: - Generic BatchGet (Raw)

    private func batchGetRawValues(
        spreadsheetId: String,
        ranges: [String],
        accessToken: String,
        completion: @escaping (Result<[[[Any]]], Error>) -> Void
    ) {
        var components = URLComponents(string: "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values:batchGet")!

        var items: [URLQueryItem] = [
            URLQueryItem(name: "majorDimension", value: "ROWS")
        ]
        for r in ranges {
            items.append(URLQueryItem(name: "ranges", value: r))
        }
        components.queryItems = items

        guard let url = components.url else {
            DispatchQueue.main.async {
                completion(.failure(SheetsError.badURL))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let http = response as? HTTPURLResponse, let data else {
                DispatchQueue.main.async { completion(.failure(SheetsError.badResponse)) }
                return
            }

            guard (200...299).contains(http.statusCode) else {
                let raw = String(data: data, encoding: .utf8) ?? "(unreadable)"
                DispatchQueue.main.async { completion(.failure(SheetsError.http(status: http.statusCode, body: raw))) }
                return
            }

            do {
                let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let valueRanges = obj?["valueRanges"] as? [[String: Any]] ?? []
                let all: [[[Any]]] = valueRanges.map { vr in
                    (vr["values"] as? [[Any]]) ?? []
                }
                DispatchQueue.main.async { completion(.success(all)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    // MARK: - Summary (Computed from Bills + Payments)

    func fetchComputedSummary(
        managerName: String,
        completion: @escaping (Result<[RoommateBalance], Error>) -> Void
    ) {
        let group = DispatchGroup()

        var billsResult: Result<[Bill], Error>?
        var paymentsResult: Result<[Payment], Error>?

        group.enter()
        fetchBills { result in
            billsResult = result
            group.leave()
        }

        group.enter()
        fetchPayments { result in
            paymentsResult = result
            group.leave()
        }

        group.notify(queue: .main) {
            if let b = billsResult, case .failure(let e) = b { completion(.failure(e)); return }
            if let p = paymentsResult, case .failure(let e) = p { completion(.failure(e)); return }

            let bills = (try? billsResult?.get()) ?? []
            let payments = (try? paymentsResult?.get()) ?? []

            let balances = self.computeBalances(bills: bills, payments: payments, managerName: managerName)
            completion(.success(balances))
        }
    }

    private func computeBalances(
        bills: [Bill],
        payments: [Payment],
        managerName: String
    ) -> [RoommateBalance] {

        var totals: [String: Double] = [:]

        func norm(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func add(_ name: String, _ delta: Double) {
            let key = norm(name)
            guard !key.isEmpty else { return }
            totals[key, default: 0] += delta
        }

        let manager = norm(managerName)

        // Bills:
        // - SplitWith = participants who share the cost
        // - Everyone (except manager) owes manager their share
        // - If someone else paid, they get credited for the full amount they paid (can go negative)
        for bill in bills {
            let amount = bill.amount
            if amount == 0 { continue }

            let payer = norm(bill.paidBy)

            let participants = bill.splitWith
                .split(separator: ",")
                .map { norm(String($0)) }
                .filter { !$0.isEmpty }

            guard !participants.isEmpty else { continue }

            let share = amount / Double(participants.count)

            // Each participant owes their share to the manager (manager never owes themselves)
            for person in participants {
                if person.caseInsensitiveCompare(manager) != .orderedSame {
                    add(person, share)
                }
            }

            // If someone other than manager paid upfront, credit them (manager owes them / reduces what they owe)
            if !payer.isEmpty, payer.caseInsensitiveCompare(manager) != .orderedSame {
                add(payer, -amount)
            }
        }

        // Payments:
        // - PaidBy = roommate paying the manager back
        // - Reduces what they owe (or increases their credit if they overpay)
        for pay in payments {
            let payer = norm(pay.paidBy)
            if payer.isEmpty { continue }

            // Ignore manager payments (they don't pay themselves back)
            if payer.caseInsensitiveCompare(manager) == .orderedSame { continue }

            add(payer, -pay.amount)
        }

        // This ledger is "owed to manager", so don't show a manager row
        totals.removeValue(forKey: manager)

        return totals
            .map { RoommateBalance(name: $0.key, amountOwed: $0.value) }
            .sorted { $0.amountOwed > $1.amountOwed }
    }


    // MARK: - Fetch: Bills

    func fetchBills(completion: @escaping (Result<[Bill], Error>) -> Void) {
        guard let spreadsheetId = getStoredSpreadsheetId() else {
            DispatchQueue.main.async {
                completion(.failure(SheetsError.noStoredSpreadsheetId))
            }
            return
        }

        withAccessToken { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let token):
                self.batchGetRawValues(
                    spreadsheetId: spreadsheetId,
                    ranges: ["Bills!A:E"],
                    accessToken: token
                ) { rawResult in
                    switch rawResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let allRanges):
                        let values = allRanges.first ?? []

                        var items: [Bill] = []
                        for (index, row) in values.enumerated() {
                            if index == 0 { continue } // header
                            guard row.count >= 4 else { continue }

                            let date = String(describing: row[0])
                            let paidBy = String(describing: row[1])
                            let desc = String(describing: row[2])
                            let amount = Double(String(describing: row[3])) ?? 0.0
                            let split = row.count >= 5 ? String(describing: row[4]) : ""

                            items.append(Bill(date: date, paidBy: paidBy, description: desc, amount: amount, splitWith: split))
                        }

                        items.sort { $0.date > $1.date }
                        completion(.success(items))
                    }
                }
            }
        }
    }

    // MARK: - Fetch: Payments

    struct Payment: Identifiable {
        let id = UUID()
        let date: String
        let paidBy: String
        let amount: Double
        let note: String
    }

    func fetchPayments(completion: @escaping (Result<[Payment], Error>) -> Void) {
        guard let spreadsheetId = getStoredSpreadsheetId() else {
            DispatchQueue.main.async {
                completion(.failure(SheetsError.noStoredSpreadsheetId))
            }
            return
        }

        withAccessToken { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let token):
                self.batchGetRawValues(
                    spreadsheetId: spreadsheetId,
                    ranges: ["Payments!A:D"],
                    accessToken: token
                ) { rawResult in
                    switch rawResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let allRanges):
                        let values = allRanges.first ?? []

                        var out: [Payment] = []
                        for (index, row) in values.enumerated() {
                            if index == 0 { continue } // header
                            guard row.count >= 3 else { continue }

                            let date = String(describing: row[0])
                            let paidBy = String(describing: row[1])
                            let amountStr = String(describing: row[2])
                            let note = row.count >= 4 ? String(describing: row[3]) : ""

                            let amount = Double(amountStr) ?? 0.0
                            out.append(Payment(date: date, paidBy: paidBy, amount: amount, note: note))
                        }

                        out.sort { $0.date > $1.date }
                        completion(.success(out))
                    }
                }
            }
        }
    }

    // MARK: - Append: Bills / Payments

    func appendBillRow(
        date: String,
        paidBy: String,
        description: String,
        amount: String,
        splitWith: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let values: [[Any]] = [[date, paidBy, description, amount, splitWith]]
        appendValues(sheetName: "Bills", values: values, completion: completion)
    }

    func appendPaymentRow(
        date: String,
        paidBy: String,
        amount: String,
        note: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let values: [[Any]] = [[date, paidBy, amount, note]]
        appendValues(sheetName: "Payments", values: values, completion: completion)
    }

    private func appendValues(
        sheetName: String,
        values: [[Any]],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let spreadsheetId = getStoredSpreadsheetId() else {
            DispatchQueue.main.async { completion(.failure(SheetsError.noStoredSpreadsheetId)) }
            return
        }

        withAccessToken { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let token):
                let rawRange = "\(sheetName)!A:Z"
                let encodedRange = rawRange.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawRange

                let url = URL(string:
                    "https://sheets.googleapis.com/v4/spreadsheets/\(spreadsheetId)/values/\(encodedRange):append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS"
                )!

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

                let body: [String: Any] = [
                    "majorDimension": "ROWS",
                    "values": values
                ]

                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                } catch {
                    completion(.failure(error))
                    return
                }

                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        DispatchQueue.main.async { completion(.failure(error)) }
                        return
                    }

                    guard let http = response as? HTTPURLResponse else {
                        DispatchQueue.main.async { completion(.failure(SheetsError.badResponse)) }
                        return
                    }

                    guard (200...299).contains(http.statusCode) else {
                        let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(unreadable)"
                        DispatchQueue.main.async {
                            completion(.failure(SheetsError.http(status: http.statusCode, body: raw)))
                        }
                        return
                    }

                    DispatchQueue.main.async { completion(.success(())) }
                }.resume()
            }
        }
    }
}
