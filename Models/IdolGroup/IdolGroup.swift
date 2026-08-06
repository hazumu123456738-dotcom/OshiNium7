//
//  IdolGroup.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import Foundation
import SwiftData

@Model
class IdolGroup {
    var name: String
    var imageData: Data?

    init(name: String, imageData: Data? = nil) {
        self.name = name
        self.imageData = imageData
    }
}

