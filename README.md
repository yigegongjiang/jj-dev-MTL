```When Editing
本文档作用: 工程总览 (价值主张 / 使用 / 架构 / 结构); MUST NOT 写发布流程 (→ workflow.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 文档编写规范
- 章节按需增删, 只留项目真有的; 首行一行价值主张, MUST NOT 带 LLM 提示
- 短并列项用表格; 可执行步骤 fenced + `#` 注释同行
- NEVER 写「开发」段 (VibeCoding 不向人类解释 dev 命令)
```

# JJ-DEV-MTL

面向开发者的 macOS 原生小工具集 (JSON 格式化 / 文本处理 / ...), Swift + AppKit, 启动即用.

类似产品: [DevToys](https://devtoys.app/).

## 安装

本工具 NEVER 上架 App Store, 通过 GitHub Releases 分发 (ad-hoc 签名, 非公证).

一行命令 (拉最新 → 装入 `/Applications` → 清 quarantine):

```bash
curl -fsSL https://raw.githubusercontent.com/yigegongjiang/jj-dev-mtl/main/install.sh | bash
```

亦可 [Releases](https://github.com/yigegongjiang/jj-dev-mtl/releases) 直接下载 `JJ-DEV-MTL-macos.zip` 手动解压拖入 `/Applications`, 首次启动前:

```bash
xattr -dr com.apple.quarantine /Applications/JJ-DEV-MTL.app
```

## 更新

App 内建更新: 对比本机 `MARKETING_VERSION` vs `https://api.github.com/repos/yigegongjiang/jj-dev-mtl/releases/latest` 的 `tag_name`; 无 CLI, MUST NOT 依赖 `install.sh` 常驻.

## 架构

Swift + AppKit (Cocoa), macOS 15.6+.

## 项目结构

- `JJ-DEV-MTL/` — 源码 (AppDelegate / ViewController / Assets / Base.lproj)
- `.github/workflows/release.yml` — tag `v*` 触发, `macos-latest` 出通用二进制 + ad-hoc 签名 + zip + SHA256 → GitHub Release
- `install.sh` — 终端用户下载 + 校验 + 本机安装
