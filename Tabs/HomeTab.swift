//
//  HomeTab.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/10.
//

import SwiftUI

struct HomeTab: View {

    @Binding var selectedDate: Date
    @Binding var selectedGroup: IdolGroup?
    @Binding var showAddEvent: Bool

    var body: some View {
        NavigationStack {
            HomeView(
                selectedDate: $selectedDate,
                selectedGroup: $selectedGroup,
                showAddEvent: $showAddEvent
            )
        }
    }
}
