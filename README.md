# Claude Code Hub Bar

一个非官方的 macOS 菜单栏客户端，用来配合 [Claude Code Hub](https://github.com/ding113/claude-code-hub) 使用。

它会把今日用量、运行中的请求、日志、排行和渠道健康状态放进菜单栏，方便在本地快速查看当前状态。

## 使用

1. 打开应用。
2. 从菜单栏弹窗进入「设置」。
3. 填写你的 CCH 地址和 API Key。

所有私有配置都在本机填写，不应提交到仓库。

## 功能

- 菜单栏显示今日成本和请求概况。
- 有运行中请求时显示供应商、计费模型、倍率和运行时间。
- 支持多个运行中请求轮播。
- 菜单栏缓存指示条呼吸灯:绿色慢呼吸,红色快闪示警。
- 总览、排行、日志、渠道面板,带滑动胶囊切换动效。
- macOS 26 启用 Liquid Glass 半透明玻璃面板,旧系统回落 ultraThin 材质。
- 日志详情展示供应商决策链、TTFB、吞吐、缓存写入/读取。
- 排行和日志展示缓存命中率。
- 渠道页支持分组筛选、启用/停用、测速、熔断重置。
- 支持开机启动。

## 构建

```bash
xcodebuild -project CCHBar.xcodeproj -scheme CCHBar -configuration Release build
```

## 语言

- [English](./README.en.md)

## 致谢

- 致敬 [Claude Code Hub](https://github.com/ding113/claude-code-hub) 作者。
- 感谢 `mbot6183` 提供的 Codex 相关支持。
- 模型图标来自 [LobeHub Icons](https://github.com/lobehub/lobe-icons)。

## 许可证

MIT
