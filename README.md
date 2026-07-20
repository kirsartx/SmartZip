## 功能介绍
 - 智能解压
    - 单文件时解压至当前文件夹
    - 多文件时解压到当前文件夹下的某个文件夹
    - 压缩包包含密码时,遍历设置的密码,密码正确解压,不正确提示手动输入密码并解压
      - 自带两个密码,上次使用的密码,剪贴板复制的内容(移除了首尾空格和换行)
      - 如不想添加可以直接复制密码然后运行智能解压
      - 自动新增使用过的密码 **2.20+**
      - 动态排序密码 **2.20+**
    - 解压完成后按照指定规则处理压缩后的文件,如重命名,删除
    - 解压嵌套压缩包
      - 文件后缀名符合`ini-ext,extExp` 规则则解压
      - **嵌套压缩包解压后会删除**
 - 智能打开
   - 如果是压缩包则打开,如果不是则显示添加到压缩包界面
 - 压缩
   - 全是文件夹则每个文件夹生成一个压缩包, 否则生成单个压缩包

## 3.6 Kirs.2 安全解压流水线

SmartZip **3.6 Kirs.2 (22)** 使用安全优先（safety-first）的解压流水线，不再用输出大小百分比判断成功。

### 状态流

每个顶层压缩包按固定顺序处理：

1. **list / 探测** — `7z l -slt` 识别格式、加密与分卷
2. **test / 完整性测试** — 需要处理源包或用户启用 `test` 时执行 `7z t`
3. **extract-to-isolated-temp** — 解压到隔离临时目录
4. **finalize** — 仅在干净成功时提交到目标目录；失败则隔离部分输出

### 源包安全门

- **只有干净 `OK`**（探测、必要测试、正式解压均为干净成功）才允许按配置回收源包（回收站，非永久删除）
- **`OK_WITH_WARNING`、任何失败、取消**一律保留源包
- 分卷组**永不自动删除**任何卷

### 部分输出

失败且临时目录有内容时，整体移到：

```text
<压缩包名>_解压不完整_<yyyyMMdd-HHmmss>
```

目录内含 UTF-8 `SmartZip-诊断.txt`（状态、阶段、退出码、脱敏错误摘要；不含密码）。

### 分卷

- 选中非首卷且首卷存在时，**规范化到第一卷**后再处理
- 同组多卷批量选择只生成一个任务
- **所有分卷成员始终保留**，不因成功或失败自动删除

### 诊断分类

下列状态相互区分，不再把 `Headers Error` 一律当成损坏：

| 状态 | 含义 |
|------|------|
| `HEADER_CORRUPT` | 文件头损坏 |
| `TRUNCATED` | 截断 / Unexpected end of archive |
| `DATA_CORRUPT` | CRC / Data Error |
| `WRONG_PASSWORD` | 密码错误 |
| `MISSING_VOLUME` | 缺卷 |
| `UNSUPPORTED_METHOD` | 不支持的方法或特性 |
| `NOT_ARCHIVE` | 不是压缩包 |

### 诊断界面与批量

- 单任务：`SmartZip 未完成解压` / `SmartZip 解压警告`
- 按钮：打开部分文件目录、重新输入密码、定位首卷、使用 7-Zip 打开、**复制脱敏诊断信息**、关闭
- 批量：后续任务继续；结束时**一次汇总**（成功 / 警告 / 失败 / 跳过）

### 日志与密码脱敏

- 日志：`SmartZip-diagnostics.log`（轮转 `.1` / `.2`，约 1 MiB）
- 所有密码参数记为 `-p***`；不记录密码候选、输入框或剪贴板原文
- “复制脱敏诊断信息”默认只含文件名，不含完整路径

### 测试引擎

当前集成与冒烟验证使用：

```text
C:\Tool\7-Zip-Zstandard\7z.exe
```

（7-Zip 26.02 ZS）。Kirs.2 是在 **Kirs.1 之上**的可靠性增强版本发布线；**不替代或替换**已发布的 Kirs.1 标签/Release。

### 恢复建议

1. 取得完整源包或全部分卷
2. 重试正确密码（或使用“重新输入密码”）
3. 用 7-Zip 直接打开核对
4. 检查 `_解压不完整_` 目录中的部分结果与 `SmartZip-诊断.txt`
5. 使用“复制脱敏诊断信息”反馈问题（不会泄露密码）

## 设置方式
 - 直接运行 `SmartZip.exe` 会显示设置界面 **3.0+**
 - **建议清空所有 `password` `rename` `delete` 然后按照需求添加**
 - 可批量从`tx`t或旧版本`ini`设置中导入密码  **3.0+**
 - 更多自定义请直接编辑ini,参考以下链接设置,后续可能不再更新ini文档
     - [INI设置](ini.md)

## 运行方式
 - 如果启用了右键,可在资源管理器中右键文件使用
    - 右键实现方式不完美
       - 由于右键菜单单次只能传递一个文件,传递多文件过于复杂
       - 目前方法为在当前窗口发送 复制(Ctrl+C) 快捷键,可能会扰乱剪贴板
       -  右键菜单有15个文件限制,解除限制访问下方链接按说明操作
          - [context-menus-shortened-select-over-15-files](https://docs.microsoft.com/zh-cn/troubleshoot/windows-client/shell-experience/context-menus-shortened-select-over-15-files)
 - 右键发送到菜单 **2.14+**
    - 不影响剪贴板
    - 不受15个文件限制影响
    - 如使用资源管理器可用此代替
    - 缺点是在二级目录里
 - 通过直接传递参数运行(推荐但比较繁杂)
   - 智能解压: `SmartZip.exe  x  file1 file2 file3 ....`
   - 手动指定编码解压: `SmartZip.exe  xc  file1 file2 file3 ....`
   - 使用7-zip打开: `SmartZip.exe  o  file1`
   - 压缩: `SmartZip.exe  a  file1 file2 file3 ....`
 - Directory Opus 示例
   - 智能解压: `SmartZip.exe x {allfilepath}`
   - 手动指定编码解压: `SmartZip.exe xc {allfilepath}`
   - 使用7-zip打开: `SmartZip.exe o {allfilepath} `
   - 压缩: `SmartZip.exe a {allfilepath} `
 - 向 `Contextmenu.exe` 传递参数或直接运行
    - 它会在运行时执行复制,然后将其传给主脚本执行
    - 选中文件然后以快捷键或其他方法调用`Contextmenu.exe`
    - 无参时默认智能解压
   - 智能解压: `Contextmenu.exe  x`
   - 手动指定编码解压: `Contextmenu.exe  xc`
   - 使用7-zip打开: `Contextmenu.exe  o`
   - 压缩: `Contextmenu.exe  a`
 - 直接运行 `SmartZip.exe` 然后拖拽文件到界面上会触发智能解压 **3.0+**
 - 拖拽文件到 `SmartZip.exe` 上会触发智能解压

## 提示
 - **更新版本建议备份 ini以防出错**

## 预览图
 - 设置界面

![set](pic/set.gif)

 - 手动指定编码解压界面

![xc](pic/xc.jpg)

 - 右键菜单界面

![menu](pic/menu.jpg)

 - 批量解压界面

![addZip](pic/addZip.jpg)

 - 批量压缩界面

![unZip](pic/unZip.jpg)


## 相关链接
  - [7-zip](https://www.7-zip.org/)
    - 测试基于 7-Zip 21.07 版本
  - [小众软件](https://www.appinn.com/smartzip-for-7zip/)
  - [小众软件发现频道](https://meta.appinn.net/t/topic/33555)