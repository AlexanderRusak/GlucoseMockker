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
    
    @Published var showToast: Bool = false
    @Published var toastMessage: String?
    
    private let healthStore = HKHealthStore()
    
    init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }
        
        healthStore.requestAuthorization(toShare: [glucoseType], read: [glucoseType]) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit доступ разрешен")
                } else {
                    self.showToastMessage("❌ Ошибка авторизации HealthKit")
                }
            }
        }
    }
    
    private func convertValues(from oldUnit: GlucoseUnit, to newUnit: GlucoseUnit) {
        guard oldUnit != newUnit else { return }
        
        let conversionFactor = 18.0182
        if newUnit == .mgdL {
            glucoseValue *= conversionFactor
            minGlucose *= conversionFactor
            maxGlucose *= conversionFactor
        } else {
            glucoseValue /= conversionFactor
            minGlucose /= conversionFactor
            maxGlucose /= conversionFactor
        }
    }

    func writeManualGlucoseData() {
        writeGlucoseData(value: glucoseValue, timestamp: timestamp, isManual: true)
    }

    func startAutoLogging() {
        guard !isAutoLogging else { return }
        isAutoLogging = true
        logAllEntriesInRange()
    }
    
    func stopAutoLogging() {
        isAutoLogging = false
    }
    
    func logAllEntriesInRange() {
        var currentTime = autoStartTime
        let maxEntries = Int((autoEndTime.timeIntervalSince(autoStartTime) / 60) / interval)
        var count = 0
        
        while currentTime <= autoEndTime && isAutoLogging && count < maxEntries {
            let randomGlucose = Double.random(in: minGlucose...maxGlucose)
            writeGlucoseData(value: randomGlucose, timestamp: currentTime, isManual: false)

            currentTime = Calendar.current.date(byAdding: .minute, value: Int(interval), to: currentTime) ?? currentTime
            count += 1
        }

        DispatchQueue.main.async {
            self.showToastMessage("✅ Записано автоматически: \(count) значений")
            self.isAutoLogging = false
        }
    }
    
    private func writeGlucoseData(value: Double, timestamp: Date, isManual: Bool) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }
        
        var convertedValue = value
        let finalUnit = HKUnit(from: "mg/dL") // HealthKit требует mg/dL
        
        if selectedUnit == .mmolL {
            convertedValue *= 18.0182
        }
        
        let quantity = HKQuantity(unit: finalUnit, doubleValue: convertedValue)
        let sample = HKQuantitySample(type: glucoseType, quantity: quantity, start: timestamp, end: timestamp)
        
        healthStore.save(sample) { [weak self] success, error in
            DispatchQueue.main.async {
                if success && isManual {
                    self?.showToastMessage("✅ Записано вручную: \(convertedValue) \(self?.selectedUnit.rawValue ?? "")")
                } else if !success {
                    self?.showToastMessage("❌ Ошибка записи: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                }
            }
        }
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showToast = false
        }
    }
}
