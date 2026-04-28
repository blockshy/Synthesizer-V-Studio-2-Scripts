# BlockShy Script Manager

Synthesizer V Studio 2 侧边栏脚本管理器，用来集中查看并运行本仓库中的 BlockShy 脚本。

## 功能

- 在 Synthesizer V Studio 2.1.2+ 的 Scripts 侧边栏中显示脚本管理面板。
- 通过下拉列表查看已注册脚本。
- 显示每个脚本的用途、前置条件、用法和管理路径。
- 显示当前选中音符、选中音符组和当前音符组状态。
- 通过 Run 按钮直接加载并运行原有菜单脚本。

## 已管理脚本

- BPM Rescaler
- Pitch to Parameter
- Crying Effect

## 使用方法

1. 将 `BlockShy` 文件夹保持在 Synthesizer V Studio 的 scripts 目录下。
2. 打开 Synthesizer V Studio 2.1.2 或更高版本。
3. 打开侧边栏的 Scripts 面板，并重新扫描脚本。
4. 选择 `BlockShy Script Manager`。
5. 在面板中选择脚本，查看说明后点击 `Run`。

## 注意事项

- 管理器使用显式注册表，不会自动扫描任意目录。
- 被管理脚本仍保留原来的顶部 Scripts 菜单入口。
- 管理器会优先根据自身脚本路径查找同级脚本文件夹，再回退到相对路径；如果你移动了脚本文件夹，需要同步更新管理器中的注册表。
- 被加载的原脚本中的 `SV:finish()` 会在管理器环境中被忽略，避免关闭侧边栏脚本。
