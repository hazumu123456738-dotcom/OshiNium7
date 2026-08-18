//
//  QRScannerView.swift
//  OshiNium7
//
//  Created by hirai hazumu on 2026/08/01.
//

import SwiftUI
import AVFoundation

// ★ 他ユーザーのプロフィールQRコードを読み取るためのカメラスキャナー。
//   AVCaptureSession + AVCaptureMetadataOutputでQRコードだけを検出する。
//   読み取れた文字列はonScannedで呼び出し元に渡し、呼び出し元がoshinium://profile?uid=...を
//   解釈してUserProfileViewへ遷移させる（このビュー自体はURLの意味を知らない）
struct QRScannerView: UIViewControllerRepresentable {
    var onScanned: (String) -> Void
    var onPermissionDenied: (() -> Void)?

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScanned = onScanned
        controller.onPermissionDenied = onPermissionDenied
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController {
    var onScanned: ((String) -> Void)?
    var onPermissionDenied: (() -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestAccessAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.onPermissionDenied?()
                    }
                }
            }
        default:
            // ★ 発見(全画面UIレビュー)：.denied/.restrictedの場合、以前はここで
            //   何もせず終わっており、黒画面にスキャン枠だけが表示され続ける
            //   「何も起きない」行き止まりになっていた。呼び出し元に伝えて案内を出す
            onPermissionDenied?()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
}

// ★ カメラプレビュー全画面＋枠線・案内文つきのスキャン画面（fullScreenCoverで使う想定）
struct QRScannerScreen: View {
    var onScanned: (String) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            QRScannerView(
                onScanned: { value in
                    onScanned(value)
                    dismiss()
                },
                onPermissionDenied: {
                    permissionDenied = true
                }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.9))
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .accessibilityLabel("閉じる")
                    .padding(20)
                }

                Spacer()

                if !permissionDenied {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 240, height: 240)
                        .shadow(color: .black.opacity(0.4), radius: 12)
                }

                Spacer()

                if permissionDenied {
                    // ★ 発見(全画面UIレビュー)：カメラ権限が拒否/制限されている場合、以前は
                    //   黒画面にスキャン枠だけが残り、何も起きない行き止まりになっていた
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.7))
                        Text("カメラへのアクセスが許可されていません")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("設定アプリからOshiNiumのカメラアクセスを許可してください")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("設定を開く")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 50)
                } else {
                    Text("相手のプロフィールQRコードを枠内に合わせてください")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 50)
                }
            }
        }
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else { return }

        didScan = true
        onScanned?(value)
    }
}
