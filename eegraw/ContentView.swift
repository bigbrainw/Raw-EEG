import SwiftUI

struct ContentView: View {
    @StateObject private var bluetoothViewModel = BluetoothViewModel()
    @State private var csvFileNameInput = ""

    var body: some View {
        NavigationView {
            VStack {
                // Device List
                List {
                    Section(header: Text("Discovered Devices")) {
                        ForEach(Array(bluetoothViewModel.peripheralNames.enumerated()), id: \.element) { index, name in
                            Button(action: {
                                bluetoothViewModel.selectPeripheral(at: index)
                            }) {
                                HStack {
                                    Text(name)
                                    if bluetoothViewModel.selectedPeripheralName == name {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())

                // CSV File Name Input
                VStack(alignment: .leading) {
                    Text("CSV File Name:")
                        .font(.headline)
                        .padding(.top)

                    TextField("Enter file name", text: $csvFileNameInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    Button(action: {
                        bluetoothViewModel.csvFileName = csvFileNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("CSV file name set to \(bluetoothViewModel.csvFileName)")
                    }) {
                        Text("Set File Name")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                // Recording Controls
                HStack(spacing: 20) {
                    Button(action: {
                        bluetoothViewModel.startRecording()
                    }) {
                        Text("Start Recording")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        bluetoothViewModel.stopRecording()
                    }) {
                        Text("Stop Recording")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.top)
                .padding(.horizontal)

                // Recording Status
                Text(bluetoothViewModel.isRecording ? "Recording in Progress" : "Not Recording")
                    .font(.subheadline)
                    .foregroundColor(bluetoothViewModel.isRecording ? .green : .red)
                    .padding(.top)

                Spacer()
            }
            .navigationTitle("Bluetooth EEG Recorder")
        }
    }
}
