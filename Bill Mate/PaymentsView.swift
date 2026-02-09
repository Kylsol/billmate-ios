//
//  PaymentsView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import SwiftUI

struct PaymentsView: View {
    @State private var status: String = ""
    @State private var isLoading = false

    // ✅ If your Payment model is nested inside GoogleSheetsService, use this:
    @State private var payments: [GoogleSheetsService.Payment] = []

    // ❗ If you have a global Payment model elsewhere, use this instead:
    // @State private var payments: [Payment] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                header

                NavigationLink {
                    AddPaymentView(status: $status, onSaved: {
                        loadPayments()
                    })
                } label: {
                    Text("Add Payment")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                if isLoading {
                    ProgressView()
                }

                if !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                List(payments) { p in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(p.paidBy)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(p.amount.formatted(.currency(code: "USD")))
                                .fontWeight(.semibold)
                        }

                        Text(p.date)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !p.note.isEmpty {
                            Text(p.note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Payments")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        loadPayments()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AddPaymentView(status: $status, onSaved: {
                            loadPayments()
                        })
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadPayments()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Payments")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func loadPayments() {
        isLoading = true
        status = "Loading…"

        GoogleSheetsService.shared.fetchPayments { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let list):
                    payments = list
                    status = list.isEmpty ? "No payments yet." : "✅ Loaded \(list.count) payments"
                case .failure(let error):
                    status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}
