//
//  Bill.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import Foundation

struct Bill: Identifiable {
    let id = UUID()
    let date: String
    let paidBy: String
    let description: String
    let amount: Double
    let splitWith: String
}

