# SmartSleepAlarm MVP (iOS + watchOS)

本仓库已按 MVP 需求完成核心代码骨架与主链路实现，覆盖：
- iOS 闹铃管理（CRUD、重复、智能开关、贪睡分钟）
- 提前 30 分钟预热指令下发（watch 端）
- watch 端智能状态机（3 秒确认、5 分钟防再睡、重响）
- 快速翻腕手势触发贪睡
- WatchConnectivity 消息契约
- 传感器异常降级为持续响铃（防漏叫）

## 目录结构
- `Sources/SmartSleepDomain`: 领域模型、闹铃时间计算、状态机、睡眠信号推断
- `Sources/SmartSleepShared`: iOS/watchOS 共享消息模型与编解码
- `Sources/SmartSleepInfra`: 权限、通知、WC 通信、传感器、后台会话
- `Sources/SmartSleepiOS`: iOS UI + ViewModel + 持久化仓储
- `Sources/SmartSleepWatch`: watchOS UI + 运行时编排
- `Tests`: 领域与共享层测试（XCTest）

## 已实现的关键类型
- `Alarm`, `SmartRuntimeConfig`, `RuntimeState`, `DegradeReason`
- `AlarmPlanSync`, `PrewarmCommand`, `RingEvent`, `AwakeDecision`, `SnoozeGestureEvent`, `DegradeEvent`
- `SmartAlarmEngine`, `HeuristicSleepSignalAnalyzer`, `CoreMotionFlipDetector`
- `AlarmListViewModel`, `WatchAlarmRuntimeOrchestrator`

## 构建状态
- `swift build`：通过
- `swift test`：当前命令行工具链缺失 `XCTest` 模块，无法在此环境执行

## 重要说明（与计划差异）
- 需求中指定 `SwiftData`。当前命令行 SwiftPM 环境无法加载 `SwiftData @Model` 宏插件（`SwiftDataMacros`），因此仓储层使用了文件持久化实现 `FileAlarmRepository`。
- 接入 Xcode App 工程后，可将 `Sources/SmartSleepiOS/Data/AlarmRecord.swift` 和 `Repositories/AlarmRepository.swift` 替换为 SwiftData 版本（接口保持 `AlarmRepository` 不变）。

## 在 Xcode 中落地为真机 App 的建议步骤
1. 新建 iOS App + watchOS App for iOS App 工程（iOS 17+/watchOS 10+）。
2. 将本仓库 `Sources` 目录按模块拖入工程，并为 iOS/watch target 配置对应文件归属。
3. 开启能力与权限：
   - iOS: Notifications
   - watchOS: HealthKit, Background Modes（按需）
   - 两端: WatchConnectivity
4. `Info.plist` 增加权限文案（HealthKit/通知）。
5. 以真机联调流程验证：
   - 新建闹铃 -> 下发计划
   - 预热 -> 响铃
   - 清醒确认 3 秒后静音
   - 5 分钟防再睡重响
   - 翻腕手势贪睡 X 分钟后重响

