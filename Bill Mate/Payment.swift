//
//  Payment.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import Foundation

struct Payment: Identifiable {
    let id = UUID()
    let date: String
    let paidBy: String
    let amount: Double
    let note: String
}
