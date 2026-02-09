//
//  InviteService.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import Foundation
import FirebaseFirestore

final class InviteService {
    static let shared = InviteService()
    private init() {}

    private let db = Firestore.firestore()
    private let collectionName = "invites"

    // MARK: - Token generation

    func generateToken() -> String {
        // XXXX-XXXX using A-Z + 2-9 (avoids confusing 0/O, 1/I)
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

        func chunk(_ n: Int) -> String {
            String((0..<n).compactMap { _ in alphabet.randomElement() })
        }

        return "\(chunk(4))-\(chunk(4))"
    }

    // MARK: - Create Invite

    func createInvite(
        spreadsheetId: String,
        createdBy: String,
        ttlHours: Int = 72,
        maxUses: Int = 5,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let token = generateToken()
        let now = Date()
        let expires = Calendar.current.date(byAdding: .hour, value: ttlHours, to: now)
            ?? now.addingTimeInterval(TimeInterval(ttlHours * 3600))

        let docRef = db.collection(collectionName).document(token)

        let data: [String: Any] = [
            "spreadsheetId": spreadsheetId,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: now),
            "expiresAt": Timestamp(date: expires),
            "maxUses": maxUses,
            "uses": 0,
            "active": true
        ]

        docRef.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(token))
            }
        }
    }

    // MARK: - Consume Invite (transaction)

    func consumeInvite(
        token rawToken: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if token.isEmpty {
            completion(.failure(NSError(domain: "BillMate", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Token is empty."
            ])))
            return
        }

        let docRef = db.collection(collectionName).document(token)

        db.runTransaction({ transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(docRef)

                guard snapshot.exists else {
                    errorPointer?.pointee = NSError(domain: "BillMate", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "Invite not found."
                    ])
                    return nil
                }

                let data = snapshot.data() ?? [:]

                let active = data["active"] as? Bool ?? false
                let spreadsheetId = data["spreadsheetId"] as? String ?? ""
                let maxUses = data["maxUses"] as? Int ?? 0
                let uses = data["uses"] as? Int ?? 0
                let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date.distantPast

                if !active {
                    errorPointer?.pointee = NSError(domain: "BillMate", code: 403, userInfo: [
                        NSLocalizedDescriptionKey: "Invite is inactive."
                    ])
                    return nil
                }

                if Date() > expiresAt {
                    errorPointer?.pointee = NSError(domain: "BillMate", code: 410, userInfo: [
                        NSLocalizedDescriptionKey: "Invite has expired."
                    ])
                    return nil
                }

                if spreadsheetId.isEmpty {
                    errorPointer?.pointee = NSError(domain: "BillMate", code: 0, userInfo: [
                        NSLocalizedDescriptionKey: "Invite is invalid (missing spreadsheetId)."
                    ])
                    return nil
                }

                if maxUses > 0 && uses >= maxUses {
                    errorPointer?.pointee = NSError(domain: "BillMate", code: 429, userInfo: [
                        NSLocalizedDescriptionKey: "Invite has reached its usage limit."
                    ])
                    return nil
                }

                transaction.updateData(["uses": uses + 1], forDocument: docRef)

                // Return spreadsheetId as Any? (Firestore wants Any?)
                return spreadsheetId

            } catch let err as NSError {
                errorPointer?.pointee = err
                return nil
            }
        }, completion: { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let spreadsheetId = result as? String, !spreadsheetId.isEmpty else {
                completion(.failure(NSError(domain: "BillMate", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "Could not consume invite."
                ])))
                return
            }

            completion(.success(spreadsheetId))
        })
    }
}
