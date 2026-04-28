function getClientInfo()
  return {
    name = "Pitch to Parameter",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 7,
    minEditorVersion = 131330,
    type = "SidePanelSection",
  }
end

local TARGET_PARAM_CANDIDATES = {
  { typeName = "tension", label = "Tension (张力)" },
  { typeName = "breathiness", label = "Breathiness (气声)" },
  { typeName = "gender", label = "Gender (性别)" },
  { typeName = "voicing", label = "Voicing (清浊)" },
  { typeName = "vibratoEnv", label = "Vibrato Envelope (颤音包络)" },
  { typeName = "loudness", label = "Loudness (响度)" },
  { typeName = "toneShift", label = "Tone Shift (音色，兼容性尝试)" },
}

local SOURCE_MODE_BEND_ONLY = 1
local SOURCE_MODE_COMPUTED = 2

local DENSITY_SMART = 0
local DENSITY_LINEAR = 2

local WRITE_OVERWRITE_RANGES = 0
local WRITE_APPEND_ONLY = 1
local WRITE_REBUILD_TARGET = 2

local SAMPLE_DENOMINATORS = { 8, 16, 32, 64 }

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end
  return nil
end

local function clamp(value, minValue, maxValue)
  if minValue ~= nil and value < minValue then
    return minValue
  end
  if maxValue ~= nil and value > maxValue then
    return maxValue
  end
  return value
end

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function getParameterSafe(group, typeName)
  return safeCall(function()
    return group:getParameter(typeName)
  end)
end

local function getAutomationDefinition(param)
  local definition = safeCall(function()
    return param:getDefinition()
  end)

  if type(definition) ~= "table" then
    return nil
  end

  return definition
end

local function getParamRange(param)
  local definition = getAutomationDefinition(param)
  if type(definition) == "table" and type(definition.range) == "table" then
    local minValue = definition.range[1] or definition.range.min
    local maxValue = definition.range[2] or definition.range.max
    if type(minValue) == "number" and type(maxValue) == "number" then
      return minValue, maxValue, definition
    end
  end

  return -1.0, 1.0, definition
end

local function getGroupPitchOffset(groupReference)
  local offset = safeCall(function()
    return groupReference:getPitchOffset()
  end)

  if type(offset) == "number" then
    return offset
  end

  return 0
end

local function getGroupTimeOffset(groupReference)
  local offset = safeCall(function()
    return groupReference:getTimeOffset()
  end)

  if type(offset) == "number" then
    return offset
  end

  return 0
end

local function getNoteDetune(note)
  local detune = safeCall(function()
    return note:getDetune()
  end)

  if type(detune) == "number" then
    return detune
  end

  return 0
end

local function getSortedSelectedNotes(selection)
  local notes = selection:getSelectedNotes()

  table.sort(notes, function(a, b)
    return a:getOnset() < b:getOnset()
  end)

  return notes
end

