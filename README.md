# RightClick — macOS Finder 右键「新建文件」

一个轻量的 macOS Finder 右键菜单增强工具：在 Finder 右键菜单中加入「**新建文件**」子菜单，一键在当前文件夹创建以下空白文件：

- Word 文档（.docx）
- Excel 表格（.xlsx）
- PPT 演示（.pptx）
- 文本文档（.txt）
- Markdown（.md）
- XML（.xml）
- RTF（.rtf）

同目录重复创建会自动编号（新建 Word 文档.docx → 新建 Word 文档 2.docx → …）。

纯系统 API 实现（FinderSync + Swift），无第三方依赖；用 `swiftc` 手动编译，不需要 Xcode 工程。

## 工作原理

| 组件 | 说明 |
|---|---|
| `RightClick`（宿主 App） | 菜单栏常驻小程序，作为扩展的容器 |
| `RightClickFinder.appex`（Finder 同步扩展） | 实现 `FIFinderSync`，构建右键菜单、执行「新建文件」 |
| `build.sh` | `swiftc` 编译 → 打包 → `codesign` 签名 |

扩展监控用户主目录及其 Desktop / Downloads / Documents 子目录，在这些位置的 Finder 窗口里右键即可看到菜单。

## 环境要求

- macOS 12 或更高（在 macOS 15.5 上测试通过）
- 一个 **Apple Development 签名证书**（免费 Apple ID 即可获得，见下）
- 安装 Xcode（16.4 支持 macOS 15.x；具体版本按你的系统选择）

### 获取免费签名证书

Finder 同步扩展必须用 Apple 签发的证书签名，否则 `pluginkit` 会静默拒绝注册。免费方案：

1. 安装 Xcode，打开后进入 Settings → Accounts，登录你的 Apple ID（个人团队即可，无需付费）。
2. 终端确认证书存在：

   ```bash
   security find-identity -v -p codesigning
   ```

   能看到 `Apple Development: ...` 一行即可。

   若证书显示为「matching 但不是 valid」，通常是缺少 WWDR 中间证书，可安装 Xcode 内置的：
   `/Applications/Xcode.app/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/Resources/AppleWWDRCA-2030.cer`

## 构建

```bash
CODE_SIGN_IDENTITY="Apple Development: 你的名字 (你的TeamID)" bash build.sh
```

不传 `CODE_SIGN_IDENTITY` 时使用 ad-hoc 签名（仅能自测，系统不会注册该扩展）。

## 安装与启用

```bash
# 1. 部署
cp -R build/RightClick.app /Applications/

# 2. 注册并启用扩展
pluginkit -a /Applications/RightClick.app/Contents/PlugIns/RightClickFinder.appex
pluginkit -e use -i com.example.RightClick.FinderSync

# 3. 重启 Finder 加载
killall Finder
```

然后在 Finder 窗口中右键 →「新建文件」，选择类型即可在当前文件夹创建文件。

停用扩展：`pluginkit -e ignore -i com.example.RightClick.FinderSync`

## 权限（entitlements）说明

- **`com.apple.security.app-sandbox`**：必须为 `true`。现代 macOS 要求 Finder 同步扩展必须沙盒化，否则 `pluginkit` 拒绝注册。
- **`com.apple.security.temporary-exception.files.absolute-path.read-write`**：允许扩展在用户主目录内写文件。`build.sh` 会自动把模板中的 `__HOME__` 替换成当前用户的 `$HOME`，因此不需要手动改路径。注意：这是**本地自用**方案，Mac App Store 不接受该 entitlement。
- **不要添加 `com.apple.application-identifier`**：个人团队没有 provisioning profile，添加后宿主 App 会启动失败（`Launch failed Code=153`）。

## 常见问题（踩坑记录）

1. **扩展注册后不出现**：扩展未沙盒化会被 `pluginkit` 静默忽略——检查 `app-sandbox = true`。
2. **宿主 App 启动报 `Code=153`**：entitlements 中多余的 `application-identifier` 导致，删掉即可。
3. **右键菜单不弹出**：沙盒里 `FileManager` 返回的是容器路径（`~/Library/Containers/.../Data/...`），扩展会监控到不存在的目录。代码中已改用 `getpwuid()` 获取真实主目录。
4. **点击菜单没反应**：Finder 会把菜单通过 XPC 传给 Finder 进程显示，`NSMenuItem.representedObject` 无法跨进程传递，会丢失。代码中已改用 `NSMenuItem.tag` 标识菜单项。
5. **同一文件夹第二次创建失败**：自动编号函数拼接路径错误。已修复（在父目录下生成「原名 + 序号 + 扩展名」）。
6. **`codesign` 报 `resource fork, Finder information ... not allowed`**：Office 模板带扩展属性，构建脚本已通过 `xattr -cr` 清理。

## 文件结构

```
├── build.sh                        # 编译 + 签名 + 打包
├── FinderSync.entitlements.template # 扩展权限模板（__HOME__ 由构建脚本替换）
├── RightClick.entitlements          # 宿主 App 权限
├── Info-RightClick.plist            # 宿主 App 配置
├── Info-FinderSyncExt.plist         # 扩展配置（NSExtension 声明）
├── FinderSyncExt/
│   ├── FinderSync.swift             # 扩展核心：菜单构建 + 新建文件逻辑
│   └── main.m                       # 扩展入口（main → NSExtensionMain）
├── RightClick/
│   └── main.swift                   # 宿主 App 源码
├── Templates/                       # 7 个空白模板文件
└── export_templates.applescript     # 用 Pages/Numbers/Keynote 重新导出 Office 模板
```

## 重新生成 Office 模板

`Templates/` 中的 Word/Excel/PPT 是用 iWork 导出的真实空白文件（结构完整、兼容性好）。如需重新生成：

```bash
mkdir -p /tmp/tpl_out
osascript export_templates.applescript /tmp/tpl_out
```

## 许可

[MIT](LICENSE)
