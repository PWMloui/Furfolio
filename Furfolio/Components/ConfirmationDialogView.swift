//
//  ConfirmationDialogView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on 2025-06-27 — added reusable ConfirmationDialogView component.
//

import SwiftUI

/// A reusable overlay that presents a confirmation dialog with customizable title, message, and actions.
struct ConfirmationDialogView<Presenting: View>: View {
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
    self.presenting = presenting()
  }

  /// The view body that wraps the presenting view and conditionally presents the confirmation dialog.
  var body: some View {
    ZStack {
      presenting
      if isPresented {
        Color.black.opacity(0.4)
          .ignoresSafeArea()
        VStack(spacing: 16) {
          Text(title)
            .font(.headline)
          if let message = message {
            Text(message)
              .font(.subheadline)
          }
          HStack {
            Button(cancelButtonTitle) {
              withAnimation { isPresented = false }
            }
            .buttonStyle(.bordered)
            Button(confirmButtonTitle, role: confirmButtonRole) {
              withAnimation {
                isPresented = false
                onConfirm()
              }
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .shadow(radius: 10)
        .transition(.scale.combined(with: .opacity))
      }
    }
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
    cancelButtonRole: ButtonRole = .cancel
  ) -> some View {
    ConfirmationDialogView(
      isPresented: isPresented,
      title: title,
      message: message,
      confirmButtonTitle: confirmButtonTitle,
      confirmButtonRole: confirmButtonRole,
      onConfirm: onConfirm,
      cancelButtonTitle: cancelButtonTitle,
      cancelButtonRole: cancelButtonRole
    ) {
      self
    }
  }
}
