import SwiftUI

/// Fareback's identity: a rust-orange/asphalt-charcoal road palette —
/// evokes pavement, taillights, and highway signage. Distinct from every
/// sibling app's colors (no blue/lime/cream/sage reused).
enum FBTheme {
    static let backdrop = Color(red: 0.965, green: 0.949, blue: 0.929)   // warm concrete
    static let surface = Color.white
    static let surfaceRaised = Color(red: 0.925, green: 0.902, blue: 0.867)
    static let ink = Color(red: 0.153, green: 0.145, blue: 0.137)        // asphalt-charcoal
    static let inkFaded = Color(red: 0.153, green: 0.145, blue: 0.137).opacity(0.55)
    static let rule = Color.black.opacity(0.08)

    static let rust = Color(red: 0.769, green: 0.318, blue: 0.129)      // taillight rust-orange
    static let rustBright = Color(red: 0.898, green: 0.420, blue: 0.184)
    static let signGreen = Color(red: 0.204, green: 0.416, blue: 0.302) // highway sign green
    static let danger = Color(red: 0.702, green: 0.204, blue: 0.196)
    static let success = Color(red: 0.204, green: 0.416, blue: 0.302)

    static let titleFont = Font.system(.title2, design: .rounded).weight(.bold)
    static let headlineFont = Font.system(.headline, design: .rounded).weight(.semibold)
}

struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
    }
}

extension View {
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}
