//
//  AddEventMenuView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/25.
//

import SwiftUI

struct AddEventMenuView: View {
    let date: Date

    var body: some View {
        Text("予定追加メニュー（仮）\n\(date.formatted())")
            .padding()
    }
}
