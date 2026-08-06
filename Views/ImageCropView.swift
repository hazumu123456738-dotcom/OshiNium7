//
//  ImageCropView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/06.
//

import SwiftUI

// ★ Instagramのように、写真を選んだ直後にピンチ・ドラッグで位置とズームを
//   調整してから使えるようにするための正方形トリミング画面
struct ImageCropView: View {

    let image: UIImage
    var onCancel: () -> Void
    var onDone: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSide: CGFloat = UIScreen.main.bounds.width - 32

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cropSide, height: cropSide)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipped()

                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .allowsHitTesting(false)
                }
                .frame(width: cropSide, height: cropSide)
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, lastScale * value)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            },
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )

                Text("ピンチで拡大縮小、ドラッグで位置を調整できます")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer(minLength: 0)
            }
            .background(Color.black.opacity(0.02).ignoresSafeArea())
            .navigationTitle("写真を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        onDone(croppedImage())
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - 実際の切り出し

    private func croppedImage() -> UIImage {
        let imageSize = image.size
        // ★ .aspectRatio(contentMode: .fill) と同じ計算で、正方形フレームを
        //   埋めるための基準スケールを求める（scale=1・offset=0のときの見た目に一致させる）
        let baseFillScale = max(cropSide / imageSize.width, cropSide / imageSize.height)
        let effectiveScale = baseFillScale * scale

        let renderedSize = CGSize(width: imageSize.width * effectiveScale, height: imageSize.height * effectiveScale)
        let frameCenter = CGPoint(x: cropSide / 2, y: cropSide / 2)
        let imageCenterInFrame = CGPoint(x: frameCenter.x + offset.width, y: frameCenter.y + offset.height)
        let imageTopLeftInFrame = CGPoint(
            x: imageCenterInFrame.x - renderedSize.width / 2,
            y: imageCenterInFrame.y - renderedSize.height / 2
        )

        // クロップ枠(フレーム全体)を、描画された画像のローカル座標に変換
        let cropOriginInRendered = CGPoint(x: -imageTopLeftInFrame.x, y: -imageTopLeftInFrame.y)

        // 元画像（ポイント単位）の座標に戻す
        var cropOrigin = CGPoint(x: cropOriginInRendered.x / effectiveScale, y: cropOriginInRendered.y / effectiveScale)
        var cropSize = CGSize(width: cropSide / effectiveScale, height: cropSide / effectiveScale)

        // 画像範囲内に収める
        cropOrigin.x = max(0, min(cropOrigin.x, imageSize.width - cropSize.width))
        cropOrigin.y = max(0, min(cropOrigin.y, imageSize.height - cropSize.height))
        cropSize.width = min(cropSize.width, imageSize.width - cropOrigin.x)
        cropSize.height = min(cropSize.height, imageSize.height - cropOrigin.y)

        // ポイント→ピクセルに変換してCGImageから切り出す
        let pixelScale = image.scale
        let pixelRect = CGRect(
            x: cropOrigin.x * pixelScale,
            y: cropOrigin.y * pixelScale,
            width: cropSize.width * pixelScale,
            height: cropSize.height * pixelScale
        )

        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: pixelRect) else {
            return image
        }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
