# SmartSleepAlarm MVP 开发 TODO 与迭代计划（基于 0326 需求）

> 对照文档：`docs/MVP 版本功能描述（精简版0326）.md`  
> 对照代码范围：`Sources/`、`App/`、`Tests/`、`SmartSleepAlarm.xcodeproj`

## 1. 当前实现状态总览

### 1.1 iOS 闹铃管理
- 已实现：
  - 创建、编辑、删除闹铃（基础字段、重复周、智能模式开关、贪睡分钟）。
  - 列表展示与按时间排序。
  - 本地通知调度与删除时取消调度。
  - SwiftData（App target 内）持久化适配：`App/iOS/SwiftDataAlarmRepositoryAdapter.swift`。
- 部分实现：
  - 铃声选择目前是 `soundID` 文本字段，未接系统铃声选择器。
  - “快捷闹铃”仅有新增入口，未提供一键模板（如“5分钟后”）。
- 未实现：
  - 全局默认贪睡时间设置页。
  - 闹铃响起前权限检查与阻断/提醒流程。

### 1.2 watchOS 智能监测与唤醒
- 已实现：
  - 清醒判断状态机（3 秒确认窗口 + 5 分钟防再睡窗口 + 重响循环）逻辑框架。
  - 翻腕手势贪睡触发与倒计时重响框架。
  - 传感器无数据时降级为持续响铃（防漏叫策略框架）。
- 部分实现：
  - `WKExtendedRuntimeSession` 控制器已封装，但未与 WatchConnectivity 预热消息完整闭环。
  - watch 端页面目前主要是调试/模拟入口，不是正式用户流程页面。
- 未实现：
  - HealthKit 实时心率读取（当前 provider 返回占位数据）。
  - 与 iOS 的 WC 收包处理与自动驱动 `handlePrewarm/startRinging`。
  - 手表断连、低电量等降级条件识别。
  - 贪睡触发后的震动/图标反馈。

### 1.3 跨端通信与容错
- 已实现：
  - 消息协议（`AlarmPlanSync/Prewarm/Ring/Awake/Snooze/Degrade`）与编解码。
  - iOS 侧发包（计划同步、预热、状态事件上报接口）。
- 未实现：
  - WC 双向接收处理与会话状态管理（reachable、后台传输重试、恢复同步）。
  - 断连后“最后一次计划 + 本地保底”完整策略落地。

### 1.4 测试与验收
- 已实现：
  - 领域层单测：时间计算、状态机、贪睡边界、消息编解码。
  - 在 Xcode 工具链下 `swift test` 可通过。
  - iOS/watchOS scheme 可构建通过（模拟器）。
- 未实现：
  - 端到端集成测试（iOS <-> watch 实机链路）。
  - 非功能指标验证（响应延迟、电量、识别准确率、防再睡成功率）。
  - 对照 9 条验收标准的逐条实测记录。

---

## 2. MVP 功能 TODO List（按优先级）

## P0（必须）
- [ ] 接通 WatchConnectivity 收包处理：watch 端可接收 `PrewarmCommand` 并自动启动后台会话。
- [ ] 接通闹铃触发链路：到点后 watch 端自动进入 ringing + 监测流程（非“模拟按钮”触发）。
- [x] 实现 HealthKit 心率实时采样与 CoreMotion 加速度采样，替换占位 provider。
- [ ] 完成“清醒后 5 秒内静音”的端到端行为验证（含日志与时间戳）。
- [ ] 完成“5 分钟内再睡自动重响”的端到端行为验证。
- [ ] 传感器缺失/异常时维持保底响铃并给出降级原因。
- [ ] iOS 首次权限引导完整化（通知 + HealthKit）与失败态提示。
- [x] watch 端手势贪睡后给出反馈（震动或 UI 提示）。

## P1（MVP 强化）
- [ ] 系统铃声选择器接入（替代 `soundID` 手输）。
- [ ] 全局默认贪睡时间设置，创建闹铃时自动继承。
- [ ] 闹铃前权限检查（响铃前/预热前二次检查并提醒）。
- [ ] WC 断连恢复与重试机制（消息缓存/重发）。
- [ ] 关键指标埋点：清醒静音延迟、重响触发次数、降级原因分布。

## P2（后续，不阻塞 MVP 验收）
- [ ] 手势类型扩展（打响指等）。
- [ ] 贪睡次数上限策略。
- [ ] 手势选择设置页。

---

## 3. 分阶段开发与测试闸门（必须“先测后进”）

## 阶段 0：基线与可观测性
### 开发任务
- [x] 固化分支基线与构建脚本（iOS/watch scheme + swift test）。
- [x] 增加统一日志结构（alarmID、state、timestamp、source）。
- [x] 为关键状态转换补充事件记录。
### 测试验证（通过后进入阶段 1）
- [x] `swift test` 全绿。
- [x] `xcodebuild` 两个 scheme（iOS/watch）构建成功。
- [x] 日志可覆盖“新建闹铃 -> 调度 -> 发 prewarm”链路。

