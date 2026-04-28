# BlockShy Script Manager

Synthesizer V Studio 2 侧边栏脚本管理器，用来集中查看并运行本仓库中的 BlockShy 脚本。

## 功能

- 在 Synthesizer V Studio 2.1.2+ 的 Scripts 侧边栏中显示脚本管理面板。
- 通过下拉列表查看已注册脚本。
- 显示每个脚本的用途、前置条件、用法和管理路径。
- 显示当前选中音符、选中音符组和当前音符组状态。
- 通过 Run 按钮直接运行管理器内置的同版本脚本源码。
- 管理器索引由 `tools/sync_script_manager.lua.txt` 从 `BlockShy` 目录自动生成。

## 已管理脚本

- BPM Rescaler
- Crying Effect
- Flatten Pitch Curve
- Pitch to Parameter

## 使用方法

1. 将 `BlockShy` 文件夹保持在 Synthesizer V Studio 的 scripts 目录下。
2. 打开 Synthesizer V Studio 2.1.2 或更高版本。
3. 打开侧边栏的 Scripts 面板，并重新扫描脚本。
4. 选择 `BlockShy Script Manager`。
5. 在面板中选择脚本，查看说明后点击 `Run`。

## 新增脚本

新增脚本文件夹后运行：

```sh
lua tools/sync_script_manager.lua.txt
```

同步工具会扫描 `BlockShy/*/*.lua`，跳过侧边栏脚本，读取 `getClientInfo()`、`README.zh.md` 和 `README.en.md`，然后更新管理器的脚本列表和内置源码。

被管理脚本需要：

- 位于 `BlockShy/脚本文件夹/` 下。
- 提供 `getClientInfo()`。
- 提供 `main()`。
- 保持同目录下的 `README.zh.md` 和 `README.en.md` 可用。

## 注意事项

- 管理器使用生成式注册表，不会在 Synthesizer V 运行时自动扫描任意目录。
- 被管理脚本仍保留原来的顶部 Scripts 菜单入口。
- 侧边栏运行使用管理器内置源码，不依赖 `loadfile()` 或脚本目录的相对路径。
- 如果被管理脚本本体发生功能变化，需要重新运行 `lua tools/sync_script_manager.lua.txt`。
- 被加载的原脚本中的 `SV:finish()` 会在管理器环境中被忽略，避免关闭侧边栏脚本。
