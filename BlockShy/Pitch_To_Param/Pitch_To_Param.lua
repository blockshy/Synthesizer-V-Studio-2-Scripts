function getClientInfo()
  return {
    name = "Pitch to Parameter",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 5,
    minEditorVersion = 65537,
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

local function getAvailableTargetParams(group)
  local params = {}

  for _, candidate in ipairs(TARGET_PARAM_CANDIDATES) do
    local param = getParameterSafe(group, candidate.typeName)
    if param then
      table.insert(params, {
        typeName = candidate.typeName,
        label = candidate.label,
      })
    end
  end

  return params
end

local function buildParamLabels(params)
  local labels = {}
  for _, param in ipairs(params) do
    table.insert(labels, param.label)
  end
  table.insert(labels, "自定义参数名 (Custom)")
  return labels
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

function main()
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)

  if #selectedNotes == 0 then
    SV:showMessageBox("提示", "请先选中需要处理的音符。")
    return
  end

  local currentGroup = editor:getCurrentGroup()
  if currentGroup == nil then
    SV:showMessageBox("错误", "未检测到当前音符组，请先选中一个轨道或音符组。")
    return
  end

  local groupTarget = currentGroup:getTarget()
  if groupTarget == nil then
    SV:showMessageBox("错误", "未检测到当前音符组目标。")
    return
  end

  local pitchDelta = getParameterSafe(groupTarget, "pitchDelta")
  if pitchDelta == nil then
    SV:showMessageBox("错误", "当前音符组没有可用的 pitchDelta 参数。")
    return
  end

  local availableParams = getAvailableTargetParams(groupTarget)
  if #availableParams == 0 then
    SV:showMessageBox("错误", "当前音符组没有可用的目标参数。")
    return
  end

  local totalPitch = 0
  for _, note in ipairs(selectedNotes) do
    totalPitch = totalPitch + note:getPitch()
  end
  local avgPitch = math.floor(totalPitch / #selectedNotes)

  local inputForm = {
    title = "音高映射 V5",
    message = "将选中音符的音高或弯音映射到目标参数曲线。默认会覆盖选中音符范围内的旧目标参数点。",
    buttons = "OkCancel",
    widgets = {
      {
        name = "targetParamIdx",
        type = "ComboBox",
        label = "目标参数",
        choices = buildParamLabels(availableParams),
        default = 0,
      },
      {
        name = "customParam",
        type = "TextBox",
        label = "自定义参数名 (可选)",
        default = "",
      },
      {
        name = "sourceMode",
        type = "ComboBox",
        label = "音高来源",
        choices = {
          "轻量：音符音高 + pitchDelta",
          "仅跟随 pitchDelta",
          "计算后音高 (Studio 2)",
        },
        default = 0,
      },
      {
        name = "densityMode",
        type = "ComboBox",
        label = "点密度",
        choices = {
          "智能精简",
          "保留全部采样点",
          "强制线性",
        },
        default = 0,
      },
      {
        name = "writeMode",
        type = "ComboBox",
        label = "写入模式",
        choices = {
          "覆盖选中音符范围",
          "仅追加/更新同位置点",
          "清空目标参数后重建",
        },
        default = 0,
      },
      {
        name = "sampleInterval",
        type = "ComboBox",
        label = "采样间隔",
        choices = { "1/8 拍", "1/16 拍", "1/32 拍", "1/64 拍" },
        default = 2,
      },
      {
        name = "simplifyPercent",
        type = "Slider",
        label = "精简阈值 (% 参数范围)",
        format = "%1.2f",
        minValue = 0.0,
        maxValue = 5.0,
        interval = 0.05,
        default = 0.5,
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
        maxValue = 2.0,
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

  local customParam = trim(result.answers.customParam)
  local targetParamName

  if customParam ~= "" then
    targetParamName = customParam
  elseif result.answers.targetParamIdx == #availableParams then
    SV:showMessageBox("错误", "选择自定义参数时必须填写参数名。")
    return
  else
    local targetParamOption = availableParams[result.answers.targetParamIdx + 1]
    targetParamName = targetParamOption.typeName
  end

  local targetParam = getParameterSafe(groupTarget, targetParamName)
  if targetParam == nil then
    SV:showMessageBox("错误", "目标参数不可用: " .. targetParamName)
    return
  end

  local targetMin, targetMax, targetDefinition = getParamRange(targetParam)
  local targetRange = targetMax - targetMin
  local sampleDenominator = SAMPLE_DENOMINATORS[result.answers.sampleInterval + 1] or 32
  local step = math.floor((SV.QUARTER or 705600000) / sampleDenominator)
  if step < 1 then
    step = 1
  end

  local simplifyThreshold = targetRange * ((result.answers.simplifyPercent or 0) / 100.0)
  local ranges = collectMergedRanges(selectedNotes)

  local context = {
    sourceMode = result.answers.sourceMode,
    densityMode = result.answers.densityMode,
    centerPitch = result.answers.centerPitch,
    strength = result.answers.strength,
    isInverted = (result.answers.direction == 1),
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
    SV:showMessageBox("提示", "没有生成任何参数点。")
    return
  end

  if context.sourceMode == SOURCE_MODE_COMPUTED and pointStats.computedFallbacks == pointStats.sampledPoints then
    SV:showMessageBox(
      "提示",
      "计算后音高尚未准备好，脚本未写入参数。请等待 Synthesizer V 完成音高计算后重试，或改用轻量音高来源。"
    )
    return
  end

  local project = SV:getProject()
  safeCall(function()
    project:newUndoRecord()
    return true
  end)

  local writeMode = result.answers.writeMode
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

  local summary = "映射完成。\n"
    .. "目标参数: "
    .. targetDisplayName
    .. "\n"
    .. "选中音符: "
    .. #selectedNotes
    .. "\n"
    .. "采样点: "
    .. pointStats.sampledPoints
    .. "\n"
    .. "写入点: "
    .. #points
    .. "，新建 "
    .. createdPoints
    .. "，更新 "
    .. updatedPoints
    .. "\n"
    .. "清理旧点: "
    .. removedPoints

  if pointStats.collisions > 0 then
    summary = summary .. "\n合并同位置点: " .. pointStats.collisions
  end

  if pointStats.computedFallbacks > 0 then
    summary = summary
      .. "\n计算后音高缺失采样: "
      .. pointStats.computedFallbacks
      .. "，已回退到轻量音高。"
  end

  if safeCall(function()
    return currentGroup:isMain()
  end) == false then
    summary = summary
      .. "\n\n注意: 参数写入当前音符组目标；如果该目标被多个引用复用，其他引用也会同步变化。"
  end

  SV:showMessageBox("完成", summary)
  SV:finish()
end
