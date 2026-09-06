import Foundation
import UIKit
import Vision

public final class ReceiptVisionScanner {
    public static let shared = ReceiptVisionScanner()
    private init() {}

    public func scanReceiptImage(_ image: UIImage, completion: @escaping (MobileReceiptPayload?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion(nil)
                return
            }

            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let fullText = lines.joined(separator: "\n")
            let parsed = self.parseReceiptText(fullText)
            completion(parsed)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func parseReceiptText(_ text: String) -> MobileReceiptPayload {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let merchant = lines.first ?? "Unknown Merchant"

        var amount: Double = 0.0
        let amountPattern = #"\$?\s*([0-9]+\.[0-9]{2})"#
        if let regex = try? NSRegularExpression(pattern: amountPattern, options: []) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            var largestVal: Double = 0.0
            for match in matches {
                if let r = Range(match.range(at: 1), in: text) {
                    let numStr = String(text[r])
                    if let val = Double(numStr), val > largestVal && val < 5000.0 {
                        largestVal = val
                    }
                }
            }
            amount = largestVal
        }

        var cardLast4: String? = nil
        let cardPattern = #"(?:ending in|visa|mastercard|amex|card|••••|\*{4})\s*([0-9]{4})"#
        if let regex = try? NSRegularExpression(pattern: cardPattern, options: .caseInsensitive) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(match.range(at: 1), in: text) {
                    cardLast4 = String(text[r])
                }
            }
        }

        let category: String
        let lower = text.lowercased()
        if lower.contains("uber") || lower.contains("lyft") || lower.contains("airline") || lower.contains("hotel") {
            category = "Travel"
        } else if lower.contains("coffee") || lower.contains("restaurant") || lower.contains("cafe") || lower.contains("food") || lower.contains("dining") {
            category = "Dining"
        } else if lower.contains("software") || lower.contains("github") || lower.contains("aws") || lower.contains("apple.com/bill") || lower.contains("cloud") {
            category = "Software"
        } else if lower.contains("target") || lower.contains("walmart") || lower.contains("amazon") || lower.contains("groceries") {
            category = "Shopping"
        } else {
            category = "Business"
        }

        return MobileReceiptPayload(
            id: UUID(),
            capturedAt: Date(),
            merchant: merchant,
            amount: amount,
            currency: "USD",
            cardLast4: cardLast4,
            category: category,
            rawOcrSnippet: text.prefix(200).description,
            confidenceScore: amount > 0 ? 0.92 : 0.50
        )
    }
}
