//
//  ConfirmationDialogView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on 2025-06-27 — added reusable ConfirmationDialogView component.
//

import SwiftUI
import os

/// A reusable overlay that presents a confirmation dialog with customizable title, message, and actions.
struct ConfirmationDialogView<Presenting: View>: View {
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ConfirmationDialogView")
  @Binding var isPresented: Bool
  let title: String
  let message: String?
  let confirmButtonTitle: String
  let confirmButtonRole: ButtonRole
  let onConfirm: () -> Void
  /// Title for the cancel action button.
  let cancelButtonTitle: String
  /// Role for the cancel action button.
  let cancelButtonRole: ButtonRole
  let presenting: Presenting

  let backdropOpacity: Double
  let dismissOnBackgroundTap: Bool
  let animation: Animation
  let enableHaptics: Bool

  /// Initializes the confirmation dialog wrapper.
  /// - Parameters:
  ///   - isPresented: Binding to control presentation state.
  ///   - title: The dialog’s title text.
  ///   - message: Optional descriptive message.
  ///   - confirmButtonTitle: Title for the confirm action button.
  ///   - confirmButtonRole: Role (e.g. destructive) for the confirm button.
  ///   - onConfirm: Closure to execute when confirmed.
  ///   - presenting: The view over which the dialog is presented.
  init(
    isPresented: Binding<Bool>,
    title: String,
    message: String? = nil,
    confirmButtonTitle: String = "OK",
    confirmButtonRole: ButtonRole = .destructive,
    onConfirm: @escaping () -> Void,
    cancelButtonTitle: String = "Cancel",
    cancelButtonRole: ButtonRole = .cancel,
    backdropOpacity: Double = 0.4,
    dismissOnBackgroundTap: Bool = true,
    animation: Animation = .easeInOut(duration: 0.2),
    enableHaptics: Bool = false,
    @ViewBuilder presenting: () -> Presenting
  ) {
    self._isPresented = isPresented
    self.title = title
    self.message = message
    self.confirmButtonTitle = confirmButtonTitle
    self.confirmButtonRole = confirmButtonRole
    self.onConfirm = onConfirm
    self.cancelButtonTitle = cancelButtonTitle
    self.cancelButtonRole = cancelButtonRole
    self.backdropOpacity = backdropOpacity
    self.dismissOnBackgroundTap = dismissOnBackgroundTap
    self.animation = animation
    self.enableHaptics = enableHaptics
    self.presenting = presenting()
  }

  /// The view body that wraps the presenting view and conditionally presents the confirmation dialog.
  var body: some View {
    ZStack {
      presenting
      if isPresented {
        Rectangle()
          .fill(Color.black.opacity(backdropOpacity))
          .background(AppTheme.background.opacity(backdropOpacity))
          .ignoresSafeArea()
          .contentShape(Rectangle())
          .onTapGesture {
            if dismissOnBackgroundTap {
              withAnimation(animation) {
                isPresented = false
              }
            }
          }
        VStack(spacing: 16) {
          Text(title)
            .font(AppTheme.header)
            .foregroundColor(AppTheme.primaryText)
          if let message = message {
            Text(message)
              .font(AppTheme.body)
              .foregroundColor(AppTheme.secondaryText)
          }
          HStack {
            Button(cancelButtonTitle) {
              logger.log("ConfirmationDialog cancelled")
              if enableHaptics {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
              }
              withAnimation {
                isPresented = false
              }
            }
            .buttonStyle(FurfolioButtonStyle())
            Button(confirmButtonTitle, role: confirmButtonRole) {
              logger.log("ConfirmationDialog confirmed")
              if enableHaptics {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
              }
              withAnimation {
                isPresented = false
                onConfirm()
              }
            }
            .buttonStyle(FurfolioButtonStyle())
          }
          .onAppear {
            logger.log("ConfirmationDialog actions rendered")
          }
        }
        .onAppear {
          logger.log("ConfirmationDialog presented: \(title)")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadius).fill(AppTheme.background))
        .shadow(color: Color.black.opacity(0.2), radius: AppTheme.cornerRadius)
        .transition(.scale.combined(with: .opacity))
      }
    }
    .animation(animation, value: isPresented)
  }
}


/// Convenience modifier to attach a confirmation dialog using `ConfirmationDialogView`.
extension View {
  /// Presents a confirmation dialog overlay on this view.
  func confirmationDialog(
    isPresented: Binding<Bool>,
    title: String,
    message: String? = nil,
    confirmButtonTitle: String = "OK",
    confirmButtonRole: ButtonRole = .destructive,
    onConfirm: @escaping () -> Void,
    cancelButtonTitle: String = "Cancel",
    cancelButtonRole: ButtonRole = .cancel,
    backdropOpacity: Double = 0.4,
    dismissOnBackgroundTap: Bool = true,
    animation: Animation = .easeInOut(duration: 0.2),
    enableHaptics: Bool = false
  ) -> some View {
    ConfirmationDialogView(
      isPresented: isPresented,
      title: title,
      message: message,
      confirmButtonTitle: confirmButtonTitle,
      confirmButtonRole: confirmButtonRole,
      onConfirm: onConfirm,
      cancelButtonTitle: cancelButtonTitle,
      cancelButtonRole: cancelButtonRole,
      backdropOpacity: backdropOpacity,
      dismissOnBackgroundTap: dismissOnBackgroundTap,
      animation: animation,
      enableHaptics: enableHaptics
    ) {
      self
    }
  }
}
