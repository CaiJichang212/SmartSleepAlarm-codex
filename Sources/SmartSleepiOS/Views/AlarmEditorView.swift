import SwiftUI
import SmartSleepDomain

public struct AlarmEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let baseAlarm: Alarm?
    private let onSave: (Alarm) -> Void
    private let ringtoneOptions: [(id: String, name: String)] = [
        ("default", "默认"),
        ("system_bell", "铃铛"),
        ("system_radar", "雷达"),
        ("system_chime", "和弦")
    ]

    @State private var hour: Int
    @State private var minute: Int
    @State private var label: String
    @State private var soundID: String
    @State private var enabled: Bool
    @State private var smartModeEnabled: Bool
    @State private var snoozeMinutes: Int
    @State private var weekdays: Set<Weekday>

    public init(alarm: Alarm? = nil, defaultSnoozeMinutes: Int = 5, onSave: @escaping (Alarm) -> Void) {
        self.baseAlarm = alarm
        self.onSave = onSave

        _hour = .init(initialValue: alarm?.hour ?? 7)
        _minute = .init(initialValue: alarm?.minute ?? 0)
        _label = .init(initialValue: alarm?.label ?? "起床")
        _soundID = .init(initialValue: alarm?.soundID ?? "default")
        _enabled = .init(initialValue: alarm?.enabled ?? true)
        _smartModeEnabled = .init(initialValue: alarm?.smartModeEnabled ?? true)
        _snoozeMinutes = .init(initialValue: alarm?.snoozeMinutes ?? defaultSnoozeMinutes)
        _weekdays = .init(initialValue: alarm?.repeatWeekdays ?? [])
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("时间") {
                    HStack {
                        Stepper("小时: \(hour)", value: $hour, in: 0...23)
                        Stepper("分钟: \(minute)", value: $minute, in: 0...59)
                    }
                }

                Section("基础") {
                    TextField("标签", text: $label)
                    Picker("铃声", selection: $soundID) {
                        ForEach(ringtoneOptions, id: \.id) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    Toggle("启用", isOn: $enabled)
                    Toggle("智能模式", isOn: $smartModeEnabled)
                    Stepper("贪睡 \(snoozeMinutes) 分钟", value: $snoozeMinutes, in: 1...30)
                }

                Section("重复") {
                    ForEach(Weekday.allCases, id: \.rawValue) { weekday in
                        Toggle(dayText(weekday), isOn: binding(for: weekday))
                    }
                }
            }
            .navigationTitle(baseAlarm == nil ? "新建闹铃" : "编辑闹铃")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let alarm = Alarm(
                            id: baseAlarm?.id ?? UUID(),
                            hour: hour,
                            minute: minute,
                            repeatWeekdays: weekdays,
                            label: label,
                            soundID: soundID,
                            enabled: enabled,
                            smartModeEnabled: smartModeEnabled,
                            snoozeMinutes: snoozeMinutes
                        )
                        onSave(alarm)
                        dismiss()
                    }
                }
            }
        }
    }

    private func binding(for weekday: Weekday) -> Binding<Bool> {
        Binding {
            weekdays.contains(weekday)
        } set: { enabled in
            if enabled {
                weekdays.insert(weekday)
            } else {
                weekdays.remove(weekday)
            }
        }
    }

    private func dayText(_ day: Weekday) -> String {
        switch day {
        case .sunday: return "周日"
        case .monday: return "周一"
        case .tuesday: return "周二"
        case .wednesday: return "周三"
        case .thursday: return "周四"
        case .friday: return "周五"
        case .saturday: return "周六"
        }
    }
}
