//
//  BillsView.swift
//  Bill Mate
//
//  Created by Kyle Solomons on 2/8/26.
//

import SwiftUI

struct BillsView: View {
    @State private var status: String = ""
    @State private var bills: [Bill] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Bills")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    loadBills()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)

            NavigationLink {
                AddBillView(status: $status) {
                    loadBills()          // refresh after save
                }
            } label: {
                Text("Add Bill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .padding(.top, 8)
            }

            if !status.isEmpty {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            List {
                ForEach(bills) { bill in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bill.description)
                            .fontWeight(.semibold)

                        Text("\(bill.date) • Paid by \(bill.paidBy) • Split: \(bill.splitWith)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(bill.amount.formatted(.currency(code: "USD")))
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        }
        .padding(.top)
        .navigationTitle("Bills")
        .onAppear { loadBills() }
    }

    private func loadBills() {
        isLoading = true
        status = "Loading bills…"

        GoogleSheetsService.shared.fetchBills { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let items):
                    self.bills = items
                    self.status = items.isEmpty ? "No bills found yet." : "✅ Loaded \(items.count) bills"
                case .failure(let error):
                    self.status = "❌ \(error.localizedDescription)"
                }
            }
        }
    }
}
