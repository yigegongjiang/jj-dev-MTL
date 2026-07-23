```When Editing
本文档作用: 工程工作流程 (可用工具 / 调试 / 发布); MUST NOT 写工程说明 (→ README.md) / LLM 约束 (→ AGENTS.md)
遵循 AGENTS.md 文档编写规范
- 所有段落均为条件段, 根据工程实际决定保留或删除; 存在即为明确流程, MUST NOT 附加强度标记
- 发布内按顺序编号步骤; 顶部 TL;DR ≤ 5 行; 删除子段后重编号保持连续
- 风险点 / 不可逆操作用 `>` 引用块; 高危操作 MUST 标禁用条件
```

# 可用工具

- `gh` 已登录
- `xcodebuild` (Xcode CLI) 本机可用

# 调试

AI 完成 build + launch, app 启动后交人类肉眼验证 UI / 行为.

```bash
xcodebuild -project jj-dev-MTL.xcodeproj -scheme jj-dev-MTL -configuration Debug -derivedDataPath build build       # 编译
open build/Build/Products/Debug/jj-dev-MTL-dev.app                                                                  # 启动
```

# 发布

代码变更完成后立即执行 (= 需求交付的最后环节). CI 已接入 (`.github/workflows/release.yml`): push tag `v*` → GHA 自动构建 `.app` + ad-hoc 签名 + zip + SHA256 → 生成 GitHub Release.

## TL;DR

依序执行:

1. 验证: `xcodebuild ... -configuration Release build`
2. 写版本: `Version.xcconfig` (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`) + `CHANGELOG.md` + `CHANGELOG.dev.md` 同步
3. 发布: commit + annotated tag (`-a -m`) + push branch + tag → 等 GHA 绿灯 → `pkill` 旧 app + `bash install.sh` + `open` → 交人类肉眼验证
4. 修上版 bug: amend + 删远程 tag + 重打 + force push (自动重跑 GHA 覆盖 release → 重跑本机安装启动)

## 1. 验证

```bash
xcodebuild -project jj-dev-MTL.xcodeproj -target jj-dev-MTL -configuration Release clean build   # Release 编译零警告零错误
```

## 2. 写版本

- 版本号: 默认递增 PATCH (第三位); 新功能 → MINOR; 不兼容改动 → MAJOR
- 版本源: `Version.xcconfig` (xcconfig 唯一源, project.pbxproj 通过 `baseConfigurationReference` 引入); MUST NOT 再手改 pbxproj
- 同步编辑 (MUST 全同步, GHA 有 tag ↔ `MARKETING_VERSION` 校验, 不一致直接 fail):
  - `Version.xcconfig` → `MARKETING_VERSION = X.Y.Z`
  - `Version.xcconfig` → `CURRENT_PROJECT_VERSION` 单调递增
  - `CHANGELOG.md` + `CHANGELOG.dev.md` → 追加 `## [X.Y.Z] - YYYY-MM-DD`

## 3. 发布

push tag 触发 GHA; AI 监听 GHA 完成 → 自动跑 `install.sh` 拉最新 app 装本机 → 启动 → 交人类肉眼验证 UI / 行为.

```bash
git add -A
git commit -m "release: vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main
git push origin vX.Y.Z                    # 触发 .github/workflows/release.yml
gh run watch --exit-status                 # 等 GHA 结束; 失败即返读日志修复

pkill -x jj-dev-MTL 2>/dev/null || true   # 杀掉本机运行中的旧版本 (未运行则忽略)
bash install.sh                            # 从 latest release 拉取 + 校验 SHA256 + 装 /Applications
open /Applications/jj-dev-MTL.app          # 启动, 交人类肉眼验证
```

## 4. 修上版 bug

上版存在明显 bug 时, amend 修复后重新发布.

> `--force-with-lease` 仅在确认无他人协作时使用; 本工程为 AI-only 单人仓库, 安全.

```bash
git commit --amend --no-edit
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main --force-with-lease
git push origin vX.Y.Z                    # 触发 GHA 重跑, 覆盖同名 release
gh run watch --exit-status

pkill -x jj-dev-MTL 2>/dev/null || true
bash install.sh
open /Applications/jj-dev-MTL.app
```
