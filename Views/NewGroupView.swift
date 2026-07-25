//
//  NewGroupView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/06/11.
//

import SwiftUI

struct NewGroupView: View {

    @EnvironmentObject var groupViewModel: GroupViewModel
    @Environment(\.dismiss) var dismiss

    var onComplete: ((IdolGroup) -> Void)? = nil   // ★追加

    @State private var groupName = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("新しいグループを作成")
                .font(.title2)
                .bold()

            // MARK: - グループ画像
            Button {
                showImagePicker = true
            } label: {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 120)

                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)

            // MARK: - グループ名
            TextField("グループ名", text: $groupName)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            // MARK: - 作成ボタン
            Button(action: createGroup) {
                Text("作成する")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(groupName.isEmpty || selectedImage == nil ? Color.gray : Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(groupName.isEmpty || selectedImage == nil)

            Spacer()
        }
        .padding()
        .navigationTitle("新規グループ")
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }

    // MARK: - グループ作成処理
    private func createGroup() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let newGroup = IdolGroup(
            id: UUID().uuidString,
            name: groupName,
            imageData: imageData,
            reading: nil,
            fandom: nil,
            concept: nil,
            history: nil,
            groupDescription: nil,
            createdAt: Date()
        )

        groupViewModel.addGroup(newGroup)

        onComplete?(newGroup)   // ★追加：呼び出し元に返す
        dismiss()
    }
}
