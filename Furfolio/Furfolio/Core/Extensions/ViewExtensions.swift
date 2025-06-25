//
//  ViewExtensions.swift
//  Furfolio
//
//  Enhanced 2025: All SwiftUI extensions are now tokenized, modular, accessible, traceable, and BI/compliance ready.

import SwiftUI

// MARK: - ViewExtensions Audit/Event Logging

fileprivate struct ViewExtensionAuditEvent: Codable {
    let timestamp: Date
    let extensionName: String
    let tags: [String]
    let actor: String?
    let context: String?
    let additional: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "View extension: \(extensionName) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ViewExtensionAudit {
    static private(set) var log: [ViewExtensionAuditEvent] = []

    static func record(_ extensionName: String, tags: [String], actor: String? = nil, context: String? = nil, additional: String? = nil) {
        let event = ViewExtensionAuditEvent(
            timestamp: Date(),
            extensionName: extensionName,
            tags: tags,
            actor: actor,
            context: context,
            additional: additional
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No extension usage recorded."
    }
}

// MARK: - Public View Extensions for Modular UI Composition (Now Auditable)

public extension View {

    /// Conditionally applies a modifier when `condition` is true.
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        apply: (Self) -> Content,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("if", tags: ["conditional", "composition"], actor: actor, context: context)
        if condition {
            apply(self)
        } else {
            self
        }
    }

    /// Conditionally applies a modifier when optional `value` is non-nil.
    @ViewBuilder
    func ifLet<T, Content: View>(
        _ value: T?,
        apply: (Self, T) -> Content,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("ifLet", tags: ["conditional", "optional", "composition"], actor: actor, context: context)
        if let value = value {
            apply(self, value)
        } else {
            self
        }
    }

    /// Applies a platform-specific modifier: iOS vs macOS.
    @ViewBuilder
    func platformSpecific<Content: View>(
        _ ios: (Self) -> Content,
        mac: (Self) -> Content,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("platformSpecific", tags: ["platform", "tokenized"], actor: actor, context: context)
        #if os(iOS)
        ios(self)
        #elseif os(macOS)
        mac(self)
        #else
        self
        #endif
    }

    /// Hides the view conditionally; optionally removes from layout.
    @ViewBuilder
    func hidden(
        _ isHidden: Bool,
        remove: Bool = true,
        animated: Bool = false,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("hidden", tags: ["visibility", "conditional"], actor: actor, context: context, additional: isHidden ? "hidden" : "visible")
        if isHidden {
            if remove {
                if animated {
                    EmptyView()
                        .transition(.opacity)
                } else {
                    EmptyView()
                }
            } else {
                if animated {
                    self.hidden()
                        .transition(.opacity)
                } else {
                    self.hidden()
                }
            }
        } else {
            self
        }
    }

    /// Applies corner radius to specific corners.
    func cornerRadius(
        _ radius: CGFloat,
        corners: UIRectCorner,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("cornerRadius", tags: ["shape", "tokenized"], actor: actor, context: context, additional: "radius: \(radius), corners: \(corners.rawValue)")
        return clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    /// Applies a default subtle shadow for elevation and depth using design tokens.
    func defaultShadow(actor: String? = nil, context: String? = nil) -> some View {
        ViewExtensionAudit.record("defaultShadow", tags: ["shadow", "elevation", "tokenized"], actor: actor, context: context)
        return self.shadow(
            color: AppShadows.card.color,
            radius: AppShadows.card.radius,
            x: AppShadows.card.x,
            y: AppShadows.card.y
        )
    }

    /// Adds a customizable shimmer overlay for loading placeholders.
    func shimmer(
        isActive: Bool = true,
        cornerRadius: CGFloat? = 7,
        shape: AnyShape? = nil,
        animated: Bool = true,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("shimmer", tags: ["loading", "placeholder", "animation"], actor: actor, context: context, additional: isActive ? "active" : "inactive")
        return self.overlay(
            Group {
                if isActive {
                    AnimationUtils.ShimmerView()
                        .clipShape(
                            shape ?? (cornerRadius != nil ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius!)) : AnyShape(Rectangle()))
                        )
                        .if(animated) { view in
                            view.transition(.opacity)
                        }
                }
            }
        )
    }

    /// Adds a badge overlay at top trailing corner with customizable animation.
    func badge(
        _ count: Int?,
        color: Color = AppColors.accent,
        animated: Bool = true,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("badge", tags: ["badge", "notification", "tokenized"], actor: actor, context: context, additional: "count: \(count ?? 0)")
        return ZStack(alignment: .topTrailing) {
            self
            if let count = count, count > 0 {
                Text("\(count)")
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(AppSpacing.xSmall)
                    .background(color)
                    .clipShape(Circle())
                    .offset(x: AppSpacing.small, y: -AppSpacing.small)
                    .if(animated) { view in
                        view.transition(.scale)
                    }
            }
        }
    }

    /// Adds tap gesture to dismiss keyboard on iOS safely.
    func dismissKeyboardOnTap(actor: String? = nil, context: String? = nil) -> some View {
        ViewExtensionAudit.record("dismissKeyboardOnTap", tags: ["input", "keyboard", "accessibility"], actor: actor, context: context)
        return self.onTapGesture {
            #if canImport(UIKit)
            if UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            #endif
        }
    }

    /// Helper for demo dashboard card styling using design tokens.
    func demoDashboardCard(actor: String? = nil, context: String? = nil) -> some View {
        ViewExtensionAudit.record("demoDashboardCard", tags: ["demo", "dashboard", "tokenized"], actor: actor, context: context)
        return self
            .padding(AppSpacing.medium)
            .background(AppColors.card)
            .cornerRadius(BorderRadius.medium)
            .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
            .padding(.horizontal, AppSpacing.medium)
    }
}

