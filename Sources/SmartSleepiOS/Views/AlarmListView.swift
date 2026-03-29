import SwiftUI
import SmartSleepDomain

public struct AlarmListView: View {
    @ObservedObject private var viewModel: AlarmListViewModel
    @State private var editingAlarm: Alarm?
    @State private var showingEditor = false

    public init(viewModel: AlarmListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if !viewModel.permissionStatus.isReadyForSmartMode {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("智能模式权限未就绪")
                            Text(viewModel.permissionGuideText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("立即授权") {
                                viewModel.requestPermissions()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("打开系统设置") {
                                viewModel.openSystemSettings()
                            }
                        }
                    }
                }

                Section("默认设置") {
                    Stepper(
                        "默认贪睡 \(viewModel.defaultSnoozeMinutes) 分钟",
                        value: Binding(
                            get: { viewModel.defaultSnoozeMinutes },
                            set: { viewModel.updateDefaultSnoozeMinutes($0) }
                        ),
                        in: 1...30
                    )
                }

                Section("设备连接") {
                    Text(viewModel.watchSessionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("闹铃") {
                    ForEach(viewModel.alarms) { alarm in
                        alarmRow(alarm)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            viewModel.delete(alarmID: viewModel.alarms[index].id)
                        }
                    }
                }
            }
            .navigationTitle("SmartSleep")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingAlarm = nil
                        showingEditor = true
                    } label: {
                        Label("新建", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                AlarmEditorView(
                    alarm: editingAlarm,
                    defaultSnoozeMinutes: viewModel.defaultSnoozeMinutes
                ) { alarm in
                    viewModel.save(alarm: alarm)
                }
            }
            .task {
                viewModel.onAppear()
            }
        }
    }

    @ViewBuilder
    private func alarmRow(_ alarm: Alarm) -> some View {
        Button {
            editingAlarm = alarm
            showingEditor = true
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(String(format: "%02d:%02d", alarm.hour, alarm.minute))
                        .font(.title3.monospacedDigit())
                    Text(alarm.label)
                        .foregroundStyle(.secondary)
                    Text(alarm.smartModeEnabled ? "智能模式开" : "智能模式关")
                        .font(.caption)
                }
                Spacer()
                Image(systemName: alarm.enabled ? "alarm.fill" : "alarm")
                    .foregroundStyle(alarm.enabled ? .orange : .gray)
            }
        }
    }
}
