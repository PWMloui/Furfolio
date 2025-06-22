//
//  OwnerNotesView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


import SwiftUI

struct OwnerNotesView: View {
    @Binding var notes: String
    var placeholder: String = "Enter notes about this owner..."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Owner Notes")
                .font(.headline)
                .padding(.bottom, 4)

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.horizontal, 6)
                }
                TextEditor(text: $notes)
                    .padding(4)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 120)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    @State var demoNotes = ""
    return OwnerNotesView(notes: $demoNotes)
}
