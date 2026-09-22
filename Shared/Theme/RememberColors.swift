import SwiftUI

enum RememberColors {
    /// Exact mid pixel from AppIcon.png (96, 201, 252).
    static let brandBlue = Color(red: 96 / 255, green: 201 / 255, blue: 252 / 255)

    static var pageBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.black
        #endif
    }

    static var cardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.gray.opacity(0.2)
        #endif
    }

    static var elevatedBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.black
        #endif
    }
}
