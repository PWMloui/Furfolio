//
//  DashboardEmptyStateView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct DashboardEmptyStateView: View {
    var message: String = "No appointments or data available."
    var showAddAppointmentButton: Bool = false
    var onAddAppointment: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .frame(width: 90, height: 90)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text(message)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(message)

            if showAddAppointmentButton, let action = onAddAppointment {
                Button(action: action) {
                    Text("Add Appointment")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Add an appointment")
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: showAddAppointmentButton)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
struct DashboardEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardEmptyStateView()

            DashboardEmptyStateView(
                showAddAppointmentButton: true,
                onAddAppointment: {
                    print("Add Appointment tapped")
                }
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
