import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var viewModel = GlucoseLoggerViewModel()
    
    var body: some View {
        ZStack {
            Form {
                // Ручная запись
                Section(header: Text("Ручная запись")) {
                    Picker("Единицы измерения", selection: $viewModel.selectedUnit) {
                        ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Степпер для ручного значения
                    Stepper(value: $viewModel.glucoseValue,
                            in: (viewModel.selectedUnit == .mgdL ? 54.0...180.0 : 3.0...10.0),
                            step: (viewModel.selectedUnit == .mgdL ? 1.0 : 0.1)) {
                        Text("Ручное значение: \(String(format: "%.1f", viewModel.glucoseValue)) \(viewModel.selectedUnit.rawValue)")
                    }
                    
                    // Кастомный пикер с секундами
                    DatePickerWithSeconds(date: $viewModel.timestamp)
                    
                    HStack {
                        Button("Записать") {
                            viewModel.writeManualGlucoseData()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        Button("Удалить") {
                            viewModel.deleteManualGlucoseData()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                
                // Автоматическая запись
                Section(header: Text("Автоматическая запись")) {
                    DatePickerWithSeconds(date: $viewModel.autoStartTime)
                    DatePickerWithSeconds(date: $viewModel.autoEndTime)
                    
                    // От
                    Stepper(value: $viewModel.autoMinGlucose,
                            in: (viewModel.selectedUnit == .mgdL ? 54.0...180.0 : 3.0...10.0),
                            step: (viewModel.selectedUnit == .mgdL ? 1.0 : 0.1)) {
                        Text("От: \(String(format: "%.1f", viewModel.autoMinGlucose)) \(viewModel.selectedUnit.rawValue)")
                    }
                    
                    // До
                    Stepper(value: $viewModel.autoMaxGlucose,
                            in: viewModel.autoMinGlucose...(viewModel.selectedUnit == .mgdL ? 180.0 : 10.0),
                            step: (viewModel.selectedUnit == .mgdL ? 1.0 : 0.1)) {
                        Text("До: \(String(format: "%.1f", viewModel.autoMaxGlucose)) \(viewModel.selectedUnit.rawValue)")
                    }
                    
                    // Шаг
                    Stepper(value: $viewModel.step, in: 1...10, step: 1) {
                        Text("Шаг: \(String(format: "%.1f", viewModel.step)) \(viewModel.selectedUnit.rawValue)")
                    }
                    
                    // Частота (секунды) — Stepper
                    Stepper(value: $viewModel.intervalInSeconds, in: 1...3600, step: 1) {
                        Text("Частота (сек): \(Int(viewModel.intervalInSeconds))")
                    }
                    
                    HStack {
                        Button(viewModel.isAutoLogging ? "Остановить" : "Запустить") {
                            if viewModel.isAutoLogging {
                                viewModel.stopAutoLogging()
                            } else {
                                viewModel.startAutoLogging()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                        
                        Button("Удалить") {
                            viewModel.deleteAutoLoggedData()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            }
            
            // Всплывающее уведомление (тост)
            if viewModel.showToast {
                VStack {
                    Spacer()
                    HStack {
                        Text(viewModel.toastMessage ?? "")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(12)
                    }
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .top))
                .animation(.easeInOut(duration: 0.5), value: viewModel.showToast)
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
