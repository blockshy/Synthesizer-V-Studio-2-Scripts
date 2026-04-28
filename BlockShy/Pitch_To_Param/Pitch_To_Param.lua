function getClientInfo()
  return {
    name = "Pitch to Parameter",
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

  if #selectedNotes == 0 then
    SV:showMessageBox("提示", "请先选中需要处理的音符。")
    return
  end

  -- 按时间排序
  table.sort(selectedNotes, function(a, b)
    return a:getOnset() < b:getOnset()
  end)

  local currentGroup = editor:getCurrentGroup()
  local groupTarget = currentGroup:getTarget()

  -- 预设参数
  local paramOptions = { "tension", "breathiness", "gender", "toneShift", "loudness" }
  local paramLabels =
    { "Tension (张力)", "Breathiness (气声)", "Gender (性别)", "Tone Shift (音色)", "Loudness (响度)" }

  -- 计算平均音高供默认值使用
  local totalPitch = 0
  for _, n in ipairs(selectedNotes) do
    totalPitch = totalPitch + n:getPitch()
  end
  local avgPitch = math.floor(totalPitch / #selectedNotes)

  -- UI
  local inputForm = {
    title = "音高映射 V4 (智能优化)",
    message = "【智能优化】平直部分将自动合并为直线，不再生成密集点。\n【线性模式】强制每个音符仅生成首尾两个点。",
    buttons = "OkCancel",
    widgets = {
      {
        name = "targetParamIdx",
        type = "ComboBox",
        label = "目标参数",
        choices = paramLabels,
        default = 0,
      },
      {
        name = "mode",
        type = "ComboBox",
        label = "映射逻辑 (Source Mode)",
        choices = {
          "全音高跟随 (旋律+弯音)",
          "仅跟随弯音 (忽略旋律高低)",
        },
        default = 0,
      },
      {
        name = "simplifyMode",
        type = "ComboBox",
        label = "点密度控制 (Density)",
        choices = {
          "智能精简 (推荐：保留细节但去除冗余)",
          "强制线性 (极简：每个音符仅首尾两点)",
        },
        default = 0,
      },
      {
        name = "centerPitch",
        type = "Slider",
        label = "参考中心音高",
        format = "%1.0f",
        minValue = 36,
        maxValue = 96,
        interval = 1,
        default = avgPitch,
      },
      {
        name = "strength",
        type = "Slider",
        label = "映射强度",
        format = "%1.2f",
        minValue = 0.01,
        maxValue = 1.0,
        interval = 0.01,
        default = 0.05,
      },
      {
        name = "direction",
        type = "ComboBox",
        label = "方向",
        choices = { "正向", "反向" },
        default = 0,
      },
    },
  }

  local result = SV:showCustomDialog(inputForm)
  if result.status == "Cancel" then
    return
  end

  local targetParamName = paramOptions[result.answers.targetParamIdx + 1]
  local sourceMode = result.answers.mode
  local isForceLinear = (result.answers.simplifyMode == 1) -- 是否强制线性
  local centerPitch = result.answers.centerPitch
  local strength = result.answers.strength
  local isInverted = (result.answers.direction == 1)

  local pitchDelta = groupTarget:getParameter("pitchDelta")
  local targetParam = groupTarget:getParameter(targetParamName)

  -- 步长设置：1/32 拍 (降低采样率，足够还原颤音)
  local BLICKS_PER_QUARTER = 1470000
  local step = math.floor(BLICKS_PER_QUARTER / 32)

  -- 优化阈值：如果新值和旧值差异小于此数，则不打点
  local optimizeThreshold = 0.005

  -- 处理逻辑
  for _, note in ipairs(selectedNotes) do
    local noteStart = note:getOnset()
    local noteEnd = note:getEnd()
    local noteBasePitch = note:getPitch()

    -- 内部函数：计算某时刻的目标参数值
    local function calcVal(t)
      local deltaCents = pitchDelta:get(t)
      local currentTotalPitch
      if sourceMode == 0 then
        currentTotalPitch = noteBasePitch + (deltaCents / 100.0)
      else
        currentTotalPitch = centerPitch + (deltaCents / 100.0)
      end

      local diff = currentTotalPitch - centerPitch
      local val = diff * strength
      if isInverted then
        val = -val
      end

      -- 范围限制
      if targetParamName ~= "loudness" then
        if val > 1.0 then
          val = 1.0
        end
        if val < -1.0 then
          val = -1.0
        end
      end
      return val
    end

    if isForceLinear then
      -- 【模式A：强制线性】
      -- 只取头尾两点，中间直接拉直
      local valStart = calcVal(noteStart)
      local valEnd = calcVal(noteEnd)

      -- 清除该区域原有的参数（可选，这里直接覆盖写入）
      targetParam:add(noteStart, valStart)
      targetParam:add(noteEnd, valEnd)
    else
      -- 【模式B：智能精简】
      -- 总是写入起始点
      local lastWrittenVal = calcVal(noteStart)
      targetParam:add(noteStart, lastWrittenVal)

      -- 遍历中间
      for t = noteStart + step, noteEnd - step, step do
        local currentVal = calcVal(t)

        -- 核心优化逻辑：只有当数值变化超过阈值时才写入
        -- 这样平滑的直线就不会产生密集的点
        if math.abs(currentVal - lastWrittenVal) > optimizeThreshold then
          targetParam:add(t, currentVal)
          lastWrittenVal = currentVal
        end
      end

      -- 总是写入结束点，保证闭合
      local endVal = calcVal(noteEnd)
      targetParam:add(noteEnd, endVal)
    end
  end

  SV:finish()
end
