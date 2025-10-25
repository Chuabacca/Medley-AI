import SwiftUI

extension Color {
    // MARK: - Brand Colors
    
    /// Primary brand color - warm terracotta/rose (rgb: 0.7, 0.45, 0.4)
    /// Used for headings, accents, and brand elements
    static let brandPrimary = Color(red: 0.7, green: 0.45, blue: 0.4)
    
    /// Darker brand color - deep rose (rgb: 0.6, 0.35, 0.35)
    /// Used for headers, emphasized sections
    static let brandDark = Color(red: 0.6, green: 0.35, blue: 0.35)
    
    /// Background color - warm off-white (rgb: 0.97, 0.95, 0.93)
    /// Used for screen backgrounds
    static let backgroundWarm = Color(red: 0.97, green: 0.95, blue: 0.93)
    
    // MARK: - UI Colors
    
    /// Card background - pure white
    static let cardBackground = Color.white
    
    /// Card shadow color with 8% opacity
    static let cardShadow = Color.black.opacity(0.08)
}
