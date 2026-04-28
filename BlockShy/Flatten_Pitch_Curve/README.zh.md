# Flatten Pitch Curve

## 功能

将选中音符或选中音符组范围内的音高曲线抹平。脚本会为每个目标音符绘制一条完全水平的 Synthesizer V Studio 2 Pitch Control Curve，使音高按音符本身的 MIDI pitch 保持水平。

会处理：

- 选中音符：只处理当前音符组中这些音符覆盖的时间范围。
- 选中音符组：处理该音符组引用实际覆盖的目标时间范围。
- 水平 Pitch Control Curve：每个目标音符生成一条从音符起点到终点的水平音高曲线。
- 原有 Studio 2 音高控制对象：可选先移除与范围重叠的 Pitch Control Point / Curve。
- `pitchDelta` 参数：可选删除范围内旧点，并在范围边界写入 0 cents，作为辅助清理。

## 用法

1. 在钢琴窗中选中需要抹平音高曲线的音符，或在轨道中选中音符组。
2. 打开 Scripts 侧边栏中的 `Flatten Pitch Curve` 面板。
3. 选择处理范围：选中音符、选中音符组，或两者一起处理。
4. 保持“绘制水平 Studio 2 Pitch Control Curve”启用。
5. 按需选择是否清零 `pitchDelta` 曲线。
6. 按需选择是否先移除范围内原有 Studio 2 音高控制点/曲线。
7. 点击 `Run` 执行。

## 注意事项

- 脚本不会改变音符音高、歌词、音符长度或音符位置。
- 本脚本是 Synthesizer V Studio 2.1.2+ 侧边栏脚本，不再通过顶部 Scripts 菜单弹窗运行。
- 面板内可通过“语言 / Language”切换中文或英文界面，默认中文。
- 只清零 `pitchDelta` 不足以抹平 SV2 自动绘制的音高；默认会额外写入水平 Pitch Control Curve。
- 默认会在选区外相邻位置写入保护点，减少选区内抹平对外侧曲线的影响。
- 处理音符组时，脚本修改的是音符组目标。如果该目标被多个引用复用，其他引用也会同步变化。
- Studio 2 Pitch Control API 只在支持该功能的版本中可用；不支持时脚本会跳过并在完成提示中说明。
