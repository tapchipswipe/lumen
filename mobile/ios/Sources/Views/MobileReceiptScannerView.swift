import SwiftUI
import UIKit

public struct MobileReceiptScannerView: View {
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isScanning = false
    @State private var scannedReceipt: MobileReceiptPayload?
    @State private var statusMessage: String = "Snap or select a paper/digital receipt"

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Viewfinder / Preview Box
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.10))
                        .frame(height: 280)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.36, green: 0.55, blue: 1.0).opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        )

                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 260)
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 48))
                                .foregroundColor(Color(red: 0.36, green: 0.55, blue: 1.0))
                            Text("Apple Vision OCR Scanner")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Extracts Merchant, Total, Card Last-4 & Tax Deductibility")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }

                    if isScanning {
                        Color.black.opacity(0.6)
                            .cornerRadius(16)
                        ProgressView("Analyzing receipt text...")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)

                // Parsed Receipt Card
                if let receipt = scannedReceipt {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(receipt.merchant)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "$%.2f", receipt.amount))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Color.green)
                        }

                        HStack {
                            Text("Category: \(receipt.category)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            if let card = receipt.cardLast4 {
                                Text("Card ending in \(card)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: {
                            saveReceipt(receipt)
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save to Tax Runway Buffer")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(14)
                    .padding(.horizontal)
                }

                Spacer()

                // Capture Actions
                HStack(spacing: 16) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Photo Library")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(white: 0.16))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        simulateDemoReceiptScan()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Demo Scan")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.2, green: 0.4, blue: 0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Receipt Scanner")
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerView(image: $selectedImage) { img in
                    runVisionScan(on: img)
                }
            }
        }
    }

    private func runVisionScan(on image: UIImage) {
        isScanning = true
        ReceiptVisionScanner.shared.scanReceiptImage(image) { parsed in
            DispatchQueue.main.async {
                self.isScanning = false
                self.scannedReceipt = parsed
            }
        }
    }

    private func simulateDemoReceiptScan() {
        isScanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isScanning = false
            self.scannedReceipt = MobileReceiptPayload(
                id: UUID(),
                capturedAt: Date(),
                merchant: "Blue Bottle Coffee",
                amount: 14.75,
                currency: "USD",
                cardLast4: "8031",
                category: "Dining",
                rawOcrSnippet: "BLUE BOTTLE COFFEE\nTotal: $14.75\nVisa ending 8031",
                confidenceScore: 0.96
            )
        }
    }

    private func saveReceipt(_ receipt: MobileReceiptPayload) {
        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .receiptScan,
            payload: .receiptScan(receipt)
        ))
        scannedReceipt = nil
        selectedImage = nil
    }
}

public struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        public func picker(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.onImagePicked(uiImage)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
