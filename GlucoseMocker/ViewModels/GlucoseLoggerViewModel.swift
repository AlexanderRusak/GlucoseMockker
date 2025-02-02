import SwiftUI
import HealthKit

// MARK: - Glucose Logger ViewModel
class GlucoseLoggerViewModel: ObservableObject {
    @Published var isAutoLogging = false
    @Published var glucoseValue: Double = 100.0 // Начальное значение в mg/dL
    @Published var minGlucose: Double = 72.0
    @Published var maxGlucose: Double = 140.0
    @Published var interval: Double = 5 // Минуты
    @Published var timestamp: Date = Date()
    @Published var autoStartTime: Date = Calendar.current.date(byAdding: .minute, value: -5, to: Date()) ?? Date()
    @Published var autoEndTime: Date = Calendar.current.date(byAdding: .minute, value: 0, to: Date()) ?? Date()
    @Published var selectedUnit: GlucoseUnit = .mgdL { // mg/dL теперь по умолчанию
        didSet { convertValues(from: oldValue, to: selectedUnit) }
    }
    
    private var timer: Timer?
    private let healthStore = HKHealthStore()
    
    init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }
        
        healthStore.requestAuthorization(toShare: [glucoseType], read: [glucoseType]) { success, error in
            if success {
                print("✅ HealthKit доступ разрешен")
            } else {
                print("❌ Ошибка авторизации HealthKit: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            }
        }
    }
    
    private func convertValues(from oldUnit: GlucoseUnit, to newUnit: GlucoseUnit) {
        guard oldUnit != newUnit else { return }
        
        if newUnit == .mgdL {
            glucoseValue *= 18.0182
            minGlucose *= 18.0182
            maxGlucose *= 18.0182
        } else {
            glucoseValue /= 18.0182
            minGlucose /= 18.0182
            maxGlucose /= 18.0182
        }
    }

    func writeManualGlucoseData() {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }
        
        var convertedValue = glucoseValue
        var finalUnit = selectedUnit.hkUnit
        
        if selectedUnit == .mmolL {
            convertedValue /= 18.0182
            finalUnit = HKUnit(from: "mg/dL")
        }
        
        let quantity = HKQuantity(unit: finalUnit, doubleValue: convertedValue)
        let sample = HKQuantitySample(type: glucoseType, quantity: quantity, start: timestamp, end: timestamp)
        
        healthStore.save(sample) { success, error in
            if success {
                print("✅ Записано значение глюкозы: \(convertedValue) \(finalUnit) с таймстампом \(self.timestamp)")
            } else {
                print("❌ Ошибка записи: \(error?.localizedDescription ?? "Неизвестная ошибка")")
            }
        }
    }

    func startAutoLogging() {
        guard !isAutoLogging else { return }
        isAutoLogging = true
        logAllEntriesInRange()
    }
    
    func stopAutoLogging() {
        isAutoLogging = false
        timer?.invalidate()
    }
    
    func logAllEntriesInRange() {
        var currentTime = autoStartTime
        let maxEntries = Int((autoEndTime.timeIntervalSince(autoStartTime) / 60) / interval)
        var count = 0
        
        while currentTime <= autoEndTime && isAutoLogging && count <= maxEntries {
            let randomGlucose = Double.random(in: minGlucose...maxGlucose)
            writeManualGlucoseData()
            print("Записано значение \(randomGlucose) \(selectedUnit.rawValue) на \(currentTime)")
            
            currentTime = Calendar.current.date(byAdding: .minute, value: Int(interval), to: currentTime) ?? currentTime
            count += 1
        }
        
        DispatchQueue.main.async {
            self.isAutoLogging = false
        }
    }
}