local function collectMergedRanges(notes)
  local ranges = {}

  for _, note in ipairs(notes) do
    local rangeStart = note:getOnset()
    local rangeEnd = note:getEnd()

    if rangeEnd > rangeStart then
      table.insert(ranges, {
        start = rangeStart,
        finish = rangeEnd,
      })
    end
  end

  table.sort(ranges, function(a, b)
    return a.start < b.start
  end)

  local merged = {}
  for _, range in ipairs(ranges) do
    local last = merged[#merged]
    if last ~= nil and range.start <= last.finish then
      if range.finish > last.finish then
        last.finish = range.finish
      end
    else
      table.insert(merged, {
        start = range.start,
        finish = range.finish,
      })
    end
  end

  return merged
end

local function buildSampleTimes(noteStart, noteEnd, step, densityMode)
  local times = {}

  local function addTime(blick)
    if times[#times] ~= blick then
      table.insert(times, blick)
    end
  end

  addTime(noteStart)

  if densityMode ~= DENSITY_LINEAR then
    local t = noteStart + step
    while t < noteEnd do
      addTime(t)
      t = t + step
    end
  end

  addTime(noteEnd)

  return times
end

local function calcLightweightPitch(note, pitchDelta, blick, pitchOffset)
  local notePitch = note:getPitch()
  local detune = getNoteDetune(note)
  local deltaCents = pitchDelta:get(blick)
  return notePitch + pitchOffset + (detune / 100.0) + (deltaCents / 100.0)
end

local function calcBendOnlyPitch(centerPitch, pitchDelta, blick)
  local deltaCents = pitchDelta:get(blick)
  return centerPitch + (deltaCents / 100.0)
end

local function getComputedPitchAt(groupReference, groupTimeOffset, blick)
  local values = safeCall(function()
    return SV:getComputedPitchForGroup(groupReference, blick + groupTimeOffset, 1, 1)
  end)

  if type(values) == "table" and type(values[1]) == "number" then
    return values[1]
  end

  return nil
end

local function linearError(point, left, right)
  if right.blick == left.blick then
    return math.abs(point.value - left.value)
  end

  local ratio = (point.blick - left.blick) / (right.blick - left.blick)
  local expected = left.value + ((right.value - left.value) * ratio)
  return math.abs(point.value - expected)
end

local function markSimplifiedPoints(points, firstIndex, lastIndex, threshold, keep)
  if lastIndex <= firstIndex + 1 then
    return
  end

  local maxError = -1
  local maxIndex = nil
  local left = points[firstIndex]
  local right = points[lastIndex]

  for i = firstIndex + 1, lastIndex - 1 do
    local err = linearError(points[i], left, right)
    if err > maxError then
      maxError = err
      maxIndex = i
    end
  end

  if maxIndex ~= nil and maxError > threshold then
    keep[maxIndex] = true
    markSimplifiedPoints(points, firstIndex, maxIndex, threshold, keep)
    markSimplifiedPoints(points, maxIndex, lastIndex, threshold, keep)
  end
end

local function simplifyPoints(points, threshold)
  if #points <= 2 or threshold <= 0 then
    return points
  end

  local keep = {
    [1] = true,
    [#points] = true,
  }

  markSimplifiedPoints(points, 1, #points, threshold, keep)

  local simplified = {}
  for i, point in ipairs(points) do
    if keep[i] then
      table.insert(simplified, point)
    end
  end

  return simplified
end

local function addGeneratedPoint(pointMap, blick, value, stats)
  if pointMap[blick] ~= nil then
    stats.collisions = stats.collisions + 1
  end
  pointMap[blick] = value
end

local function getSortedPointEntries(pointMap)
  local entries = {}
  for blick, value in pairs(pointMap) do
    table.insert(entries, { blick = blick, value = value })
  end

  table.sort(entries, function(a, b)
    return a.blick < b.blick
  end)

  return entries
end

local function buildGeneratedPoints(notes, context)
  local pointMap = {}
  local stats = {
    sampledPoints = 0,
    generatedPoints = 0,
    collisions = 0,
    computedFallbacks = 0,
  }

  for _, note in ipairs(notes) do
    local noteStart = note:getOnset()
    local noteEnd = note:getEnd()
    local sampleTimes = buildSampleTimes(noteStart, noteEnd, context.step, context.densityMode)
    local notePoints = {}

    for _, blick in ipairs(sampleTimes) do
      local pitch

      if context.sourceMode == SOURCE_MODE_COMPUTED then
        pitch = getComputedPitchAt(context.groupReference, context.groupTimeOffset, blick)
        if pitch == nil then
          stats.computedFallbacks = stats.computedFallbacks + 1
          pitch = calcLightweightPitch(note, context.pitchDelta, blick, context.pitchOffset)
        end
      elseif context.sourceMode == SOURCE_MODE_BEND_ONLY then
        pitch = calcBendOnlyPitch(context.centerPitch, context.pitchDelta, blick)
      else
        pitch = calcLightweightPitch(note, context.pitchDelta, blick, context.pitchOffset)
      end

      local value = (pitch - context.centerPitch) * context.strength
      if context.isInverted then
        value = -value
      end

      value = clamp(value, context.targetMin, context.targetMax)

      table.insert(notePoints, {
        blick = blick,
        value = value,
      })

      stats.sampledPoints = stats.sampledPoints + 1
    end

    if context.densityMode == DENSITY_SMART then
      notePoints = simplifyPoints(notePoints, context.simplifyThreshold)
    end

    for _, point in ipairs(notePoints) do
      addGeneratedPoint(pointMap, point.blick, point.value, stats)
    end
  end

  local entries = getSortedPointEntries(pointMap)
  stats.generatedPoints = #entries

  return entries, stats
end

local function clearRanges(param, ranges)
  local removed = 0

  for _, range in ipairs(ranges) do
    local points = param:getPoints(range.start, range.finish)
    removed = removed + #points
    if #points > 0 then
      param:remove(range.start, range.finish)
    end
  end

  return removed
end

local function clearAllPoints(param)
  local points = param:getAllPoints()
  local removed = #points

  if removed > 0 then
    param:removeAll()
  end

  return removed
end

local function writeGeneratedPoints(param, points)
  local created = 0
  local updated = 0

  for _, point in ipairs(points) do
    local didCreate = param:add(point.blick, point.value)
    if didCreate then
      created = created + 1
    else
      updated = updated + 1
    end
  end

  return created, updated
end

local targetParamValue = nil
local customParamValue = nil
local sourceModeValue = nil
local densityModeValue = nil
local writeModeValue = nil
local sampleIntervalValue = nil
local simplifyPercentValue = nil
local centerPitchValue = nil
local strengthValue = nil
local directionValue = nil
local languageValue = nil
local runButtonValue = nil
local refreshButtonValue = nil
local statusValue = nil
local initialized = false
local isRunning = false

local function showMessage(title, message)
  safeCall(function()
    SV:showMessageBoxAsync(title, message)
    return true
  end)
end

local function createWidgetValue(defaultValue)
  local widgetValue = safeCall(function()
    return SV:create("WidgetValue")
  end)

  if widgetValue ~= nil then
    safeCall(function()
      widgetValue:setValue(defaultValue)
      return true
    end)
  end

  return widgetValue
end

local function getWidgetValue(widgetValue, fallback)
  if widgetValue == nil then
    return fallback
  end

  local value = safeCall(function()
    return widgetValue:getValue()
  end)

  if value == nil then
    return fallback
  end

  return value
end

local function isEnglish()
  return getWidgetValue(languageValue, 0) == 1
end

local function tr(zh, en)
  if isEnglish() then
    return en
  end

  return zh
end

local function setWidgetValue(widgetValue, value)
  if widgetValue == nil then
    return
  end

  safeCall(function()
    widgetValue:setValue(value)
    return true
  end)
end

local function setValueChangeCallback(widgetValue, callback)
  if widgetValue == nil then
    return
  end

  safeCall(function()
    widgetValue:setValueChangeCallback(callback)
    return true
  end)
end

local function buildStaticParamLabels()
  local labels = {}
  for _, candidate in ipairs(TARGET_PARAM_CANDIDATES) do
    table.insert(labels, candidate.label)
  end
  table.insert(labels, tr("自定义参数名 (Custom)", "Custom parameter name (自定义)"))
  return labels
end

local function getAverageSelectedPitch(notes)
  if #notes == 0 then
    return 60
  end

  local totalPitch = 0
  for _, note in ipairs(notes) do
    totalPitch = totalPitch + note:getPitch()
  end

  return math.floor(totalPitch / #notes)
end

local function updateStatus()
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)
  local centerPitch = getAverageSelectedPitch(selectedNotes)

  if #selectedNotes > 0 then
    setWidgetValue(centerPitchValue, centerPitch)
  end

  setWidgetValue(
    statusValue,
    tr("选中音符: ", "Selected notes: ")
      .. #selectedNotes
      .. tr(" | 建议中心音高: ", " | suggested center pitch: ")
      .. centerPitch
  )
end

local function resolveTargetParamName()
  local customParam = trim(getWidgetValue(customParamValue, ""))
  if customParam ~= "" then
    return customParam
  end

  local targetIndex = getWidgetValue(targetParamValue, 0) or 0
  if targetIndex == #TARGET_PARAM_CANDIDATES then
    return nil
  end

  local candidate = TARGET_PARAM_CANDIDATES[targetIndex + 1]
  if candidate == nil then
    return nil
  end

  return candidate.typeName
end

local function runPanel()
  if isRunning then
    return
  end

  isRunning = true

  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)

  if #selectedNotes == 0 then
    showMessage(
      tr("提示", "Notice"),
      tr("请先选中需要处理的音符。", "Select the notes to process first.")
    )
    isRunning = false
    return
  end

  local currentGroup = editor:getCurrentGroup()
  if currentGroup == nil then
    showMessage(
      tr("错误", "Error"),
      tr(
        "未检测到当前音符组，请先选中一个轨道或音符组。",
        "No current note group detected. Select a track or note group first."
      )
    )
    isRunning = false
    return
  end

  local groupTarget = currentGroup:getTarget()
  if groupTarget == nil then
    showMessage(
      tr("错误", "Error"),
      tr("未检测到当前音符组目标。", "No current note group target detected.")
    )
    isRunning = false
    return
  end

  local pitchDelta = getParameterSafe(groupTarget, "pitchDelta")
  if pitchDelta == nil then
    showMessage(
      tr("错误", "Error"),
      tr(
        "当前音符组没有可用的 pitchDelta 参数。",
        "The current note group has no available pitchDelta parameter."
      )
    )
    isRunning = false
    return
  end

  local targetParamName = resolveTargetParamName()
  if targetParamName == nil then
    showMessage(
      tr("错误", "Error"),
      tr("选择自定义参数时必须填写参数名。", "A parameter name is required when Custom is selected.")
    )
    isRunning = false
    return
  end

  local targetParam = getParameterSafe(groupTarget, targetParamName)
  if targetParam == nil then
    showMessage(
      tr("错误", "Error"),
      tr("目标参数不可用: ", "Target parameter is unavailable: ") .. targetParamName
    )
    isRunning = false
    return
  end

  local targetMin, targetMax, targetDefinition = getParamRange(targetParam)
  local targetRange = targetMax - targetMin
  local sampleDenominator = SAMPLE_DENOMINATORS[(getWidgetValue(sampleIntervalValue, 2) or 2) + 1] or 32
  local step = math.floor((SV.QUARTER or 705600000) / sampleDenominator)
  if step < 1 then
    step = 1
  end

  local simplifyThreshold = targetRange * ((getWidgetValue(simplifyPercentValue, 0.5) or 0) / 100.0)
  local ranges = collectMergedRanges(selectedNotes)

  local context = {
    sourceMode = getWidgetValue(sourceModeValue, 0),
    densityMode = getWidgetValue(densityModeValue, 0),
    centerPitch = getWidgetValue(centerPitchValue, getAverageSelectedPitch(selectedNotes)),
    strength = getWidgetValue(strengthValue, 0.05),
    isInverted = (getWidgetValue(directionValue, 0) == 1),
    step = step,
    simplifyThreshold = simplifyThreshold,
    targetMin = targetMin,
    targetMax = targetMax,
    pitchDelta = pitchDelta,
    pitchOffset = getGroupPitchOffset(currentGroup),
    groupTimeOffset = getGroupTimeOffset(currentGroup),
    groupReference = currentGroup,
  }

  local points, pointStats = buildGeneratedPoints(selectedNotes, context)
  if #points == 0 then
    showMessage(tr("提示", "Notice"), tr("没有生成任何参数点。", "No parameter points were generated."))
    isRunning = false
    return
  end

  if context.sourceMode == SOURCE_MODE_COMPUTED and pointStats.computedFallbacks == pointStats.sampledPoints then
    showMessage(
      tr("提示", "Notice"),
      tr(
        "计算后音高尚未准备好，脚本未写入参数。请等待 Synthesizer V 完成音高计算后重试，或改用轻量音高来源。",
        "Computed pitch is not ready, so no parameters were written. "
          .. "Wait for Synthesizer V to finish pitch calculation, or use a lightweight pitch source."
      )
    )
    isRunning = false
    return
  end

  local project = SV:getProject()
  safeCall(function()
    project:newUndoRecord()
    return true
  end)

  local writeMode = getWidgetValue(writeModeValue, 0)
  local removedPoints = 0

  if writeMode == WRITE_REBUILD_TARGET then
    removedPoints = clearAllPoints(targetParam)
  elseif writeMode == WRITE_OVERWRITE_RANGES then
    removedPoints = clearRanges(targetParam, ranges)
  elseif writeMode ~= WRITE_APPEND_ONLY then
    removedPoints = clearRanges(targetParam, ranges)
  end

  local createdPoints, updatedPoints = writeGeneratedPoints(targetParam, points)
  local targetDisplayName = targetParamName
  if targetDefinition and targetDefinition.displayName then
    targetDisplayName = targetDefinition.displayName .. " (" .. targetParamName .. ")"
  end

  local summary = tr("映射完成。\n", "Mapping complete.\n")
    .. tr("目标参数: ", "Target parameter: ")
    .. targetDisplayName
    .. tr("\n选中音符: ", "\nSelected notes: ")
    .. #selectedNotes
    .. tr("\n采样点: ", "\nSampled points: ")
    .. pointStats.sampledPoints
    .. tr("\n写入点: ", "\nWritten points: ")
    .. #points
    .. tr("，新建 ", ", created ")
    .. createdPoints
    .. tr("，更新 ", ", updated ")
    .. updatedPoints
    .. tr("\n清理旧点: ", "\nRemoved old points: ")
    .. removedPoints

  if pointStats.collisions > 0 then
    summary = summary .. tr("\n合并同位置点: ", "\nMerged same-position points: ") .. pointStats.collisions
  end

  if pointStats.computedFallbacks > 0 then
    summary = summary
      .. tr("\n计算后音高缺失采样: ", "\nComputed-pitch fallback samples: ")
      .. pointStats.computedFallbacks
      .. tr("，已回退到轻量音高。", "; fell back to lightweight pitch.")
  end

  if safeCall(function()
    return currentGroup:isMain()
  end) == false then
    summary = summary
      .. tr(
        "\n\n注意: 参数写入当前音符组目标；如果该目标被多个引用复用，其他引用也会同步变化。",
        "\n\nWarning: Parameters are written to the current note group target. "
          .. "If the target is reused by multiple references, those references will change as well."
      )
  end

  showMessage(tr("完成", "Done"), summary)
  updateStatus()
  isRunning = false
end

local function initializePanel()
  if initialized then
    return
  end

  initialized = true
  languageValue = createWidgetValue(0)
  targetParamValue = createWidgetValue(0)
  customParamValue = createWidgetValue("")
  sourceModeValue = createWidgetValue(0)
  densityModeValue = createWidgetValue(0)
  writeModeValue = createWidgetValue(0)
  sampleIntervalValue = createWidgetValue(2)
  simplifyPercentValue = createWidgetValue(0.5)
  centerPitchValue = createWidgetValue(60)
  strengthValue = createWidgetValue(0.05)
  directionValue = createWidgetValue(0)
  runButtonValue = createWidgetValue(false)
  refreshButtonValue = createWidgetValue(false)
  statusValue = createWidgetValue("")

  setValueChangeCallback(runButtonValue, function()
    runPanel()
  end)

  setValueChangeCallback(refreshButtonValue, function()
    updateStatus()
  end)

  setValueChangeCallback(languageValue, function()
    updateStatus()
    safeCall(function()
      SV:refreshSidePanel()
      return true
    end)
  end)

  updateStatus()
end

local function comboRow(choices, value)
  return {
    type = "Container",
    columns = {
      {
        type = "ComboBox",
        choices = choices,
        value = value,
        width = 1.0,
      },
    },
  }
end

local function sliderRow(label, value, format, minValue, maxValue, interval)
  return {
    type = "Container",
    columns = {
      {
        type = "Slider",
        label = label,
        value = value,
        format = format,
        minValue = minValue,
        maxValue = maxValue,
        interval = interval,
        width = 1.0,
      },
    },
  }
end

function getSidePanelSectionState()
  initializePanel()

  return {
    title = "Pitch to Parameter",
    rows = {
      {
        type = "Label",
        text = tr("语言 / Language", "Language / 语言"),
      },
      {
        type = "Container",
        columns = {
          {
            type = "ComboBox",
            choices = { "中文", "English" },
            value = languageValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Label",
        text = tr("选择", "Selection"),
      },
      {
        type = "Container",
        columns = {
          {
            type = "TextBox",
            value = statusValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Label",
        text = tr("目标参数", "Target"),
      },
      comboRow(buildStaticParamLabels(), targetParamValue),
      {
        type = "Container",
        columns = {
          {
            type = "TextBox",
            value = customParamValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Label",
        text = tr("音高来源", "Source"),
      },
      comboRow({
        tr("轻量：音符音高 + pitchDelta", "Lightweight: note pitch + pitchDelta"),
        tr("仅跟随 pitchDelta", "PitchDelta only"),
        tr("计算后音高 (Studio 2)", "Computed pitch (Studio 2)"),
      }, sourceModeValue),
      comboRow({
        tr("智能精简", "Smart simplify"),
        tr("保留全部采样点", "Keep all samples"),
        tr("强制线性", "Force linear"),
      }, densityModeValue),
      comboRow({
        tr("覆盖选中音符范围", "Overwrite selected note ranges"),
        tr("仅追加/更新同位置点", "Append/update only"),
        tr("清空目标参数后重建", "Clear target parameter and rebuild"),
      }, writeModeValue),
      comboRow({
        tr("1/8 拍", "1/8 beat"),
        tr("1/16 拍", "1/16 beat"),
        tr("1/32 拍", "1/32 beat"),
        tr("1/64 拍", "1/64 beat"),
      }, sampleIntervalValue),
      sliderRow(
        tr("精简阈值 (% 参数范围)", "Simplify threshold (% parameter range)"),
        simplifyPercentValue,
        "%1.2f",
        0.0,
        5.0,
        0.05
      ),
      sliderRow(tr("参考中心音高", "Reference center pitch"), centerPitchValue, "%1.0f", 36, 96, 1),
      sliderRow(tr("映射强度", "Mapping strength"), strengthValue, "%1.2f", 0.01, 2.0, 0.01),
      comboRow({ tr("正向", "Normal"), tr("反向", "Inverted") }, directionValue),
      {
        type = "Container",
        columns = {
          {
            type = "Button",
            text = tr("刷新", "Refresh"),
            value = refreshButtonValue,
            width = 0.35,
          },
          {
            type = "Button",
            text = tr("运行", "Run"),
            value = runButtonValue,
            width = 0.65,
          },
        },
      },
    },
  }
end
