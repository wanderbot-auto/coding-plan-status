import SwiftUI
import CodingPlanStatusCore

enum AppTheme {
    static let primary100 = Color(hex: "3F51B5")
    static let primary200 = Color(hex: "757de8")
    static let primary300 = Color(hex: "dedeff")
    static let accent100 = Color(hex: "2196F3")
    static let accent200 = Color(hex: "003f8f")
    static let text100 = Color(hex: "333333")
    static let text200 = Color(hex: "5c5c5c")
    static let bg100 = Color(hex: "FFFFFF")
    static let bg200 = Color(hex: "f5f5f5")
    static let bg300 = Color(hex: "cccccc")

    static func statusTint(_ severity: StatusSeverity) -> Color {
        switch severity {
        case .ok:
            return accent100
        case .warning:
            return primary200
        case .critical, .error:
            return accent200
        case .unsupported:
            return bg300
        }
    }

    static func statusText(_ severity: StatusSeverity) -> String {
        switch severity {
        case .ok:
            return "正常"
        case .warning:
            return "预警"
        case .critical:
            return "临界"
        case .error:
            return "异常"
        case .unsupported:
            return "未配置"
        }
    }

    static func menuBarSymbol(_ severity: StatusSeverity) -> String {
        switch severity {
        case .ok:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        case .error:
            return "xmark.octagon.fill"
        case .unsupported:
            return "questionmark.circle.fill"
        }
    }

    static func providerSymbol(_ provider: ProviderID) -> String {
        switch provider {
        case .glm:
            return "cpu"
        case .minimax:
            return "waveform.path.ecg"
        }
    }

    static func providerTint(_ provider: ProviderID) -> Color {
        switch provider {
        case .glm:
            return primary100
        case .minimax:
            return accent100
        }
    }
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64

        switch clean.count {
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        default:
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
