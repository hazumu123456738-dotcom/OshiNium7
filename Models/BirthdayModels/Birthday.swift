//
//  Birthday.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import Foundation
import FirebaseFirestore

struct Birthday: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var date: Date
    var memo: String?
}

