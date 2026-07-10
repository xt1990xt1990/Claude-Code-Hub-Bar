# Sub2API Cookie 登录态自动续期设计

## 背景

`ageteam.online` 的 access token 约 24 小时过期。它的网页端通过
`POST /api/v1/auth/refresh` 自动续期，请求体固定为 `{}`，refresh token
由 `sub2api_refresh_token` Cookie 提供。

CCHBar 目前会同时保存独立的 `sub2RefreshToken` 字段和浏览器 Cookie。
重新获取登录态时，新 Cookie 可能与钥匙串中的旧字段并存；后续续期若把旧字段放进请求体，
就会与新 Cookie 冲突并导致续期失败。刷新响应若轮换 Cookie，而 CCHBar 没有持久化新值，
下一次续期也会再次使用旧 Cookie。

## 目标

- Cookie-only Sub2API 站点在 access token 到期前可以自动续期。
- `sub2api_refresh_token` Cookie 存在时，以它作为 refresh token 的权威来源。
- 保存刷新响应轮换后的 Cookie，避免下一轮续期使用旧值。
- 不改变仅支持请求体 refresh token 的其他 Sub2API 站点行为。
- 不按域名硬编码 `ageteam.online`，让相同协议的站点共用修复。

## 方案

### 1. 浏览器登录态导入

从 Chrome 读取到 `sub2api_refresh_token` Cookie 时：

- 保存完整 Cookie header，继续保留 `cf_clearance` 等同域 Cookie。
- 用 Cookie 中的 refresh token 覆盖 `sub2RefreshToken`，消除钥匙串旧值。
- 重新获取 Sub2API 登录态前删除共享 Chrome profile 中同域的旧 refresh Cookie，
  防止导入流程把过期 Cookie 当作新登录结果。
- 若已有 access token 缺失到期时间或将在 5 分钟内过期，立即走一次真实刷新校验，
  不把无法续期的状态保存为成功。

### 2. 自动续期请求

- 存在非空 `sub2api_refresh_token` Cookie 时，发送 Cookie 和浏览器 User-Agent，
  请求体使用 `{}`，与站点网页行为一致。
- 不存在该 Cookie 时，保持现有请求体
  `{ "refresh_token": "..." }` 方式。
- 不在一次续期中自动尝试两种方式。refresh token 可能是单次轮换凭据，盲目重试会让状态更难判断。

### 3. Cookie 轮换持久化

刷新成功后检查响应中的 `Set-Cookie`：

- 使用 Foundation 的 Cookie 解析能力处理属性和编码，不手写拆分 `Set-Cookie`。
- 仅合并当前上游域名返回的 Cookie。
- 新的 `sub2api_refresh_token` 同时更新完整 Cookie header 和
  `sub2RefreshToken` 镜像字段。
- 响应没有设置新 Cookie 时保留原值。
- 更新后的 credential 继续走现有钥匙串保存路径。

### 4. 错误处理

- refresh 返回明确的 401、403 或 invalid refresh token 时，维持现有
  `authExpired` 状态和“重新获取”入口。
- Cloudflare challenge 继续按网络拦截处理，不误判为登录失效。
- 网络超时或 5xx 不清空 credential，避免暂时故障变成永久掉登录态。

## 测试

先增加失败回归测试，再修改生产代码：

1. 新 Cookie 覆盖 credential 中的旧 refresh token。
2. Cookie-only 刷新发送 Cookie、User-Agent 和空 JSON 请求体。
3. 刷新响应轮换 `sub2api_refresh_token` 后，返回的 credential 保存新 Cookie 和镜像字段。
4. 没有 refresh Cookie 的 Sub2API 仍在请求体发送 refresh token。
5. 运行现有 Cloudflare、浏览器导入和 stale snapshot 测试。
6. 执行完整 Debug 构建，确认 app target 编译通过。

## 不做的事

- 不硬编码站点域名。
- 不改变 new-api 登录态处理。
- 不改变钥匙串数据结构或迁移旧数据；下一次浏览器导入或成功刷新会自然校正旧字段。
- 不增加后台重试策略或新的设置项。

## 风险与控制

- `Set-Cookie` 可能包含多个 Cookie 和复杂属性。使用系统解析器并用轮换测试覆盖。
- 共享 Chrome profile 可能保留旧登录态。只删除目标域的
  `sub2api_refresh_token`，不清理其他站点或其他 Cookie。
- 部分 Sub2API 变体同时支持 Cookie 和请求体。只要存在专用 refresh Cookie，
  按浏览器协议优先使用 Cookie；没有该 Cookie 时保持原行为。
