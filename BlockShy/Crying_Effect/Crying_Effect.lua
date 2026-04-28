function getClientInfo()
  return {
    name = "Crying Effect",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 4,
    minEditorVersion = 65537,
  }
end

function main()
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = selection:getSelectedNotes()

  -- 检查是否有选中音符
  if #selectedNotes == 0 then
    SV:showMessageBox("提示", "请先在钢琴窗中选中一个或多个音符。")
    return
  end

  -- 弹出强度设置对话框
  local inputForm = {
    title = "自动哭腔参数设置",
    message = "请调整哭腔的强度参数：",
    buttons = "OkCancel",
    widgets = {
      {
        name = "intensity",
        type = "Slider",
        label = "哭腔强度 (Intensity)",
        format = "%1.1f",
        minValue = 0.5,
        maxValue = 2.0,
        interval = 0.1,
        default = 1.0,
      },
      {
        name = "addPitchDrop",
        type = "CheckBox",
        text = "添加尾部下坠 (Sobbing Tail)",
        default = true,
      },
    },
  }

  local result = SV:showCustomDialog(inputForm)
  if result.status == "Cancel" then
    return
  end

  local intensity = result.answers.intensity
  local addPitchDrop = result.answers.addPitchDrop

  -- 获取当前组对象
  local currentGroup = editor:getCurrentGroup()
  local groupTarget = currentGroup:getTarget()

  -- 【改动】获取所有需要的参数曲线，包括颤音包络
  local paramTension = groupTarget:getParameter("tension")
  local paramBreath = groupTarget:getParameter("breathiness")
  local paramPitch = groupTarget:getParameter("pitchDelta")
  local paramVibEnv = groupTarget:getParameter("vibratoEnv") -- 用参数控制颤音深度

  -- 开始批量处理
  for i = 1, #selectedNotes do
    local note = selectedNotes[i]
    local onset = note:getOnset()
    local dur = note:getDuration()
    local endPos = onset + dur

    -- 步长计算 (防止极短音符)
    local step = math.floor(dur / 4)
    if step < 1000000 then
      step = math.floor(dur / 4)
    end -- 简单处理
    if step < 1 then
      step = 1
    end

    -- 1. 绘制 颤音包络 (Vibrato Envelope)
    -- 替代之前的 setDF0Vbr
    -- 标准值为 1.0，哭腔加大到 1.2 ~ 1.5
    local vibDepth = 1.3 * intensity
    if vibDepth > 2.0 then
      vibDepth = 2.0
    end

    -- 在音符范围内提升颤音深度
    paramVibEnv:add(onset, vibDepth)
    paramVibEnv:add(endPos, vibDepth)

    -- 2. 绘制 气声 (Breathiness)
    for t = 0, 4 do
      local pos = onset + (step * t)
      if pos > endPos then
        pos = endPos
      end

      local breathValue = 0.3 * intensity
      if t == 1 or t == 2 or t == 3 then
        breathValue = breathValue + 0.3 -- 中间加重
      end
      if breathValue > 1.2 then
        breathValue = 1.2
      end

      paramBreath:add(pos, breathValue)
    end

    -- 3. 绘制 张力 (Tension)
    for t = 0, 4 do
      local pos = onset + (step * t)
      if pos > endPos then
        pos = endPos
      end

      local tensValue = 0.4 * intensity
      -- 随机抖动
      local randomJitter = (math.random() - 0.5) * 0.3
      tensValue = tensValue + randomJitter

      if tensValue > 1.0 then
        tensValue = 1.0
      end
      if tensValue < -1.0 then
        tensValue = -1.0
      end

      paramTension:add(pos, tensValue)
    end

    -- 4. 绘制 音高下坠 (Pitch Drop)
    if addPitchDrop then
      local dropStart = onset + (dur * 0.75)
      local dropEnd = endPos
      local dropAmount = -150 * intensity

      -- 确保下坠前是平稳的（相对于当前音高）
      paramPitch:add(dropStart, 0)
      paramPitch:add(dropEnd, dropAmount)
    end
  end

  SV:finish()
end
