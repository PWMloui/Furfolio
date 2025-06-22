import SwiftUI

/// An animated checkmark view for confirming successful actions like form submissions or tasks.
struct SuccessCheckmarkView: View {
    /// Color of the circle stroke.
    var circleColor: Color = .green

    /// Color of the checkmark.
    var checkColor: Color = .white

    /// Total size of the icon.
    var size: CGFloat = 72

    /// Stroke width for both circle and checkmark.
    var lineWidth: CGFloat = 7

    /// Optional delay before starting the animation.
    var delay: Double = 0.0

    @State private var animateCircle = false
    @State private var animateCheck = false

    private enum Constants {
        static let circleDuration: Double = 0.38
        static let checkDuration: Double = 0.43
        static let checkDelay: Double = 0.22
        static let shadowOpacity: Double = 0.17
    }

    var body: some View {
        ZStack {
            // Circular trim animation
            Circle()
                .trim(from: 0, to: animateCircle ? 1 : 0)
                .stroke(circleColor.opacity(0.7), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .shadow(color: circleColor.opacity(Constants.shadowOpacity), radius: 10, x: 0, y: 3)
                .animation(.easeOut(duration: Constants.circleDuration).delay(delay), value: animateCircle)

            // Animated checkmark
            CheckmarkShape()
                .trim(from: 0, to: animateCheck ? 1 : 0)
                .stroke(checkColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.53, height: size * 0.53)
                .offset(y: size * 0.07)
                .animation(.easeOut(duration: Constants.checkDuration).delay(delay + Constants.checkDelay), value: animateCheck)
        }
        .onAppear {
            animateCircle = false
            animateCheck = false
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateCircle = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Constants.checkDelay) {
                animateCheck = true
            }
        }
        .accessibilityLabel(Text("Success checkmark confirmed"))
    }
}

/// Custom shape that draws a stylized checkmark using three anchor points.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + rect.width * 0.04, y: rect.midY * 1.15)
        let mid = CGPoint(x: rect.midX * 0.9, y: rect.maxY * 0.98)
        let end = CGPoint(x: rect.maxX * 0.98, y: rect.minY + rect.height * 0.20)
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

// MARK: - Preview

#if DEBUG
struct SuccessCheckmarkView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            SuccessCheckmarkView(circleColor: .green, checkColor: .white, size: 84, delay: 0.1)
            SuccessCheckmarkView(circleColor: .blue, checkColor: .yellow, size: 60)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif
