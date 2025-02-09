import SwiftUI
import HealthKit

// MARK: - Content View
struct ContentView: View {
    @StateObject private var viewModel = GlucoseLoggerViewModel()
    
    var body: some View {
        ZStack {
            Form {
                Section(header: Text("Ручная запись")) {
                    Picker("Единицы измерения", selection: $viewModel.selectedUnit) {
                        ForEach(GlucoseUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Stepper(
                        value: $viewModel.glucoseValue,
                        in: viewModel.selectedUnit == .mgdL ? 54.0...180.0 : 3.0...10.0,
                        step: viewModel.selectedUnit == .mgdL ? 1.0 : 0.1
                    ) {
                        Text("Ручное значение: \(String(format: "%.1f", viewModel.glucoseValue)) \(viewModel.selectedUnit.rawValue)")
                    }
                    
                    DatePicker(
                        "Выберите время записи",
                        selection: $viewModel.timestamp,
                        displayedComponents: [.hourAndMinute, .date]
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    
                    Button("Записать глюкозу") {
                        viewModel.writeManualGlucoseData()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Section(header: Text("Автоматическая запись")) {
                    DatePicker("Время начала", selection: $viewModel.autoStartTime, displayedComponents: [.hourAndMinute, .date])
                        .datePickerStyle(CompactDatePickerStyle())
                    
                    DatePicker("Время окончания", selection: $viewModel.autoEndTime, displayedComponents: [.hourAndMinute, .date])
                        .datePickerStyle(CompactDatePickerStyle())
                    
                    Stepper("Частота (мин): \(Int(viewModel.interval))", value: $viewModel.interval, in: 1...60, step: 1)
                    
                    Button(viewModel.isAutoLogging ? "Остановить" : "Запустить") {
                        if viewModel.isAutoLogging {
                            viewModel.stopAutoLogging()
                        } else {
                            viewModel.startAutoLogging()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
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
