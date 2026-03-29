import Foundation
import SmartSleepInfra

public enum AppBootstrap {
    @MainActor
    public static func makeAlarmListViewModel() -> AlarmListViewModel {
        let repository = FileAlarmRepository()
        let settingsRepository = UserDefaultsSnoozeSettingsRepository()
        let scheduler = LocalNotificationAlarmScheduler()
        let watchSession = LiveWatchSessionCoordinator()
        let permissionService = LivePermissionService()

        return AlarmListViewModel(
            repository: repository,
            settingsRepository: settingsRepository,
            scheduler: scheduler,
            watchSession: watchSession,
            permissionService: permissionService
        )
    }
}
