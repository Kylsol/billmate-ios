//
//  AddBillView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import SwiftUI

struct AddBillView: View {
    @Binding var status: String
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var description: String = ""
    @State private var amount: String = ""
    @State private var splitWith: String = ""
    @State private var date = Date()
    @State private var isSaving = false

    // PaidBy logic
    @State private var paidByManager: Bool = true
    @State private var paidByInput: String = ""

    var body: some View {
        Form {
            DatePicker("Date", selection: $date, displayedComponents: .date)

            Toggle(isOn: $paidByManager) {
                Text("Paid by Manager")
            }
            .onAppear {
                // Prefill with manager name so if they untick, it's ready
                let manager = GoogleSheetsService.shared.getManagerName() ?? ""
                if paidByInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    paidByInput = manager
                }
            }

            if paidByManager {
                let manager = GoogleSheetsService.shared.getManagerName() ?? "Manager"
                HStack {
                    Text("Paid by")
                    Spacer()
                    Text(manager)
                        .foregroundStyle(.secondary)
                }
            } else {
                TextField("Paid by (name)", text: $paidByInput)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            TextField("Description", text: $description)

            TextField("Amount", text: $amount)
                .keyboardType(.decimalPad)

            TextField("Split with (comma separated)", text: $splitWith)

            Button(isSaving ? "Saving..." : "Save Bill") {
                save()
            }
            .disabled(isSaving)
        }
        .navigationTitle("Add Bill")
    }

    private func save() {
        isSaving = true
        status = "⏳ Saving bill..."

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: date)

        let manager = (GoogleSheetsService.shared.getManagerName() ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let paidByFinal: String = {
            if paidByManager {
                return manager
            } else {
                return paidByInput.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }()

        guard !paidByFinal.isEmpty else {
            isSaving = false
            status = "❌ Paid by cannot be empty."
            return
        }

        GoogleSheetsService.shared.appendBillRow(
            date: dateStr,
            paidBy: paidByFinal,
            description: description,
            amount: amount,
            splitWith: splitWith
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    status = "✅ Bill saved"
                    onSaved?()
                    dismiss()
                case .failure(let error):
                    status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}
