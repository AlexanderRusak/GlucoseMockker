import SwiftUI
import HealthKit

// MARK: - Glucose Unit Enum
enum GlucoseUnit: String, CaseIterable, Identifiable {
    case mmolL = "mmol/L"
    case mgdL = "mg/dL"
    
    var id: String { self.rawValue }
    
    var hkUnit: HKUnit {
        switch self {
        case .mmolL: return HKUnit(from: "mmol/L")
        case .mgdL: return HKUnit(from: "mg/dL")
        }
    }
    
    func convert(value: Double, to unit: GlucoseUnit) -> Double {
        guard self != unit else { return value }
        return self == .mmolL ? value * 18.0182 : value / 18.0182
    }
}