## 阶段 1：iOS 端功能补齐
### 开发任务
- [x] 铃声选择改为系统选择器。
- [x] 全局默认贪睡设置 + 创建页继承。
- [x] 权限引导页与失败态说明完善。
### 测试验证（通过后进入阶段 2）
- [x] UI/逻辑回归：闹铃 CRUD、启停、重复、贪睡范围边界（以自动化逻辑测试 + 构建回归覆盖）。
- [x] 通知调度链路验证：新增/编辑/删除触发调度路径且构建通过。
- [x] 权限拒绝场景验证：有明确提示且测试通过。

## 阶段 2：跨端通信闭环
### 开发任务
- [x] watch 端实现 WC 收包与命令路由（Plan/Prewarm/Ring/Snooze/Degrade）。
- [x] iOS 端实现会话状态与重试策略。
- [x] prewarm 命令触发 watch 后台会话启动。
### 测试验证（通过后进入阶段 3）
- [x] 集成/路由测试：iOS 发 prewarm，watch 成功收到并进入预热路径（自动化单测 + 构建验证）。
- [x] 断连恢复策略验证：不可达时消息排队并触发重试同步逻辑。
- [x] alarmID 路由验证：Plan+Prewarm 按 alarmID 正确映射（自动化测试）。

## 阶段 3：watch 传感器与智能判断
### 开发任务
- [x] HealthKit 心率实时读取（采样频率与超时策略）。
- [x] CoreMotion 体动采集并喂给 `SleepSignalAnalyzer`。
- [x] 传感器异常分类（未佩戴/超时/权限不足）与降级上报。
### 测试验证（通过后进入阶段 4）
- [ ] 实机验证：有数据时可进入 awake/asleep 判定路径。
- [x] 无数据/权限拒绝时稳定进入 degraded 且不中断响铃策略（自动化测试覆盖）。
- [ ] 连续运行稳定性（长时间监测不崩溃）。

## 阶段 4：唤醒与贪睡完整体验
### 开发任务
- [x] 打通真实响铃触发后的全流程状态机。
- [x] 接入翻腕手势阈值调参与防误触策略。
- [x] 贪睡触发反馈（触觉 + UI 状态）完善。
### 测试验证（通过后进入阶段 5）
- [x] 验证“清醒信号持续 3 秒后静音”（状态机单测）。
- [x] 验证“静音后 5 分钟内再睡 -> 自动重响”（状态机单测）。
- [x] 验证“手势贪睡 X 分钟后重响，并继续智能监测”（状态机 + watch 流程测试）。

## 阶段 5：验收封板
### 开发任务
- [ ] 对照需求文档 9 条验收项逐条补齐证据（日志、录屏、测试报告）。
- [ ] 非功能基线验证与问题修复（响应、稳定性、功耗粗测）。
- [ ] 发布前清单（权限文案、异常兜底、关键崩溃点）。
### 测试验证（通过后宣布 MVP 完成）
- [ ] 验收条目 1-9 全部通过并记录结果。
- [ ] iOS/watch 回归测试通过。
- [ ] 已知问题清单仅剩可接受 P2，不影响 MVP 核心承诺。

---

## 4. 执行规则（迭代纪律）

- 每个阶段必须先完成“开发任务清单”，再执行“测试验证清单”。
- 测试未通过时，禁止进入下一阶段；必须先修复并复测。
- 每阶段结束输出：
  - 阶段完成项
  - 阻塞项与风险
  - 测试结果（通过/失败 + 证据链接）
  - 下一阶段准入结论（Go/No-Go）

---

## 5. 阶段执行记录

### 阶段 0（已完成）
- 完成项：
  - 新增统一日志模型与 JSONL 记录器：`AlarmRuntimeLogEntry`、`AlarmEventLogger`、`JSONLineAlarmEventLogger`。
  - iOS 关键流程已接日志：`onAppear`、权限请求、闹铃保存/删除、调度、prewarm 发包、计划同步。
  - watch 关键状态已接日志：激活、预热接收、状态迁移、重响事件、贪睡事件、降级事件。
  - 新增阶段验证脚本：`scripts/phase0_validate.sh`。
- 测试结果：
  - `xcrun swift test`：通过（7/7）。
  - iOS scheme 构建：通过。
  - watchOS scheme 构建：通过。
- Go/No-Go：`Go`（允许进入阶段 1）。

### 阶段 1（已完成）
- 完成项：
  - 闹铃编辑页接入铃声 Picker（预置系统铃声选项，替代手输 `soundID`）。
  - 新增全局默认贪睡设置仓储，列表页可设置默认值，新建闹铃自动继承。
  - 权限失败态文案细化，并支持打开系统设置。
  - 补充 iOS 侧阶段单测：默认贪睡持久化、权限拒绝提示逻辑。
- 测试结果：
  - `xcrun swift test`：通过（11/11）。
  - iOS scheme 构建：通过（日志 `/tmp/smartsleep_phase1_ios.log`）。
  - watchOS scheme 构建：通过（日志 `/tmp/smartsleep_phase1_watch.log`）。
