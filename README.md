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
- 渠道页支持分组筛选、渠道分组分配、启用/停用、测速、熔断重置。
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
