//
//  BusinessHealthScoreView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
import SwiftUI

struct BusinessHealthScoreView: View {
    let score: Int

    private var scoreColor: Color {
        switch score {
        case 75...100:
            return .green
        case 50..<75:
            return .yellow
        default:
            return .red
        }
    }

    private var healthStatusLabel: String {
        switch score {
        case 75...100:
            return "Excellent"
        case 50..<75:
            return "Moderate"
        default:
            return "Critical"
        }
    }

    private var statusMessage: String {
        switch score {
        case 75...100:
            return "Your business is thriving. Great customer retention and solid growth!"
        case 50..<75:
            return "Your business is stable but could benefit from better appointment frequency or revenue improvements."
        default:
            return "Your business needs attention. Consider retention strategies or re-engagement campaigns."
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Business Health Score")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(score)")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(scoreColor)

            Text(healthStatusLabel)
                .font(.subheadline.weight(.medium))
                .foregroundColor(scoreColor)

            Text(statusMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: scoreColor.opacity(0.4), radius: 8, x: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Business health score is \(score), rated as \(healthStatusLabel). \(statusMessage)")
    }
}

#if DEBUG
struct BusinessHealthScoreView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BusinessHealthScoreView(score: 85)
            BusinessHealthScoreView(score: 65)
            BusinessHealthScoreView(score: 40)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
