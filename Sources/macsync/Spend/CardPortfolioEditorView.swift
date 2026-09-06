import SwiftUI

struct CardPortfolioEditorView: View {
    @ObservedObject var appState = AppState.shared

    @State private var nick8031: String = CardPortfolio.shortName(for: "8031")
    @State private var nick1533: String = CardPortfolio.shortName(for: "1533")
    @State private var nick9530: String = CardPortfolio.shortName(for: "9530")
    @State private var nick7805: String = CardPortfolio.shortName(for: "7805")
    @State private var nick1244: String = CardPortfolio.shortName(for: "1244")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Nicknames
            VStack(alignment: .leading, spacing: 8) {
                cardRow(digits: "8031", binding: $nick8031)
                cardRow(digits: "1533", binding: $nick1533)
                cardRow(digits: "9530", binding: $nick9530)
                cardRow(digits: "7805", binding: $nick7805)
                cardRow(digits: "1244", binding: $nick1244)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))

            // Category Tax Rules
            Text("TAX DEDUCTIBILITY RULES").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.4)).tracking(1)
            VStack(alignment: .leading, spacing: 8) {
                categoryTaxRow(cat: .software, label: "Software & SaaS")
                categoryTaxRow(cat: .subscriptions, label: "Subscriptions (Apple, Cloud)")
                categoryTaxRow(cat: .travel, label: "Business Travel & Flights")
                categoryTaxRow(cat: .transport, label: "Transportation (Uber/Lyft)")
                categoryTaxRow(cat: .education, label: "Education & Courses")
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
        }
    }

    private func cardRow(digits: String, binding: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.accent)
            Text("••\(digits)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 50, alignment: .leading)
            TextField("Card Nickname", text: binding)
                .textFieldStyle(.plain)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                .font(.system(size: 11.5))
                .onChange(of: binding.wrappedValue) { _, newValue in
                    CardPortfolio.setNickname(newValue, for: digits)
                    appState.refreshSpend()
                }
        }
    }

    private func categoryTaxRow(cat: ReceiptCategory, label: String) -> some View {
        HStack {
            Image(systemName: cat.icon)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: cat.colorHex))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(cat.businessDeductible ? "Deductible" : "Personal")
                .font(.system(size: 9.5, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(cat.businessDeductible ? AppTheme.batteryGreen.opacity(0.18) : Color.white.opacity(0.08)))
                .foregroundStyle(cat.businessDeductible ? AppTheme.batteryGreen : .white.opacity(0.5))
        }
    }
}
