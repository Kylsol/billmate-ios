//
//  Roommate.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/9/26.
//

import Foundation

struct Roommate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let isManager: Bool
}
