# 上游登录态唤醒续期设计

## 背景

八阿哥的 access token 约 24 小时过期。2026-07-11 的现场时间线显示：

- 电脑在 token 过期期间处于深度睡眠。
- 系统 18:18 完整唤醒，但 CCHBar 没有立即刷新上游登录态。
- 用户 18:27 手动刷新后，现有 refresh Cookie 成功换取了新的 24 小时 token。

这证明 Cookie 刷新协议已经可用，剩余问题是唤醒路径没有主动执行上游续期。
当前 `observeSystemWake()` 只刷新主数据、恢复 mini probe，并运行到期的倍率自动同步；
如果倍率同步尚未到期，上游登录态不会被检查。

## 目标

- 电脑睡眠跨过 access token 到期时间后，唤醒时自动续期上游登录态。
- 等待网络恢复后再请求，避免刚唤醒时的瞬时网络失败。
- 合并 `didWakeNotification` 与 `screensDidWakeNotification`，同一轮唤醒只刷新一次。
- 只刷新上游余额/登录态，不执行更重的完整 key 与倍率扫描。
- 保持现有手动刷新、定时余额刷新和倍率自动同步行为不变。

## 方案

### 1. 可测试的唤醒协调器

新增 `CCHUpstreamWakeRefreshCoordinator`，只管理三个状态转换：

- 收到系统唤醒：记录有待处理刷新；网络已就绪且尚未安排任务时，返回“应安排”。
- 网络从未就绪变为就绪：如果有待处理刷新且尚未安排，返回“应安排”。
- 刷新任务完成：清除已安排状态，使下一次真实唤醒可以再次执行。

协调器不访问网络、不持有 `Task`，因此可以用独立 Swift 测试覆盖离线唤醒、网络恢复、
在线唤醒和重复通知。

### 2. MonitorState 接线

`MonitorState` 新增协调器状态和一个 `Task<Void, Never>?`：

- `didWakeNotification` 或 `screensDidWakeNotification` 到达时，先执行现有 `refresh()`，
  再通知协调器系统已唤醒。
- 复用现有 `NWPathMonitor` 的 `providerMiniProbeNetworkStatus`；网络恢复事件同时通知协调器。
- 协调器要求安排时，创建一个主 actor 任务，沿用现有 mini probe 的 1.2 秒网络稳定等待，
  然后调用 `refreshUpstreamBalances(silent: true)`。
- 任务结束后通知协调器完成并清空任务引用。
- `deinit` 取消该任务。

### 3. 为什么只刷新余额

`refreshUpstreamBalances` 已经遍历所有已保存的 Sub2API/new-api credential。
对过期的 Sub2API token，它会先调用 refresh 接口、保存轮换后的 Cookie/token，
再读取余额并将站点恢复为 available。它不需要扫描所有 key 和倍率，适合系统唤醒路径。

### 4. 错误处理

- 网络未就绪时不发请求，也不改变登录状态。
- 网络就绪后的请求若是超时或 5xx，现有余额刷新逻辑保留旧 credential 和 snapshot。
- 只有上游明确返回认证失效时才标记 `authExpired`。
- 本设计不增加循环重试；下一次网络恢复、小时余额刷新或手动刷新仍可再次尝试。

## 测试

新增独立协调器测试，先验证失败再实现：

1. 离线唤醒不安排任务，但保留 pending。
2. pending 状态下网络恢复只安排一次。
3. 在线唤醒立即安排一次。
4. 已安排期间的重复 wake/network 通知不重复安排。
5. 完成后下一次新唤醒可以再次安排。

随后运行现有 Sub2API Cookie、Cloudflare、stale snapshot 和 Node rate-watch 测试，
执行 Release 构建，安装到 `/Applications` 并重启确认唯一运行进程。

## 不做的事

- 不改变 refresh token/Cookie 协议。
- 不在睡眠期间运行定时器。
- 不在唤醒时强制执行完整上游倍率扫描。
- 不新增用户设置或界面状态。
