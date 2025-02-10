import SwiftUI
import HealthKit

// MARK: - Glucose Logger ViewModel
class GlucoseLoggerViewModel: ObservableObject {
    @Published var isAutoLogging = false
    @Published var glucoseValue: Double = 100.0
    @Published var minGlucose: Double = 72.0
    @Published var maxGlucose: Double = 140.0
    @Published var interval: Double = 5
    @Published var step: Double = 1.0 // Шаг увеличения
    @Published var timestamp: Date = Date()
    
    @Published var autoMinGlucose: Double = 72.0
    @Published var autoMaxGlucose: Double = 140.0
    @Published var autoStartTime: Date = Calendar.current.date(byAdding: .minute, value: -5, to: Date()) ?? Date()
    @Published var autoEndTime: Date = Calendar.current.date(byAdding: .minute, value: 0, to: Date()) ?? Date()

    @Published var selectedUnit: GlucoseUnit = .mgdL {
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
            autoMinGlucose *= conversionFactor
            autoMaxGlucose *= conversionFactor
        } else {
            glucoseValue /= conversionFactor
            minGlucose /= conversionFactor
            maxGlucose /= conversionFactor
            autoMinGlucose /= conversionFactor
            autoMaxGlucose /= conversionFactor
        }
    }

    func writeManualGlucoseData() {
        writeGlucoseData(value: glucoseValue, timestamp: timestamp)
    }
    
    func deleteManualGlucoseData() {
        deleteGlucoseData(timestamp: timestamp)
    }

    func startAutoLogging() {
        guard !isAutoLogging else { return }
        isAutoLogging = true
        logAllEntriesInRange()
    }
    
    func stopAutoLogging() {
        isAutoLogging = false
    }
    
    func deleteAutoLoggedData() {
        deleteGlucoseData(timestamp: autoStartTime, endTimestamp: autoEndTime)
    }
    
    func logAllEntriesInRange() {
        var currentTime = autoStartTime
        var currentValue = autoMinGlucose
        let maxEntries = Int((autoEndTime.timeIntervalSince(autoStartTime) / 60) / interval)
        var count = 0
        var increasing = true // Направление изменения

        while currentTime <= autoEndTime && isAutoLogging && count < maxEntries {
            writeGlucoseData(value: currentValue, timestamp: currentTime)

            // Изменяем значение по шагу
            if increasing {
                currentValue += step
                if currentValue >= autoMaxGlucose {
                    currentValue = autoMaxGlucose
                    increasing = false // Начинаем уменьшать
                }
            } else {
                currentValue -= step
                if currentValue <= autoMinGlucose {
                    currentValue = autoMinGlucose
                    increasing = true // Начинаем увеличивать
                }
            }

            currentTime = Calendar.current.date(byAdding: .minute, value: Int(interval), to: currentTime) ?? currentTime
            count += 1
        }

        DispatchQueue.main.async {
            self.showToastMessage("✅ Записано автоматически: \(count) значений")
            self.isAutoLogging = false
        }
    }
    
    private func writeGlucoseData(value: Double, timestamp: Date) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }
        
        var convertedValue = value
        let finalUnit = HKUnit(from: "mg/dL")
        
        if selectedUnit == .mmolL {
            convertedValue *= 18.0182
        }
        
        let quantity = HKQuantity(unit: finalUnit, doubleValue: convertedValue)
        let sample = HKQuantitySample(type: glucoseType, quantity: quantity, start: timestamp, end: timestamp)
        
        healthStore.save(sample) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showToastMessage("✅ Записано: \(convertedValue) \(self?.selectedUnit.rawValue ?? "")")
                } else {
                    self?.showToastMessage("❌ Ошибка записи: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                }
            }
        }
    }
    
    private func deleteGlucoseData(timestamp: Date, endTimestamp: Date? = nil) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }

        let adjustedEndTimestamp = endTimestamp ?? Calendar.current.date(byAdding: .minute, value: 1, to: timestamp)

        let predicate = HKQuery.predicateForSamples(
            withStart: timestamp,
            end: adjustedEndTimestamp,
            options: .strictEndDate
        )

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, results, error in
            guard let self = self, let samples = results as? [HKQuantitySample], error == nil else {
                DispatchQueue.main.async {
                    self?.showToastMessage("❌ Ошибка удаления: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                }
                return
            }

            guard !samples.isEmpty else {
                DispatchQueue.main.async {
                    self.showToastMessage("⚠️ Нет записей для удаления")
                }
                return
            }

            self.healthStore.delete(samples) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.showToastMessage("🗑 Удалено: \(samples.count) записей")
                    } else {
                        self.showToastMessage("❌ Ошибка удаления: \(error?.localizedDescription ?? "Неизвестная ошибка")")
                    }
                }
            }
        }

        healthStore.execute(query)
    }

    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showToast = false
        }
    }
}
