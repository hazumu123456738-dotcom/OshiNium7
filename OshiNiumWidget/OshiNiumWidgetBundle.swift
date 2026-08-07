//
//  OshiNiumWidgetBundle.swift
//  OshiNiumWidget
//
//  Created by hirai hazumu on 2026/07/30.
//

import WidgetKit
import SwiftUI

@main
struct OshiNiumWidgetBundle: WidgetBundle {
    var body: some Widget {
        MiniCalendarWidget()
        PackingCalendarWidget()
        ExpenseCalendarWidget()
    }
}
