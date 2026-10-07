import SwiftUI

enum CodexPalette {
    static let canvas = Color.dynamic(light: 0xF4F5F7, dark: 0x15181E)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x1E222A)
    static let raised = Color.dynamic(light: 0xFFFFFF, dark: 0x252A34)
    static let ink = Color.dynamic(light: 0x20242C, dark: 0xE8ECF3)
    static let secondaryInk = Color.dynamic(light: 0x626A78, dark: 0xA6AFBF)
    static let line = Color.dynamic(light: 0xDDE1E7, dark: 0x3B424F)
    static let cobalt = Color.dynamic(light: 0x315FDB, dark: 0x8AA9FF)
    static let selection = Color.dynamic(light: 0xE7EDFC, dark: 0x29354F)
    static let userSurface = Color.dynamic(light: 0xEFF2F8, dark: 0x252C38)
    static let teal = Color.dynamic(light: 0x287D78, dark: 0x62C8BE)
    static let amber = Color.dynamic(light: 0x9A5C20, dark: 0xF0B266)
    static let danger = Color.dynamic(light: 0xB83F4A, dark: 0xFF8992)
}

enum CodexLayout {
    // Budget the outer window, before navigation columns or the inspector
    // consume any width. Resizing an inspector must not change this decision.
    static let sidebarThreshold: CGFloat = 900
    static let inspectorThreshold: CGFloat = 1_280
    static let sidebarIdealWidth: CGFloat = 288
    static let conversationMaxWidth: CGFloat = 840
    static let panelRadius: CGFloat = 18
    static let controlRadius: CGFloat = 12
    static let touchTarget: CGFloat = 44
}

private extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct CodexPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: CodexLayout.panelRadius, style: .continuous)
                    .fill(reduceTransparency ? CodexPalette.raised : CodexPalette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: CodexLayout.panelRadius, style: .continuous)
                    .stroke(CodexPalette.line, lineWidth: 0.5)
            }
    }
}

extension View {
    func codexPanel(padding: CGFloat = 16) -> some View {
        modifier(CodexPanelModifier(padding: padding))
    }

    func codexDisplayTitle() -> some View {
        font(.title2.weight(.semibold))
            .foregroundStyle(CodexPalette.ink)
    }
}
