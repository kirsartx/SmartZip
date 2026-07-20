# SmartZip 3.6 Kirs.1 “关于”页清理设计

日期：2026-07-20

## 目标

把设置窗口“关于”页更新为当前维护版本，删除旧作者的反馈与捐赠入口，并更新已经公开的 `v3.6-kirs.1`。

## 用户可见结果

“关于”页显示：

- `SmartZip 3.6 Kirs.1 (21)`
- 本次构建的修改时间
- 当前维护仓库：[kirsartx/SmartZip](https://github.com/kirsartx/SmartZip)
- 最新 Release：<https://github.com/kirsartx/SmartZip/releases/latest>
- 7-Zip Zstandard：[mcmilk/7-Zip-zstd](https://github.com/mcmilk/7-Zip-zstd)
- 7-Zip 提示文字：已测试 `7-Zip 26.02 ZS v1.5.7 R1`
- AutoHotkey：<https://www.autohotkey.com/>

以下内容完全消失：

- “建议反馈”
- “论坛反馈”
- “支持作者”
- 捐赠窗口及其微信、支付宝图片

## 版本元数据

- `MainVersion` 保持纯数字字符串 `3.6`，避免破坏 Ahk2Exe 文件版本格式和现有逻辑。
- 新增独立的版本后缀常量 `Kirs.1`，仅用于产品显示。
- `buildVersion` 从 `20` 更新为 `21`。
- Ahk2Exe `FileVersion` 保持 `3.6`。
- Ahk2Exe `ProductVersion` 更新为 `21`。
- `buileTime` 更新为本次实现提交的本地构建时间。
- INI 版本迁移沿用现有 `buildVersion` 机制；不新增、不改写其他默认配置。

## 代码与资源范围

在 `SmartZip.ahk` 中：

- 更新版本常量与 Ahk2Exe 产品版本。
- 更新“关于”页标题和链接。
- 删除两个反馈链接与“支持作者”按钮。
- 删除不再可达的 `Donate()` 函数及 `FileInstall` 调用。

从仓库删除：

- `donate/wexin.png`
- `donate/alipay.jpg`

不修改：

- 压缩/解压命令构造
- 排除规则
- PID/WMI 与 ErrorMode
- 密码行为
- 右键菜单
- `SmartZip.ini`
- `Contextmenu.exe`
- 隐藏运行大小单位

## 测试策略

遵循 TDD：

1. 先更新/新增 Pester 静态测试并观察 RED。
2. 测试要求：
   - Kirs.1、build 21、当前修改时间和产品版本存在。
   - 当前 GitHub、Release、7-Zip Zstandard、AutoHotkey 链接存在。
   - 旧 GitHub Issues 链接、小众软件论坛链接及三段旧文字不存在。
   - `Donate()`、捐赠 `FileInstall` 与 `donate` 资源引用不存在。
   - 两个捐赠资源文件从仓库删除。
3. 最小实现后运行 focused GREEN 与完整 Pester。
4. 保留现有 60 条回归测试，并增加关于页清理断言。

## 构建、部署与发布

1. 使用已经核验的 AutoHotkey v2.0.26 与 Ahk2Exe 构建。
2. 在临时目录复制 INI，使用 `C:\Tool\7-Zip-Zstandard` 执行 `a` / `x` 冒烟测试。
3. 部署前备份 `C:\Tool\SmartZip\SmartZip.exe`。
4. 仅替换 `SmartZip.exe`，验证 `SmartZip.ini` 与 `Contextmenu.exe` 哈希保持不变。
5. 将代码推送到 `kirsartx/SmartZip` 的 `main`。
6. 将现有 `v3.6-kirs.1` 标签从旧提交移动到最终源码提交。
7. 更新现有 `v3.6-kirs.1` Release 的说明，删除旧 `SmartZip.exe` 附件并上传最终 EXE，记录新的 SHA-256。
8. 不创建 `v3.6-kirs.2`。

更新既有 Release 的影响明确接受：

- `v3.6-kirs.1` 的源码归档将指向新提交。
- `SmartZip.exe` 下载内容、大小与 SHA-256 会变化。
- 已经下载的旧文件无法收回；Release 说明必须写明本次刷新。

## 验收标准

- “关于”页只展示当前项目与依赖信息。
- 三个旧入口、捐赠函数和捐赠资源全部删除。
- 版本显示为 `SmartZip 3.6 Kirs.1 (21)`。
- 完整测试为零失败。
- 临时 `a` / `x` 冒烟通过。
- 最终 EXE 部署成功，用户 INI 与 Contextmenu 未被覆盖。
- 更新后的 `v3.6-kirs.1` 指向最终源码提交，附件哈希与部署 EXE 一致。
