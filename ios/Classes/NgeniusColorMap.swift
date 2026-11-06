import NISdk
import UIKit

/// Builds the SDK colour set (`NISdkColors`) from the Dart `NgeniusColors` map of ARGB ints.
enum NgeniusColorMap {
    /// A `nil` map restores the SDK defaults; unset slots keep them.
    static func sdkColors(from map: [String: Any]?) -> NISdkColors {
        let colors = NISdkColors()
        guard let map = map else {
            return colors
        }
        func color(_ key: String) -> UIColor? {
            return argb((map[key] as? NSNumber)?.int64Value)
        }
        if let value = color("payButtonBackground") { colors.payButtonBackgroundColor = value }
        if let value = color("payButtonTitle") { colors.payButtonTitleColor = value }
        colors.navigationBarColor = color("navigationBar")
        colors.navigationBarButtonColor = color("navigationBarButton")
        colors.cardPreviewStartColor = color("cardPreviewStart")
        colors.cardPreviewCenterColor = color("cardPreviewCenter")
        colors.cardPreviewEndColor = color("cardPreviewEnd")
        colors.progressLoaderColor = color("progressLoader")
        if let value = color("payPageBackground") { colors.payPageBackgroundColor = value }
        if let value = color("payPageLabel") { colors.payPageLabelColor = value }
        if let value = color("textFieldLabel") { colors.textFieldLabelColor = value }
        if let value = color("payPageTitle") { colors.payPageTitleColor = value }
        return colors
    }

    static func argb(_ value: Int64?) -> UIColor? {
        guard let value = value else {
            return nil
        }
        let bits = UInt32(truncatingIfNeeded: value)
        return UIColor(
            red: CGFloat((bits >> 16) & 0xFF) / 255,
            green: CGFloat((bits >> 8) & 0xFF) / 255,
            blue: CGFloat(bits & 0xFF) / 255,
            alpha: CGFloat((bits >> 24) & 0xFF) / 255
        )
    }
}
