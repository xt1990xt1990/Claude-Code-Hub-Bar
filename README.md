# Claude Code Hub Bar

一个非官方的 macOS 菜单栏客户端，用来配合 [Claude Code Hub](https://github.com/ding113/claude-code-hub) 使用。

它会把今日用量、运行中的请求、日志、排行和渠道健康状态放进菜单栏，方便在本地快速查看当前状态。

## 下载

- 最新版本：[v1.2.2](https://github.com/xt1990xt1990/Claude-Code-Hub-Bar/releases/tag/v1.2.2)
- Apple Silicon：[CCHBar-v1.2.2-arm64.zip](https://github.com/xt1990xt1990/Claude-Code-Hub-Bar/releases/download/v1.2.2/CCHBar-v1.2.2-arm64.zip)

## 使用

1. 打开应用。
2. 从菜单栏弹窗进入「设置」。
3. 填写你的 CCH 地址和 API Key。

## 功能

- 菜单栏显示今日成本和请求概况。
- 状态栏空闲态显示今日成本和请求数，成本保留到小数点后三位。
- 有运行中请求时显示供应商、计费模型、倍率、运行时间和并发数量。
- 支持多个运行中请求轮播，状态栏最多轮播 3 个，避免高并发时跳动过多。
- 运行中请求面板最多展示 3 条，其余请求可在列表内滚动查看。
- 菜单栏缓存指示条呼吸灯:绿色慢呼吸,红色快闪示警。
- 最近请求、日志详情和运行中请求统一使用当前渠道配置倍率。
- 总览、排行、日志、渠道面板,带滑动胶囊切换动效。
- 面板右上角跳转入口提供按钮态和 hover 反馈。
- macOS 26 启用 Liquid Glass 半透明玻璃面板,旧系统回落 ultraThin 材质。
- 支持 Liquid Glass 和 Endless Dark 两套皮肤。
- 日志详情展示供应商决策链、TTFB、吞吐、缓存写入/读取。
- 排行和日志展示缓存命中率。
- 总览最近请求使用紧凑布局,长渠道名和长模型名会按可用空间自适应截断。
- 渠道页支持分组筛选、渠道分组分配、启用/停用、测速、熔断重置。
- 渠道页支持模型测试首字节和总延迟展示,便于区分连接等待和整体响应耗时。
- 支持 Mini 探针系统,可按渠道单独启用后台模型测试探针,自定义探针模型、频率、运行时段和平均首字节统计。
- Mini 探针设置页支持更紧凑的时段、频率和平均首字节控制。
- 上游倍率页支持按官网聚合 Sub2API / new-api 供应商,通过 key 后四位匹配本地渠道。
- 上游倍率页显示渠道分组,并复用渠道页的 Mini 探针开关、状态和历史数据。
- 支持从本机 Chrome 获取上游登录态,登录完成后自动保存,用于刷新倍率和余额。
- 支持手动或定时刷新上游倍率,勾选的渠道会自动同步倍率,未勾选的渠道保留手动控制。
- 支持上游余额读取和独立后台刷新,便于区分倍率刷新和余额刷新。
- 上游抽屉内复用渠道测试能力,可直接测试官网链路和模型可用性。
- 模型品牌识别支持 GLM,并减少 OpenAI 系列模型名的误判。
- 支持开机启动。

## 演示

- 状态栏 空闲-请求中
<img width="284" height="62" alt="Kapture 2026-05-30 at 14 17 56" src="https://github.com/user-attachments/assets/8e3baef7-782a-4caa-b8cf-5d7fe572f653" />

- 抽屉部分功能演示
<img width="1524" height="1328" alt="Kapture 2026-05-30 at 14 23 09" src="https://github.com/user-attachments/assets/8f198750-2728-492f-baa1-acfe7caca03b" />

## 构建

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Release build
```

## 语言

- [English](./README.en.md)

## 致谢

- 致敬 [Claude Code Hub](https://github.com/ding113/claude-code-hub) 作者 `ding113`。
- 感谢 `mbot6183` 提供的 Codex 相关支持。
- 模型图标来自 [LobeHub Icons](https://github.com/lobehub/lobe-icons)。

## 许可证

MIT

Copyright (c) 2026 xt1990xt1990

如果你复制、分发、修改或基于本项目进行二次开发，请保留原始版权声明、MIT 许可证文本和 [NOTICE](./NOTICE) 中的署名与致谢信息。
