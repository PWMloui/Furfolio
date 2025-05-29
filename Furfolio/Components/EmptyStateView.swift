import SwiftUI
import os

private enum EmptyStateImageSizeKey: EnvironmentKey {
  static let defaultValue: CGFloat = 80
}
private enum EmptyStateVerticalSpacingKey: EnvironmentKey {
  static let defaultValue: CGFloat = 16
}
private enum EmptyStateBackgroundColorKey: EnvironmentKey {
  static let defaultValue: Color = Color(.systemBackground)
}
extension EnvironmentValues {
  var emptyStateImageSize: CGFloat {
    get { self[EmptyStateImageSizeKey.self] }
    set { self[EmptyStateImageSizeKey.self] = newValue }
  }
  var emptyStateVerticalSpacing: CGFloat {
    get { self[EmptyStateVerticalSpacingKey.self] }
    set { self[EmptyStateVerticalSpacingKey.self] = newValue }
  }
  var emptyStateBackgroundColor: Color {
    get { self[EmptyStateBackgroundColorKey.self] }
    set { self[EmptyStateBackgroundColorKey.self] = newValue }
  }
}

extension View {
  func onActionHaptic(_ enabled: Bool) -> some View {
    self.onTapGesture {
      if enabled {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
      }
    }
  }
}

/// A reusable view that displays an empty-state message with an optional action.
struct EmptyStateView: View {
    let imageName: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let enableHaptics: Bool

    @Environment(\.emptyStateImageSize) private var imageSize
    @Environment(\.emptyStateVerticalSpacing) private var verticalSpacing
    @Environment(\.emptyStateBackgroundColor) private var backgroundColor

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "EmptyStateView")

    var body: some View {
        VStack(spacing: verticalSpacing) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                .foregroundColor(AppTheme.secondaryText)
                .padding(.bottom, 8)

            Text(title)
                .font(AppTheme.title)
                .fontWeight(.bold)

            if let message = message {
                Text(message)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    logger.log("EmptyStateView action tapped: \(actionTitle)")
                    action()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
                .onActionHaptic(enableHaptics)
            }
        }
        .onAppear {
            logger.log("EmptyStateView presented: \(title)")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .background(AppTheme.background)
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
                action: {},
                enableHaptics: false
            )
            .previewDisplayName("With Action")

            EmptyStateView(
                imageName: "tray",
                title: "No Items Found",
                message: "You don’t have any items yet.",
                actionTitle: nil,
                action: nil,
                enableHaptics: false
            )
            .previewDisplayName("Without Action")
        }
    }
}