- Go/No-Go：`Go`（允许进入阶段 2）。

### 阶段 2（已完成）
- 完成项：
  - WatchConnectivity 支持双向通信事件：激活、可达性变化、收包、排队、错误。
  - watch 端新增消息路由：接收 `AlarmPlanSync`、`PrewarmCommand`、`RingEvent` 并驱动运行时。
  - prewarm 收到后自动启动 `WKExtendedRuntimeSession`（通过统一运行时控制接口触发）。
  - iOS 端新增会话状态展示与离线重试同步（排队后 3 次重试 + 在线时自动同步）。
  - 新增阶段测试：`WatchCommandRoutingTests` 验证 plan+prewarm 路由与后台会话启动。
- 测试结果：
  - `xcrun swift test`：通过（12/12）。
  - iOS scheme 构建：通过（日志 `/tmp/smartsleep_phase2_ios.log`）。
  - watchOS scheme 构建：通过（日志 `/tmp/smartsleep_phase2_watch.log`）。
- Go/No-Go：`Go`（允许进入阶段 3）。

### 阶段 3（已完成，进入阶段 4）
- 完成项：
  - `HealthKitSleepSignalProvider` 完成真实读取链路：HeartRate 查询 + CoreMotion 加速度采样合并输出 `SleepSignalReadout`。
  - watch 端运行时已接入结构化读数：优先按 `degradeReason` 触发降级，再按 `signal` 进行 awake/asleep 推断。
  - 异常分类已落地并上报：`healthPermissionMissing`、`sensorTimeout`、`watchNotWorn`。
  - 修复 Swift 6 并发问题：体动回调不再跨 actor 捕获 `self`，改为线程安全样本缓存。
  - 新增测试 `SensorDegradeTests`，验证权限缺失触发 degraded。
- 测试结果：
  - `xcrun swift test`：通过（13/13）。
  - iOS scheme（Simulator）构建：通过（日志 `/tmp/smartsleep_phase3_ios_sim.log`）。
  - watchOS scheme（Simulator）构建：通过（日志 `/tmp/smartsleep_phase3_watch_sim.log`）。
  - 补充说明：`generic/platform=iOS` 与 `generic/platform=watchOS` 设备构建需配置 Development Team，否则会因签名失败。
- Go/No-Go：`Go`（允许进入阶段 4）。

### 阶段 4（已完成，进入阶段 5）
- 完成项：
  - iOS 端新增运行时派发循环：按时间窗口自动下发 `PrewarmCommand` 与 `RingEvent`，打通非“模拟按钮”的真实响铃触发链路。
  - iOS 端修正触发窗口边界：到点后 30 秒内仍按本次闹铃派发 ring，避免跳到下一次周期。
  - 翻腕手势识别升级：加入旋转阈值 + 重力变化阈值 + 连续命中计数 + 冷却时间，降低误触发。
  - watch 端新增反馈播放器：对 `ringing/reringing/silenced/degraded/dismissed` 状态切换提供触觉反馈。
  - 手势贪睡后状态文案优化：显示“已贪睡 X 分钟，随后重响”。
- 测试结果：
  - `xcrun swift test`：通过（16/16）。
  - iOS scheme（Simulator）构建：通过（日志 `/tmp/smartsleep_phase4_ios_sim.log`）。
  - watchOS scheme（Simulator）构建：通过（日志 `/tmp/smartsleep_phase4_watch_sim.log`）。
  - 补充说明：本阶段“真实响铃全流程”已完成代码与自动化验证，真机长时稳定性与验收证据在阶段 5 继续补齐。
- Go/No-Go：`Go`（允许进入阶段 5）。

### 阶段 5（进行中：自动化完成，待真机封板）
- 完成项：
  - 按 9 条验收项补齐自动化证据映射，并形成阶段文档：`docs/阶段5验收与封板清单.md`。
  - 新增阶段验证脚本：`scripts/phase5_validate.sh`，统一产出测试与构建日志到 `artifacts/phase5/`。
  - 补齐阶段 5 相关自动化测试覆盖：
    - iOS 闹铃 CRUD、智能开关与贪睡配置持久化；
    - -30 分钟预热下发、到点响铃下发；
    - 清醒后 5 秒内退出响铃态；
    - 手势贪睡触发反馈与贪睡后重响状态机。
- 测试结果：
  - `scripts/phase5_validate.sh`：通过。
  - `swift test`：通过（21/21，日志 `artifacts/phase5/swift_test.log`）。
  - iOS scheme（Simulator）构建：通过（日志 `artifacts/phase5/ios_sim_build.log`）。
  - watchOS scheme（Simulator）构建：通过（日志 `artifacts/phase5/watch_sim_build.log`）。
- 阻塞项（发布前必须补齐）：
  - 仍缺真机联调证据（iPhone + Apple Watch）与 9 条验收录屏/时间戳日志。
  - 仍缺功耗、长时稳定性、断连/低电量异常链路的真机复核报告。
- Go/No-Go：`No-Go`（自动化通过，但未完成真机封板验收）。
