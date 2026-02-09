//
//  AddPaymentView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import SwiftUI

struct AddPaymentView: View {
    @Binding var status: String
    var onSaved: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var paidBy: String = ""
    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var date = Date()

    @State private var isSaving = false

    var body: some View {
        Form {
            DatePicker("Date", selection: $date, displayedComponents: .date)

            TextField("Paid by", text: $paidBy)
                .textInputAutocapitalization(.words)

            TextField("Amount", text: $amount)
                .keyboardType(.decimalPad)

            TextField("Note (optional)", text: $note)

            Button(isSaving ? "Saving..." : "Save Payment") {
                save()
            }
            .disabled(isSaving || paidBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || amount.isEmpty)
        }
        .navigationTitle("Add Payment")
    }

    private func save() {
        isSaving = true
        status = "⏳ Saving payment..."

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: date)

        GoogleSheetsService.shared.appendPaymentRow(
            date: dateStr,
            paidBy: paidBy,
            amount: amount,
            note: note
        ) { result in
            DispatchQueue.main.async {
                isSaving = false

                switch result {
                case .success:
                    status = "✅ Payment saved"
                    onSaved?()
                    dismiss()

                case .failure(let error):
                    status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}
