//
//  DashboardTipBanner.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
import SwiftUI

struct DashboardTipBanner: View {
    @Binding var isVisible: Bool
    let message: String

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(4)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                        .accessibilityLabel("Dismiss tip")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            .padding(.horizontal)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale),
                                    removal: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tip: \(message)")
        }
    }
}

#if DEBUG
struct DashboardTipBanner_Previews: PreviewProvider {
    @State static var visible = true
    static var previews: some View {
        VStack {
            DashboardTipBanner(isVisible: $visible, message: "Remember to follow up with customers after their appointment.")
            Spacer()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
