import SwiftUI
import UIKit

enum Theme {
    /// Pear green for fills, bars and highlights.
    static let pear = Color(red: 0.553, green: 0.722, blue: 0.184)
    /// Deeper green for text, buttons and tints (readable on cream).
    static let accent = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.80, blue: 0.27, alpha: 1)
            : UIColor(red: 0.30, green: 0.48, blue: 0.11, alpha: 1)
    })
    static let cream = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.10, blue: 0.07, alpha: 1)
            : UIColor(red: 1.0, green: 0.973, blue: 0.906, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.17, blue: 0.11, alpha: 1)
            : UIColor(red: 1.0, green: 0.992, blue: 0.96, alpha: 1)
    })
    static let stem = Color(red: 0.36, green: 0.25, blue: 0.15)
    static let leaf = Color(red: 0.23, green: 0.54, blue: 0.20)
}

struct PearMark: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(Theme.pear).frame(width: s * 0.42).offset(y: -s * 0.12)
                Circle().fill(Theme.pear).frame(width: s * 0.70).offset(y: s * 0.14)
                Capsule().fill(Theme.stem)
                    .frame(width: s * 0.05, height: s * 0.16)
                    .rotationEffect(.degrees(15))
                    .offset(x: s * 0.02, y: -s * 0.38)
                Ellipse().fill(Theme.leaf)
                    .frame(width: s * 0.22, height: s * 0.10)
                    .rotationEffect(.degrees(-25))
                    .offset(x: s * 0.14, y: -s * 0.36)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.pear.opacity(0.35), lineWidth: 1)
            )
    }
}

extension View {
    func pearCard() -> some View { modifier(CardBackground()) }
}
