//
//  AppTheme.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: This file provides the single source of truth for all design tokens,
//  unifying the modular styling files into one easy-to-use API.
//

import SwiftUI

public enum AppTheme {
    public enum Colors {
        public static let primary = AppColors.primary
        public static let secondary = AppColors.secondary
        public static let background = AppColors.background
        public static let card = AppColors.card
        
        public static let success = AppColors.success
        public static let warning = AppColors.warning
        public static let danger = AppColors.danger
        
        public static let textPrimary = AppColors.textPrimary
        public static let textSecondary = AppColors.textSecondary
    }
    
    public enum Fonts {
        public static let largeTitle = AppFonts.largeTitle
        public static let title = AppFonts.title
        public static let headline = AppFonts.headline
        public static let body = AppFonts.body
        public static let caption = AppFonts.caption
        public static let button = AppFonts.button
    }
    
    public enum Spacing {
        public static let small: CGFloat = AppSpacing.small
        public static let medium: CGFloat = AppSpacing.medium
        public static let large: CGFloat = AppSpacing.large
        public static let card: CGFloat = AppSpacing.card
    }
    
    public enum CornerRadius {
        public static let small: CGFloat = BorderRadius.small
        public static let medium: CGFloat = BorderRadius.medium
        public static let large: CGFloat = BorderRadius.large
    }
    
    public enum Shadows {
        public static let card = AppShadows.card
        public static let modal = AppShadows.modal
    }
}


/// Usage Example:
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         Text("Hello, World!")
///             .font(AppTheme.Fonts.title)
///             .foregroundColor(AppTheme.Colors.textPrimary)
///             .padding(AppTheme.Spacing.medium)
///             .background(AppTheme.Colors.card)
///             .cornerRadius(AppTheme.CornerRadius.medium)
///             .shadow(color: AppTheme.Shadows.card.color,
///                     radius: AppTheme.Shadows.card.radius,
///                     x: AppTheme.Shadows.card.x,
///                     y: AppTheme.Shadows.card.y)
///     }
/// }
/// ```
