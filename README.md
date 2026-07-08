```When Editing
本文档作用: 工程总览 (价值主张 / 使用 / 安装 / 更新); MUST NOT 写发布流程 (→ workflow.md) / LLM 约束 (→ AGENTS.md) / 项目结构
遵循 AGENTS.md 文档编写规范
- 章节按需增删, 只留项目真有的; 首行一行价值主张, MUST NOT 带 LLM 提示
- 面向使用者: 正文 MUST NOT 出现 LLM 约束词 (MUST/NEVER 等); 可执行步骤 fenced + `#` 注释同行
- NEVER 写「开发」段 (VibeCoding 不向人类解释 dev 命令)
```

# JJ-DEV-MTL

面向开发者的 macOS 原生小工具集 (JSON 格式化 / 文本转义 / 编解码 · Token / ...), Swift + AppKit, 启动即用.

类似产品: [DevToys](https://devtoys.app/).

## 使用

- 顶部 tab 切换工具, 标签前的数字即快捷键 (非输入态按 `1`-`8` 直切)
- 键盘优先: 无 Copy/Paste 按钮, 结果可直接选中 `⌘C`; 打开时输入为空则自动填入剪贴板
- 输入/结果为可拖拽分栏 (拖动调比例, 双击复位), 右上角按钮切上下/左右布局
- 输入按工具本地保存, 切换标签或重开都不丢失

## 安装

不上架 App Store, 通过 GitHub Releases 分发 (ad-hoc 签名, 非公证).

一行命令 (拉最新 → 装入 `/Applications` → 清 quarantine):

```bash
curl -fsSL https://raw.githubusercontent.com/yigegongjiang/jj-dev-mtl/main/install.sh | bash
```

亦可 [Releases](https://github.com/yigegongjiang/jj-dev-mtl/releases) 直接下载 `JJ-DEV-MTL-macos.zip` 手动解压拖入 `/Applications`, 首次启动前:

```bash
xattr -dr com.apple.quarantine /Applications/JJ-DEV-MTL.app
```

## 更新

App 内建更新检测: 菜单栏 → Check for Updates…, 自动比对最新版本, 确认后下载替换并重启.

## 架构

Swift + AppKit (Cocoa), macOS 15.6+.
