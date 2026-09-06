import SwiftUI

struct TransactionEditorModalView: View {
    @Environment(\.dismiss) private var dismiss
    let receipt: ReceiptPayload

    @State private var merchant: String
    @State private var amountString: String
    @State private var isIncome: Bool
    @State private var selectedCard: String
    @State private var selectedCategory: ReceiptCategory
    @State private var isDeductible: Bool
    @State private var notes: String
    @State private var customCardInput: String = ""

    private let standardCards = ["1533", "8031", "9530", "7805", "1244", "Direct", "Custom"]

    init(receipt: ReceiptPayload) {
        self.receipt = receipt
        _merchant = State(initialValue: receipt.merchant)
        _amountString = State(initialValue: "\(receipt.amount)")
        _isIncome = State(initialValue: TransactionCustomizer.isIncome(for: receipt))
        let initialCard = receipt.cardLast4 ?? "Direct"
        _selectedCard = State(initialValue: ["1533", "8031", "9530", "7805", "1244", "Direct"].contains(initialCard) ? initialCard : "Custom")
        _customCardInput = State(initialValue: ["1533", "8031", "9530", "7805", "1244", "Direct"].contains(initialCard) ? "" : initialCard)
        _selectedCategory = State(initialValue: receipt.category)
        _isDeductible = State(initialValue: receipt.category.businessDeductible)
        _notes = State(initialValue: receipt.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                    Text("CUSTOMIZE TRANSACTION")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            // Direction Selector: Paid Out vs Paid to Me
            HStack(spacing: 8) {
                Button {
                    withAnimation { isIncome = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.circle.fill")
                        Text("Paid Out (Expense)")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(!isIncome ? Color(hex: "#EF4444").opacity(0.2) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(!isIncome ? Color(hex: "#EF4444") : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(!isIncome ? Color(hex: "#EF4444") : .white.opacity(0.5))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation { isIncome = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.left.circle.fill")
                        Text("Paid to Me (Income / Transfer)")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isIncome ? Color(hex: "#10B981").opacity(0.2) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isIncome ? Color(hex: "#10B981") : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(isIncome ? Color(hex: "#10B981") : .white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                // Merchant & Amount Fields
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MERCHANT / SENDER").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        TextField("Merchant Name", text: $merchant)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                            .font(.system(size: 13))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AMOUNT ($)").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        TextField("0.00", text: $amountString)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .frame(width: 100)
                }

                // Payment Card Selection
                VStack(alignment: .leading, spacing: 3) {
                    Text("CARD / ACCOUNT BINDING").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                    HStack(spacing: 8) {
                        Picker("", selection: $selectedCard) {
                            Text("Joyce Credit (••1533)").tag("1533")
                            Text("Steve Credit (••8031)").tag("8031")
                            Text("Lucas Credit (••9530)").tag("9530")
                            Text("Chase Checking (••7805)").tag("7805")
                            Text("Chase ATM (••1244)").tag("1244")
                            Text("Direct Web / Online").tag("Direct")
                            Text("Custom Last 4…").tag("Custom")
                        }
                        .labelsHidden()

                        if selectedCard == "Custom" {
                            TextField("Last 4", text: $customCardInput)
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                                .frame(width: 70)
                        }
                    }
                }

                // Category & Tax Deductible
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CATEGORY").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        Picker("", selection: $selectedCategory) {
                            ForEach(ReceiptCategory.assignable) { cat in
                                Label(cat.label, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("TAX STATUS").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        Toggle("IRS Deductible", isOn: $isDeductible)
                            .toggleStyle(.switch)
                            .font(.system(size: 11))
                    }
                }

                // Custom Notes
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOTES / TAGS").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                    TextField("e.g. Joyce Card · Dev Tools · Venmo split", text: $notes)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
                        .font(.system(size: 12))
                }
            }

            Spacer()

            // Save Action Button
            Button {
                saveChanges()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save & Apply Customization").font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(merchant.trimmingCharacters(in: .whitespaces).isEmpty || Decimal(string: amountString) == nil)
        }
        .padding(18)
        .frame(width: 440, height: 410)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#12131A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func saveChanges() {
        guard let amt = Decimal(string: amountString) else { return }
        let cleanMerchant = merchant.trimmingCharacters(in: .whitespaces)
        guard !cleanMerchant.isEmpty else { return }

        let cardToken: String?
        if selectedCard == "Custom" {
            cardToken = customCardInput.trimmingCharacters(in: .whitespaces)
        } else if selectedCard == "Direct" {
            cardToken = nil
        } else {
            cardToken = selectedCard
        }

        let override = TransactionOverride(
            customMerchant: cleanMerchant,
            customAmount: amt,
            customCardLast4: cardToken,
            customCategory: selectedCategory,
            isIncome: isIncome,
            isDeductible: isDeductible,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        TransactionCustomizer.setOverride(override, for: receipt)

        AppState.shared.refreshAggregation()
        dismiss()
    }
}
