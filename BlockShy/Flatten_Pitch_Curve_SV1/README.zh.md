# Flatten Pitch Curve (SV1)

## 功能

将选中音符或选中音符组范围内的 `pitchDelta` 曲线清理/清零，作为 SV1/旧版本下的音高曲线简化处理。SV1 不支持 Synthesizer V Studio 2 Pitch Control Curve；如果需要写入水平 Pitch Control Curve，请使用 SV2 版本。

会处理：

- 选中音符：只处理当前音符组中这些音符覆盖的时间范围。
- 选中音符组：处理该音符组引用实际覆盖的目标时间范围。
- Studio 2 Pitch Control Point / Curve 会自动跳过。
- `pitchDelta` 参数：可选删除范围内旧点，并在范围边界写入 0 cents，作为辅助清理。

## 用法

1. 在钢琴窗中选中需要抹平音高曲线的音符，或在轨道中选中音符组。
2. 从脚本菜单运行 `Flatten Pitch Curve (SV1)`，在弹窗中填写参数。
3. 选择处理范围：选中音符、选中音符组，或两者一起处理。
4. 按需选择是否清零 `pitchDelta` 曲线。
5. Studio 2 Pitch Control 相关选项在 SV1 中会被跳过。
6. 点击 `OK` 执行。

## 注意事项

- 脚本不会改变音符音高、歌词、音符长度或音符位置。
- 本目录是 SV1/旧版本专用脚本，静态 metadata 只暴露传统 `main()` 弹窗入口，不声明侧边栏类型。
- 如需 SV2.1.2+ 侧边栏版本，请使用 `BlockShy/Flatten_Pitch_Curve_SV2/Flatten_Pitch_Curve_SV2.lua`。
- SV1 版本只能清理/清零 `pitchDelta`，不能写入 Studio 2 Pitch Control Curve，因此抹平效果是降级处理。
- 默认会在选区外相邻位置写入保护点，减少选区内抹平对外侧曲线的影响。
- 处理音符组时，脚本修改的是音符组目标。如果该目标被多个引用复用，其他引用也会同步变化。
- Studio 2 Pitch Control API 只在支持该功能的版本中可用；不支持时脚本会跳过并在完成提示中说明。
