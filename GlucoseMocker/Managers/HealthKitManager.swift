import SwiftUI
import HealthKit

// MARK: - HealthKit Manager
class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(false, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: [glucoseType], read: [glucoseType]) { success, error in
            completion(success, error)
        }
    }
    
    func writeGlucoseData(value: Double, unit: GlucoseUnit, timestamp: Date) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }

        var convertedValue = value
        var finalUnit = unit.hkUnit

        // Если выбран mmol/L, конвертируем в mg/dL
        if unit == .mmolL {
            convertedValue *= 18.0182
            finalUnit = HKUnit(from: "mg/dL")
        }

        let quantity = HKQuantity(unit: finalUnit, doubleValue: convertedValue)
        let sample = HKQuantitySample(type: glucoseType, quantity: quantity, start: timestamp, end: timestamp)

        healthStore.save(sample) { success, error in
            if success {
                print("✅ Записано значение глюкозы: \(convertedValue) \(finalUnit) с таймстампом \(timestamp)")
            } else {
                print("❌ Ошибка записи: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            }
        }
    }

}
