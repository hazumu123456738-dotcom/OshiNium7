//
//  ContentView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/05/11.
//

import SwiftUI

struct ContentView: View {

    @State private var showAddEvent = false
    @State private var selectedGroup: IdolGroup? = nil
    @State private var selectedDate = Date()

    var body: some View {
        AppRootView(
            showAddEvent: $showAddEvent,
            selectedGroup: $selectedGroup,
            selectedDate: $selectedDate
        )
    }
}
