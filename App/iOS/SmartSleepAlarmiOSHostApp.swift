import SwiftUI
import SwiftData
import SmartSleepInfra
import SmartSleepiOS

@main
struct SmartSleepAlarmiOSHostApp: App {
    @StateObject private var viewModel: AlarmListViewModel

    init() {
        let schema = Schema([AlarmEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let repository = SwiftDataAlarmRepositoryAdapter(context: container.mainContext)
        let settingsRepository = UserDefaultsSnoozeSettingsRepository()
        let scheduler = LocalNotificationAlarmScheduler()
        let watchSession = LiveWatchSessionCoordinator()
        let permissions = LivePermissionService()

        _viewModel = StateObject(
            wrappedValue: AlarmListViewModel(
                repository: repository,
                settingsRepository: settingsRepository,
                scheduler: scheduler,
                watchSession: watchSession,
                permissionService: permissions
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AlarmListView(viewModel: viewModel)
        }
    }
}