// MARK: - RoundedCorner Shape for Selective Corner Rounding (Unchanged)
public struct RoundedCorner: Shape {
    public var radius: CGFloat = .infinity
    public var corners: UIRectCorner = .allCorners

    public init(radius: CGFloat = .infinity, corners: UIRectCorner = .allCorners) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Extension Audit: Static Accessors for Debug/Admin

public enum ViewExtensionAuditAdmin {
    public static var lastSummary: String { ViewExtensionAudit.accessibilitySummary }
    public static var lastJSON: String? { ViewExtensionAudit.exportLastJSON() }
    public static var logCount: Int { ViewExtensionAudit.log.count }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ViewExtensionAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Example Usage and Preview for Extensions

#if DEBUG
struct ViewExtensionsPreview: View {
    @State private var isLoading = true
    @State private var showBadge = true
    @State private var optionalCount: Int? = 5

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Group {
                    Text("Rounded only top corners")
                        .padding()
                        .background(AppColors.accentBackground)
                        .cornerRadius(BorderRadius.large, corners: [.topLeft, .topRight], actor: "preview")

                    Text("Shimmer loading")
                        .padding()
                        .shimmer(isActive: isLoading, cornerRadius: BorderRadius.medium, animated: true, actor: "preview")
                        .cornerRadius(BorderRadius.medium)
                        .frame(width: 140, height: 34)
                        .background(AppColors.surfaceBackground)

                    Button("Toggle Badge") { withAnimation { showBadge.toggle() } }
                    Image(systemName: "bell.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .badge(showBadge ? 2 : nil, color: AppColors.accent, animated: true, actor: "preview")

                    Text("Hide me!")
                        .hidden(isLoading, remove: true, animated: true, actor: "preview")

                    TextField("Type here", text: .constant(""))
                        .padding()
                        .background(AppColors.inputBackground)
                        .cornerRadius(BorderRadius.medium)
                        .dismissKeyboardOnTap(actor: "preview")
                }

                Group {
                    Text("IfLet example with optional count:")
                        .fontWeight(.semibold)

                    Image(systemName: "star.fill")
                        .ifLet(optionalCount, apply: { view, count in
                            view.badge(count, color: AppColors.accent, actor: "preview")
                        }, actor: "preview")

                    Text("Platform-specific styling:")
                        .fontWeight(.semibold)

                    Text("Hello Platform!")
                        .platformSpecific(
                            { $0.foregroundColor(AppColors.primary) },
                            mac: { $0.foregroundColor(AppColors.secondary) },
                            actor: "preview"
                        )

                    Text("Demo Dashboard Card Example")
                        .demoDashboardCard(actor: "preview")
                }
            }
            .padding()
        }
    }
}

#Preview {
    ViewExtensionsPreview()
}
#endif
