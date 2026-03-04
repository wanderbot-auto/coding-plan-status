import Foundation
import CodingPlanStatusCore

enum ProviderMappingSupport {
    static func severity(usedPercent: Double, thresholds: [Int] = [80, 90, 95]) -> StatusSeverity {
        let sorted = thresholds.sorted()
        if usedPercent >= Double(sorted.last ?? 95) {
            return .critical
        }
        if usedPercent >= Double(sorted.dropLast().last ?? 90) {
            return .warning
        }
        return .ok
    }

    static func parseJSON(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    static func decimal(from any: Any?) -> Decimal? {
        if let decimal = any as? Decimal { return decimal }
        if let number = any as? NSNumber { return number.decimalValue }
        if let str = any as? String, let double = Double(str) { return Decimal(double) }
        return nil
    }

    static func double(from any: Any?) -> Double? {
        if let double = any as? Double { return double }
        if let num = any as? NSNumber { return num.doubleValue }
        if let str = any as? String { return Double(str) }
        return nil
    }

    static func int(from any: Any?) -> Int? {
        if let int = any as? Int { return int }
        if let num = any as? NSNumber { return num.intValue }
        if let str = any as? String { return Int(str) }
        return nil
    }

    static func dateFromISO(_ value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) {
            return date
        }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fallback.date(from: string)
    }

    static func nestedValue(in dict: [String: Any], path: [String]) -> Any? {
        var current: Any = dict
        for key in path {
            guard let map = current as? [String: Any], let value = map[key] else {
                return nil
            }
            current = value
        }
        return current
    }
}
