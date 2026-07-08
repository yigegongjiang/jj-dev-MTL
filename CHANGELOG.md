```When Editing
本文档作用: 面向使用者的发版记录; 只写用户感受得到的变化, MUST NOT 写技术细节 (→ CHANGELOG.dev.md)
遵循 AGENTS.md 文档编写规范
- 写: 新功能 / 行为修复 / 体验 / 安全 / 命令迁移
- MUST NOT 写: 文件路径 / 函数名 / 组件名 / 依赖包名 / 重构细节
- 单条 ≤ 2 行, 单版本 ≤ 5 条; 段落: Added / Changed / Fixed / Removed / Security
- 无用户可感知变化 → 占位: `跟随版本同步发布`
```

# Changelog

[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) + [SemVer](https://semver.org/).

## [0.1.1] - 2026-07-08

### Added

- 三个文本工具: Format JSON (含嵌套 JSON 字符串自动解包 + 转义兜底) / Multiline → Singleline (转义) / Singleline → Multiline (反转义), 输入即时预览 + 复制 / 粘贴到当前 App.

### Changed

- Format JSON 输出键按字典序排序 (更利于 diff 对比); 斜杠不再被转义为 `\/`.

## [0.1.0] - 2026-07-08

### Added

- 初始化工程骨架 (macOS AppKit 应用).
- 主窗口 UI 骨架: 左侧工具列表 + 右侧工具内容占位, 参考 DevToys 布局; `⌘S` 折叠 / 展开左侧列表.
- 提供 `install.sh` 一行命令安装 (下载 → 校验 → 装入 `/Applications`).
- Help 菜单 → Check for Updates… : 检测新版, 自动下载 + 替换 + 重启.

[0.1.1]: https://github.com/yigegongjiang/jj-dev-mtl/releases/tag/v0.1.1
[0.1.0]: https://github.com/yigegongjiang/jj-dev-mtl/releases/tag/v0.1.0
