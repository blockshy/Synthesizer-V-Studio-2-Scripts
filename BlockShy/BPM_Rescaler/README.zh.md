# BPM Rescaler

## 功能

用于修复 MIDI/轨道原始 BPM 与当前工程 BPM 不一致导致的音符长度和参数曲线错位问题。脚本会按 `当前 BPM / 原始 BPM` 的比例缩放当前音符组目标内的数据。

会处理：

- 音符起点和长度
- 参数曲线：`pitchDelta`、`vibratoEnv`、`loudness`、`tension`、`breathiness`、`voicing`、`gender`，以及兼容性尝试的 `toneShift`
- Synthesizer V Studio 2 音高控制点和音高控制曲线

## 用法

1. 在 Synthesizer V Studio 2 中选中要处理的轨道或音符组。
2. 打开 Scripts 侧边栏中的 `BPM Rescaler` 面板。
3. 点击 `Detect BPM` 读取当前引用位置的 BPM。
4. 确认“Current BPM”，并输入 MIDI/轨道导入前的“Original BPM”。
5. 选择缩放锚点：
   - “音符组内部 0 位置”：保持组内 0 位置不动。
   - “第一个音符起点”：保持第一个音符位置不动，适合保留组内前置空白。
6. 按需勾选是否缩放参数曲线和 Studio 2 音高控制。
7. 点击 `Run` 执行。

## 注意事项

- 本脚本执行的是单一比例缩放，不是完整 tempo map 转换。如果工程中有多个 BPM 标记，脚本会提示风险。
- 本脚本是 Synthesizer V Studio 2.1.2+ 侧边栏脚本，不再通过顶部 Scripts 菜单弹窗运行。
- 当前实现修改的是当前音符组的目标对象。如果该目标被多个引用复用，其他引用也会一起变化。
- 参数点压缩到同一 blick 时会合并，后面的点会覆盖前面的点，完成提示中会显示冲突数量。
- 缩放后落到负数时间的对象会被夹到 0 blick。
