//
//  ChartHighlightBadge.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct ChartHighlightBadge: View {
    let text: String
    var backgroundColor: Color = .accentColor

    @Environment(\.colorScheme) private var colorScheme

    private var foregroundColor: Color {
        backgroundColor.isLightColor ? .black : .white
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundColor(foregroundColor)
            .accessibilityLabel(Text(text))
    }
}

private extension Color {
    var isLightColor: Bool {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.6
        #else
        return false
        #endif
    }
}

#if DEBUG
struct ChartHighlightBadge_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach([Color.accentColor, .green, .blue, .red, .yellow, .black], id: \.self) { color in
                ChartHighlightBadge(text: color.description.capitalized, backgroundColor: color)
            }
            .padding()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.light)

            ForEach([Color.accentColor, .green, .blue, .red, .yellow, .black], id: \.self) { color in
                ChartHighlightBadge(text: color.description.capitalized, backgroundColor: color)
            }
            .padding()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.dark)
        }
    }
}
#endif
