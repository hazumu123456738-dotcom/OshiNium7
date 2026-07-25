//
//  AddMethodSelectView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/17.
//

import SwiftUI

struct AddMethodSelectView: View {

    var onSelectAI: () -> Void
    var onSelectManual: () -> Void

    var body: some View {
        VStack(spacing: 28) {

            Text("予定の追加方法を選択")
                .font(.title3.bold())
                .padding(.top, 20)

            // AI追加
            Button {
                onSelectAI()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                    Text("AIで追加する")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.pink)
                .cornerRadius(16)
                .shadow(color: .pink.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.horizontal, 24)

            // 手動追加
            Button {
                onSelectManual()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.title2)
                    Text("手動で追加する")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .presentationDetents([.height(320)])
    }
}

