//
//  RecommendedGroupRowView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct RecommendedGroupRowView: View {

    let group: IdolGroup

    var body: some View {
        HStack(spacing: 16) {

            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 48, height: 48)

            Text(group.name)
                .foregroundColor(.black)
                .font(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}

