import SwiftUI

/// A reusable view that displays an empty-state message with an optional action.
struct EmptyStateView: View {
    let imageName: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            if let message = message {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyStateView(
                imageName: "tray",
                title: "No Items Found",
                message: "You don’t have any items yet. Tap the button below to add your first item.",
                actionTitle: "Add Item",
                action: {}
            )
            .previewDisplayName("With Action")

            EmptyStateView(
                imageName: "tray",
                title: "No Items Found",
                message: "You don’t have any items yet.",
                actionTitle: nil,
                action: nil
            )
            .previewDisplayName("Without Action")
        }
    }
}
