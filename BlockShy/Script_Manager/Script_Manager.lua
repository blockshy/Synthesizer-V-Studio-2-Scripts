function getClientInfo()
  return {
    name = "BlockShy Script Manager",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 4,
    minEditorVersion = 131330,
    type = "SidePanelSection",
  }
end

local SCRIPT_TITLE = "BlockShy Script Manager"
local MANAGED_DIRECTORY = "BlockShy"

local SCRIPT_ENTRIES = {
  -- MANAGED_SCRIPT_ENTRIES_START
  {
    name = "BPM Rescaler",
    folder = "BPM_Rescaler",
    file = "BPM_Rescaler.lua",
    sourceKey = "BPM_Rescaler",
    version = "V6",
    requires = "在 Synthesizer V Studio 2 中选中要处理的轨道或音符组。",
    summary = "用于修复 MIDI/轨道原始 BPM 与当前工程 BPM 不一致导致的音符长度和参数曲线错位问题。脚本会按 `当"
      .. "前 BPM / 原始 BPM` 的比例缩放当前音符组目标内的数据。",
    usage = "在 Synthesizer V Studio 2 中选中要处理的轨道或音符组。\
运行 `BPM Rescaler`。\
确认“当前工程 BPM”，并输入 MIDI/轨道导入前的“原始 BPM”。\
选择缩放锚点：",
  },
  {
    name = "Crying Effect",
    folder = "Crying_Effect",
    file = "Crying_Effect.lua",
    sourceKey = "Crying_Effect",
    version = "V6",
    requires = "在钢琴窗中选中一个或多个音符。",
    summary = "为选中音符生成哭腔风格的表现参数。新版脚本提供可直接使用的哭腔预设，并会按预设写入颤音、气声、张力和音高哭腔曲线"
      .. "。",
    usage = "在钢琴窗中选中一个或多个音符。\
运行 `Crying Effect`。\
选择哭腔预设。默认“自然哭腔（推荐）”可以直接使用。\
勾选需要生成的模块：颤音包络、气声、张力、尾部下坠。",
  },
  {
    name = "Flatten Pitch Curve",
    folder = "Flatten_Pitch_Curve",
    file = "Flatten_Pitch_Curve.lua",
    sourceKey = "Flatten_Pitch_Curve",
    version = "V2",
    requires = "在钢琴窗中选中需要抹平音高曲线的音符，或在轨道中选中音符组。",
    summary = "将选中音符或选中音符组范围内的音高曲线抹平。脚本会为每个目标音符绘制一条完全水平的 Synthesizer V "
      .. "Studio 2 Pitch Control Curve，使音高按音符本身的 MIDI pitch 保持水平。",
    usage = "在钢琴窗中选中需要抹平音高曲线的音符，或在轨道中选中音符组。\
运行 `Flatten Pitch Curve`。\
选择处理范围：选中音符、选中音符组，或两者一起处理。\
保持“绘制水平 Studio 2 Pitch Control Curve”启用。",
  },
  {
    name = "Pitch to Parameter",
    folder = "Pitch_To_Param",
    file = "Pitch_To_Param.lua",
    sourceKey = "Pitch_To_Param",
    version = "V5",
    requires = "在钢琴窗中选中需要处理的音符。",
    summary = "将选中音符的音高信息映射到目标参数曲线，用于把旋律音高、弯音或 Synthesizer V Studio 2 计"
      .. "算后的音高转换为张力、气声、性别、清浊、颤音包络、响度等表现参数。",
    usage = "在钢琴窗中选中需要处理的音符。\
运行 `Pitch to Parameter`。\
选择目标参数，或填写自定义参数名。\
选择音高来源：",
  },
  -- MANAGED_SCRIPT_ENTRIES_END
}

local EMBEDDED_SCRIPT_SOURCES = {
  -- EMBEDDED_SOURCES_START
  ["BPM_Rescaler"] = [====[
function getClientInfo()
  return {
    name = "BPM Rescaler",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 6,
    minEditorVersion = 65537,
  }
end

local PARAM_TYPES = {
  "pitchDelta",
  "vibratoEnv",
  "loudness",
  "tension",
  "breathiness",
  "voicing",
  "gender",
  "toneShift",
}

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end
  return nil
end

local function formatNumber(value)
  local formatted = string.format("%.3f", value)
  formatted = formatted:gsub("0+$", "")
  formatted = formatted:gsub("%.$", "")
  return formatted
end

local function roundBlick(value)
  if value >= 0 then
    return math.floor(value + 0.5)
  end
  return math.ceil(value - 0.5)
end

local function scaleBlick(blick, anchor, ratio)
  local scaled = anchor + roundBlick((blick - anchor) * ratio)
  if scaled < 0 then
    return 0
  end
  return scaled
end

local function getGroupOnset(groupRef)
  local onset = safeCall(function()
    return groupRef:getOnset()
  end)

  if type(onset) == "number" then
    return onset
  end

  return 0
end

local function getTempoAt(timeAxis, blick)
  local tempoMark = safeCall(function()
    return timeAxis:getTempoMarkAt(blick)
  end)

  if tempoMark and tempoMark.bpm then
    return tempoMark.bpm
  end

  return 120
end

local function getTempoMarkCount(timeAxis)
  local tempoMarks = safeCall(function()
    return timeAxis:getAllTempoMarks()
  end)

  if type(tempoMarks) == "table" then
    return #tempoMarks
  end

  return 0
end

local function getFirstNoteOnset(group)
  local numNotes = group:getNumNotes()
  local firstOnset = nil

  for i = 1, numNotes do
    local note = group:getNote(i)
    local onset = note:getOnset()
    if firstOnset == nil or onset < firstOnset then
      firstOnset = onset
    end
  end

  return firstOnset or 0
end

local function collectNotes(group)
  local notes = {}
  local numNotes = group:getNumNotes()

  for i = 1, numNotes do
    table.insert(notes, group:getNote(i))
  end

  table.sort(notes, function(a, b)
    return a:getOnset() < b:getOnset()
  end)

  return notes
end

local function setNoteTimeRange(note, onset, duration)
  local ok = safeCall(function()
    note:setTimeRange(onset, duration)
    return true
  end)

  if ok then
    return
  end

  note:setOnset(onset)
  note:setDuration(duration)
end

local function rescaleNotes(group, anchor, ratio)
  local notes = collectNotes(group)

  for _, note in ipairs(notes) do
    local oldOnset = note:getOnset()
    local oldEnd = note:getEnd()
    local newOnset = scaleBlick(oldOnset, anchor, ratio)
    local newEnd = scaleBlick(oldEnd, anchor, ratio)
    local newDuration = newEnd - newOnset

    if newDuration < 1 then
      newDuration = 1
    end

    setNoteTimeRange(note, newOnset, newDuration)
  end

  return #notes
end

local function rebuildAutomation(track, anchor, ratio)
  local points = safeCall(function()
    return track:getAllPoints()
  end)

  if type(points) ~= "table" or #points == 0 then
    return 0, 0, 0
  end

  table.sort(points, function(a, b)
    return a[1] < b[1]
  end)

  local remapped = {}
  local collisions = 0

  for _, point in ipairs(points) do
    local oldBlick = point[1]
    local value = point[2]
    local newBlick = scaleBlick(oldBlick, anchor, ratio)

    if remapped[newBlick] ~= nil then
      collisions = collisions + 1
    end

    remapped[newBlick] = value
  end

  local entries = {}
  for blick, value in pairs(remapped) do
    table.insert(entries, { blick = blick, value = value })
  end

  table.sort(entries, function(a, b)
    return a.blick < b.blick
  end)

  local cleared = safeCall(function()
    track:removeAll()
    return true
  end)

  if not cleared then
    return #points, 0, collisions
  end

  for _, entry in ipairs(entries) do
    track:add(entry.blick, entry.value)
  end

  return #points, #entries, collisions
end

local function rescaleAutomation(group, anchor, ratio)
  local stats = {
    tracks = 0,
    points = 0,
    keptPoints = 0,
    collisions = 0,
  }

  for _, typeName in ipairs(PARAM_TYPES) do
    local track = safeCall(function()
      return group:getParameter(typeName)
    end)

    if track then
      local pointCount, keptCount, collisions = rebuildAutomation(track, anchor, ratio)
      if pointCount > 0 then
        stats.tracks = stats.tracks + 1
        stats.points = stats.points + pointCount
        stats.keptPoints = stats.keptPoints + keptCount
        stats.collisions = stats.collisions + collisions
      end
    end
  end

  return stats
end

local function rescalePitchControl(control, anchor, ratio)
  local oldPosition = safeCall(function()
    return control:getPosition()
  end)

  if type(oldPosition) ~= "number" then
    return 0, 0
  end

  local newPosition = scaleBlick(oldPosition, anchor, ratio)
  local curvePoints = safeCall(function()
    return control:getPoints()
  end)

  if type(curvePoints) == "table" then
    local newPoints = {}

    for _, point in ipairs(curvePoints) do
      local oldLocalTime = point[1]
      local oldGlobalTime = oldPosition + oldLocalTime
      local newGlobalTime = scaleBlick(oldGlobalTime, anchor, ratio)
      table.insert(newPoints, { newGlobalTime - newPosition, point[2] })
    end

    table.sort(newPoints, function(a, b)
      return a[1] < b[1]
    end)

    safeCall(function()
      control:setPoints(newPoints)
      return true
    end)

    safeCall(function()
      control:setPosition(newPosition)
      return true
    end)

    return 1, #curvePoints
  end

  safeCall(function()
    control:setPosition(newPosition)
    return true
  end)

  return 1, 0
end

local function rescalePitchControls(group, anchor, ratio)
  local numPitchControls = safeCall(function()
    return group:getNumPitchControls()
  end)

  if type(numPitchControls) ~= "number" or numPitchControls <= 0 then
    return { objects = 0, curvePoints = 0 }
  end

  local controls = {}
  for i = 1, numPitchControls do
    local control = safeCall(function()
      return group:getPitchControl(i)
    end)

    if control then
      table.insert(controls, control)
    end
  end

  local stats = {
    objects = 0,
    curvePoints = 0,
  }

  for _, control in ipairs(controls) do
    local objectCount, curvePointCount = rescalePitchControl(control, anchor, ratio)
    stats.objects = stats.objects + objectCount
    stats.curvePoints = stats.curvePoints + curvePointCount
  end

  return stats
end

function main()
  local editor = SV:getMainEditor()
  local project = SV:getProject()
  local timeAxis = project:getTimeAxis()
  local currentGroup = editor:getCurrentGroup()

  if currentGroup == nil then
    SV:showMessageBox("错误", "未检测到当前音符组，请先选中一个轨道或音符组。")
    return
  end

  local groupTarget = currentGroup:getTarget()

  if groupTarget == nil then
    SV:showMessageBox("错误", "未检测到选中的轨道或音符组，请先选中一个轨道。")
    return
  end

  local groupOnset = getGroupOnset(currentGroup)
  local detectedBPM = getTempoAt(timeAxis, groupOnset)
  local tempoMarkCount = getTempoMarkCount(timeAxis)
  local tempoWarning = ""

  if tempoMarkCount > 1 then
    tempoWarning =
      "\n\n检测到工程中有多个 BPM 标记。本脚本只按单一比例缩放，不会执行完整 tempo map 转换。"
  end

  local inputForm = {
    title = "BPM 缩放修复",
    message = "将缩放当前音符组目标内的音符、参数点和 Studio 2 音高控制。\n当前引用位置 BPM: "
      .. formatNumber(detectedBPM)
      .. tempoWarning,
    buttons = "OkCancel",
    widgets = {
      {
        name = "currentBpm",
        type = "TextBox",
        label = "当前工程 BPM (Current BPM)",
        default = formatNumber(detectedBPM),
      },
      {
        name = "originalBpm",
        type = "TextBox",
        label = "原始 MIDI/轨道 BPM (Original BPM)",
        default = formatNumber(detectedBPM / 2),
      },
      {
        name = "anchorMode",
        type = "ComboBox",
        label = "缩放锚点 (Anchor)",
        choices = {
          "音符组内部 0 位置",
          "第一个音符起点",
        },
        default = 0,
      },
      {
        name = "processAutomation",
        type = "CheckBox",
        text = "同时缩放参数曲线",
        default = true,
      },
      {
        name = "processPitchControls",
        type = "CheckBox",
        text = "同时缩放 Studio 2 音高控制点/曲线",
        default = true,
      },
    },
  }

  local result = SV:showCustomDialog(inputForm)
  if not result or not result.status then
    return
  end

  local currentBPM = tonumber(result.answers.currentBpm)
  local originalBPM = tonumber(result.answers.originalBpm)

  if currentBPM == nil or currentBPM <= 0 or originalBPM == nil or originalBPM <= 0 then
    SV:showMessageBox("错误", "请输入有效的 BPM 数值。")
    return
  end

  local ratio = currentBPM / originalBPM
  local anchor = 0
  local anchorLabel = "音符组内部 0 位置"

  if result.answers.anchorMode == 1 then
    anchor = getFirstNoteOnset(groupTarget)
    anchorLabel = "第一个音符起点"
  end

  local noteCount = rescaleNotes(groupTarget, anchor, ratio)
  local automationStats = { tracks = 0, points = 0, keptPoints = 0, collisions = 0 }
  local pitchStats = { objects = 0, curvePoints = 0 }

  if result.answers.processAutomation then
    automationStats = rescaleAutomation(groupTarget, anchor, ratio)
  end

  if result.answers.processPitchControls then
    pitchStats = rescalePitchControls(groupTarget, anchor, ratio)
  end

  local summary = "缩放完成。\n"
    .. "比例: "
    .. formatNumber(ratio)
    .. " ("
    .. formatNumber(originalBPM)
    .. " -> "
    .. formatNumber(currentBPM)
    .. " BPM)\n"
    .. "锚点: "
    .. anchorLabel
    .. "\n"
    .. "音符: "
    .. noteCount
    .. "\n"
    .. "参数曲线: "
    .. automationStats.tracks
    .. " 条 / "
    .. automationStats.points
    .. " 点"

  if automationStats.collisions > 0 then
    summary = summary .. "，合并冲突 " .. automationStats.collisions .. " 点"
  end

  summary = summary
    .. "\n音高控制: "
    .. pitchStats.objects
    .. " 个对象 / "
    .. pitchStats.curvePoints
    .. " 个曲线点"

  if tempoMarkCount > 1 then
    summary = summary .. "\n\n提示: 工程中存在多个 BPM 标记，本次按单一比例处理。"
  end

  local isMainGroup = safeCall(function()
    return currentGroup:isMain()
  end)

  if isMainGroup == false then
    summary = summary
      .. "\n\n注意: 当前脚本修改的是音符组目标。如果该目标被多个引用复用，其他引用也会同步变化。"
  end

  SV:showMessageBox("完成", summary)
  SV:finish()
end
]====],
  ["Crying_Effect"] = [====[
function getClientInfo()
  return {
    name = "Crying Effect",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 6,
    minEditorVersion = 65537,
  }
end

local WRITE_OVERWRITE_RANGES = 0
local WRITE_REBUILD_ENABLED = 2

local PARAM_DEFS = {
  vibratoEnv = { label = "颤音包络", defaultMin = 0.0, defaultMax = 2.0 },
  breathiness = { label = "气声", defaultMin = -1.0, defaultMax = 1.0 },
  tension = { label = "张力", defaultMin = -1.0, defaultMax = 1.0 },
  pitchDelta = { label = "音高偏移", defaultMin = -1200.0, defaultMax = 1200.0 },
}

local CRY_PRESETS = {
  {
    label = "轻微哽咽",
    intensityScale = 0.75,
    attackPercent = 16,
    peakPercent = 48,
    releasePercent = 86,
    vibratoPeak = 0.16,
    vibratoTail = 0.08,
    breathPeak = 0.18,
    breathTail = 0.09,
    tensionPeak = 0.22,
    tensionTail = 0.08,
    randomAmount = 0.05,
    pitchCatch = 16,
    pitchDip = 8,
    wobbleDepth = 9,
    wobbleCycles = 1,
    dropStartPercent = 82,
    dropDepth = 65,
    dropLastNotesOnly = false,
  },
  {
    label = "自然哭腔（推荐）",
    intensityScale = 1.0,
    attackPercent = 12,
    peakPercent = 46,
    releasePercent = 88,
    vibratoPeak = 0.28,
    vibratoTail = 0.14,
    breathPeak = 0.32,
    breathTail = 0.16,
    tensionPeak = 0.36,
    tensionTail = 0.14,
    randomAmount = 0.09,
    pitchCatch = 28,
    pitchDip = 14,
    wobbleDepth = 16,
    wobbleCycles = 2,
    dropStartPercent = 76,
    dropDepth = 120,
    dropLastNotesOnly = false,
  },
  {
    label = "明显哭腔",
    intensityScale = 1.15,
    attackPercent = 10,
    peakPercent = 42,
    releasePercent = 90,
    vibratoPeak = 0.42,
    vibratoTail = 0.22,
    breathPeak = 0.44,
    breathTail = 0.24,
    tensionPeak = 0.52,
    tensionTail = 0.22,
    randomAmount = 0.13,
    pitchCatch = 42,
    pitchDip = 22,
    wobbleDepth = 24,
    wobbleCycles = 2,
    dropStartPercent = 72,
    dropDepth = 175,
    dropLastNotesOnly = false,
  },
  {
    label = "强烈哭腔",
    intensityScale = 1.3,
    attackPercent = 8,
    peakPercent = 38,
    releasePercent = 92,
    vibratoPeak = 0.58,
    vibratoTail = 0.3,
    breathPeak = 0.58,
    breathTail = 0.32,
    tensionPeak = 0.72,
    tensionTail = 0.3,
    randomAmount = 0.18,
    pitchCatch = 62,
    pitchDip = 34,
    wobbleDepth = 36,
    wobbleCycles = 3,
    dropStartPercent = 68,
    dropDepth = 260,
    dropLastNotesOnly = false,
  },
  {
    label = "尾音哽咽",
    intensityScale = 1.05,
    attackPercent = 22,
    peakPercent = 66,
    releasePercent = 96,
    vibratoPeak = 0.34,
    vibratoTail = 0.3,
    breathPeak = 0.36,
    breathTail = 0.32,
    tensionPeak = 0.42,
    tensionTail = 0.28,
    randomAmount = 0.08,
    pitchCatch = 16,
    pitchDip = 10,
    wobbleDepth = 22,
    wobbleCycles = 2,
    dropStartPercent = 70,
    dropDepth = 220,
    dropLastNotesOnly = true,
  },
}

local CUSTOM_PRESET_INDEX = #CRY_PRESETS

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end
  return nil
end

local function clamp(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function roundBlick(value)
  return math.floor(value + 0.5)
end

local function buildPresetChoices()
  local choices = {}

  for _, preset in ipairs(CRY_PRESETS) do
    table.insert(choices, preset.label)
  end

  table.insert(choices, "自定义（使用下方高级参数）")
  return choices
end

local function getParameterSafe(group, typeName)
  return safeCall(function()
    return group:getParameter(typeName)
  end)
end

local function getParamRange(param, typeName)
  local definition = safeCall(function()
    return param:getDefinition()
  end)

  if type(definition) == "table" and type(definition.range) == "table" then
    local minValue = definition.range[1] or definition.range.min
    local maxValue = definition.range[2] or definition.range.max
    if type(minValue) == "number" and type(maxValue) == "number" then
      return minValue, maxValue
    end
  end

  local fallback = PARAM_DEFS[typeName]
  if fallback then
    return fallback.defaultMin, fallback.defaultMax
  end

  return -1.0, 1.0
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
    local startPos = note:getOnset()
    local endPos = note:getEnd()
    if endPos > startPos then
      table.insert(ranges, {
        start = startPos,
        finish = endPos,
      })
    end
  end

  table.sort(ranges, function(a, b)
    return a.start < b.start
  end)

  local merged = {}
  for _, range in ipairs(ranges) do
    local last = merged[#merged]
    if last and range.start <= last.finish then
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

local function getLastNoteEndsByRange(notes, ranges)
  local ends = {}

  for rangeIndex, range in ipairs(ranges) do
    local lastEnd = nil
    for _, note in ipairs(notes) do
      local noteEnd = note:getEnd()
      if note:getOnset() >= range.start and noteEnd <= range.finish then
        if lastEnd == nil or noteEnd > lastEnd then
          lastEnd = noteEnd
        end
      end
    end
    ends[rangeIndex] = lastEnd
  end

  return ends
end

local function isLastNoteInMergedRange(note, ranges, rangeLastEnds)
  local onset = note:getOnset()
  local noteEnd = note:getEnd()

  for i, range in ipairs(ranges) do
    if onset >= range.start and noteEnd <= range.finish then
      return noteEnd == rangeLastEnds[i]
    end
  end

  return false
end

local function notePosition(note, percent)
  local onset = note:getOnset()
  local duration = note:getDuration()
  return onset + roundBlick(duration * (percent / 100.0))
end

local function addGeneratedPoint(task, blick, value)
  local clipped = clamp(value, task.minValue, task.maxValue)
  if task.points[blick] ~= nil then
    task.collisions = task.collisions + 1
  end
  task.points[blick] = clipped
end

local function addEnvelopePoint(task, note, percent, value)
  addGeneratedPoint(task, notePosition(note, percent), value)
end

local function sortedPointEntries(pointMap)
  local entries = {}

  for blick, value in pairs(pointMap) do
    table.insert(entries, {
      blick = blick,
      value = value,
    })
  end

  table.sort(entries, function(a, b)
    return a.blick < b.blick
  end)

  return entries
end

local function clearRanges(param, ranges)
  local removed = 0

  for _, range in ipairs(ranges) do
    local oldPoints = param:getPoints(range.start, range.finish)
    removed = removed + #oldPoints
    if #oldPoints > 0 then
      param:remove(range.start, range.finish)
    end
  end

  return removed
end

local function clearAllPoints(param)
  local oldPoints = param:getAllPoints()
  local removed = #oldPoints

  if removed > 0 then
    param:removeAll()
  end

  return removed
end

local function writePoints(param, entries)
  local created = 0
  local updated = 0

  for _, point in ipairs(entries) do
    local didCreate = param:add(point.blick, point.value)
    if didCreate then
      created = created + 1
    else
      updated = updated + 1
    end
  end

  return created, updated
end

local function createTask(typeName, param)
  local minValue, maxValue = getParamRange(param, typeName)
  return {
    typeName = typeName,
    label = PARAM_DEFS[typeName].label,
    param = param,
    minValue = minValue,
    maxValue = maxValue,
    points = {},
    collisions = 0,
    generated = 0,
    removed = 0,
    created = 0,
    updated = 0,
  }
end

local function getEnabledTasks(groupTarget, options)
  local tasks = {}
  local skipped = {}

  local function maybeAdd(enabled, typeName)
    if not enabled then
      return
    end

    local param = getParameterSafe(groupTarget, typeName)
    if param then
      tasks[typeName] = createTask(typeName, param)
    else
      table.insert(skipped, PARAM_DEFS[typeName].label .. " (" .. typeName .. ")")
    end
  end

  maybeAdd(options.addVibrato, "vibratoEnv")
  maybeAdd(options.addBreath, "breathiness")
  maybeAdd(options.addTension, "tension")
  maybeAdd(options.addPitchDrop, "pitchDelta")

  return tasks, skipped
end

local function seedRandom(fixedRandom)
  if fixedRandom then
    math.randomseed(1357911)
    return
  end

  safeCall(function()
    math.randomseed(os.time())
    return true
  end)
end

local function randomJitter(amount)
  if amount <= 0 then
    return 0
  end
  return (math.random() - 0.5) * 2.0 * amount
end

local function resolveOptions(answers)
  local presetIndex = answers.preset or 1
  local intensity = answers.intensity or 1.0
  local preset = CRY_PRESETS[presetIndex + 1]

  local options = {
    presetLabel = "自定义",
    intensity = intensity,
    writeMode = answers.writeMode,
    addVibrato = answers.addVibrato,
    addBreath = answers.addBreath,
    addTension = answers.addTension,
    addPitchDrop = answers.addPitchDrop,
    attackPercent = answers.attackPercent,
    peakPercent = answers.peakPercent,
    releasePercent = answers.releasePercent,
    randomAmount = answers.randomAmount,
    fixedRandom = answers.fixedRandom,
    vibratoPeak = 0.32,
    vibratoTail = 0.18,
    breathPeak = 0.42,
    breathTail = 0.22,
    tensionPeak = 0.42,
    tensionTail = 0.18,
    pitchCatch = (answers.dropDepth or 150) * 0.22,
    pitchDip = (answers.dropDepth or 150) * 0.12,
    wobbleDepth = (answers.dropDepth or 150) * 0.12,
    wobbleCycles = 2,
    dropStartPercent = answers.dropStartPercent,
    dropDepth = answers.dropDepth,
    dropLastNotesOnly = answers.dropLastNotesOnly,
    restorePitch = answers.restorePitch,
  }

  if presetIndex ~= CUSTOM_PRESET_INDEX and preset then
    options.presetLabel = preset.label
    options.intensity = intensity * preset.intensityScale
    options.attackPercent = preset.attackPercent
    options.peakPercent = preset.peakPercent
    options.releasePercent = preset.releasePercent
    options.randomAmount = preset.randomAmount * intensity
    options.vibratoPeak = preset.vibratoPeak
    options.vibratoTail = preset.vibratoTail
    options.breathPeak = preset.breathPeak
    options.breathTail = preset.breathTail
    options.tensionPeak = preset.tensionPeak
    options.tensionTail = preset.tensionTail
    options.pitchCatch = preset.pitchCatch
    options.pitchDip = preset.pitchDip
    options.wobbleDepth = preset.wobbleDepth
    options.wobbleCycles = preset.wobbleCycles
    options.dropStartPercent = preset.dropStartPercent
    options.dropDepth = preset.dropDepth
    options.dropLastNotesOnly = preset.dropLastNotesOnly or answers.dropLastNotesOnly
  end

  return options
end

local function normalizeEnvelopePositions(options)
  if options.attackPercent < 0 then
    options.attackPercent = 0
  end
  if options.releasePercent > 100 then
    options.releasePercent = 100
  end
  if options.peakPercent < options.attackPercent then
    options.peakPercent = options.attackPercent
  end
  if options.releasePercent < options.peakPercent then
    options.releasePercent = options.peakPercent
  end
end

local function buildVibratoEnvelope(task, note, options)
  addEnvelopePoint(task, note, 0, 1.0)
  addEnvelopePoint(task, note, options.attackPercent, 1.0 + (options.vibratoPeak * 0.35 * options.intensity))
  addEnvelopePoint(task, note, options.peakPercent, 1.0 + (options.vibratoPeak * options.intensity))
  addEnvelopePoint(task, note, options.releasePercent, 1.0 + (options.vibratoTail * options.intensity))
  addEnvelopePoint(task, note, 100, 1.0)
end

local function buildBreathEnvelope(task, note, options)
  addEnvelopePoint(task, note, 0, 0.0)
  addEnvelopePoint(task, note, options.attackPercent, options.breathPeak * 0.35 * options.intensity)
  addEnvelopePoint(task, note, options.peakPercent, options.breathPeak * options.intensity)
  addEnvelopePoint(task, note, options.releasePercent, options.breathTail * options.intensity)
  addEnvelopePoint(task, note, 100, 0.0)
end

local function buildTensionEnvelope(task, note, options)
  addEnvelopePoint(task, note, 0, 0.0)
  addEnvelopePoint(
    task,
    note,
    options.attackPercent,
    (options.tensionPeak * 0.35 * options.intensity) + randomJitter(options.randomAmount * 0.5)
  )
  addEnvelopePoint(
    task,
    note,
    options.peakPercent,
    (options.tensionPeak * options.intensity) + randomJitter(options.randomAmount)
  )
  addEnvelopePoint(
    task,
    note,
    options.releasePercent,
    (options.tensionTail * options.intensity) + randomJitter(options.randomAmount * 0.6)
  )
  addEnvelopePoint(task, note, 100, 0.0)
end

local function addPitchOffsetPoint(task, blick, offset)
  local baseValue = task.param:get(blick)
  addGeneratedPoint(task, blick, baseValue + offset)
end

local function addPitchOffsetAtPercent(task, note, percent, offset)
  addPitchOffsetPoint(task, notePosition(note, percent), offset)
end

local function buildPitchGesture(task, note, options, shouldDropTail)
  local onset = note:getOnset()
  local duration = note:getDuration()
  local dropStart = onset + roundBlick(duration * (options.dropStartPercent / 100.0))
  local dropEnd = note:getEnd()

  addPitchOffsetPoint(task, onset, 0)

  if options.pitchCatch > 0 then
    addPitchOffsetAtPercent(task, note, math.max(6, options.attackPercent), options.pitchCatch * options.intensity)
  end

  if options.pitchDip > 0 then
    local dipPercent = math.min(options.peakPercent, options.attackPercent + 18)
    addPitchOffsetAtPercent(task, note, dipPercent, -options.pitchDip * options.intensity)
  end

  if options.wobbleDepth > 0 and options.wobbleCycles > 0 then
    local wobbleStart = math.max(options.peakPercent, options.attackPercent + 20)
    local wobbleEnd = math.max(wobbleStart + 1, options.dropStartPercent - 4)
    local steps = options.wobbleCycles * 2

    for i = 1, steps do
      local ratio = i / steps
      local percent = wobbleStart + ((wobbleEnd - wobbleStart) * ratio)
      local polarity = 1
      if i % 2 == 0 then
        polarity = -1
      end
      local fade = 1.0 - (ratio * 0.35)
      addPitchOffsetAtPercent(task, note, percent, polarity * options.wobbleDepth * options.intensity * fade)
    end
  end

  addPitchOffsetPoint(task, dropStart, 0)

  if shouldDropTail then
    addPitchOffsetPoint(task, dropEnd, -options.dropDepth * options.intensity)
  else
    addPitchOffsetPoint(task, dropEnd, 0)
  end

  if shouldDropTail and options.restorePitch then
    local restoreOffset = math.floor((SV.QUARTER or 705600000) / 64)
    if restoreOffset < 1 then
      restoreOffset = 1
    end
    addPitchOffsetPoint(task, dropEnd + restoreOffset, 0)
  end
end

local function buildEffectPoints(notes, ranges, tasks, options)
  seedRandom(options.fixedRandom)
  normalizeEnvelopePositions(options)

  local rangeLastEnds = getLastNoteEndsByRange(notes, ranges)
  local processedPitchDrops = 0

  for _, note in ipairs(notes) do
    if tasks.vibratoEnv then
      buildVibratoEnvelope(tasks.vibratoEnv, note, options)
    end

    if tasks.breathiness then
      buildBreathEnvelope(tasks.breathiness, note, options)
    end

    if tasks.tension then
      buildTensionEnvelope(tasks.tension, note, options)
    end

    if tasks.pitchDelta then
      local shouldDropTail = not options.dropLastNotesOnly or isLastNoteInMergedRange(note, ranges, rangeLastEnds)
      buildPitchGesture(tasks.pitchDelta, note, options, shouldDropTail)
      if shouldDropTail then
        processedPitchDrops = processedPitchDrops + 1
      end
    end
  end

  return processedPitchDrops
end

local function applyWriteMode(tasks, ranges, writeMode)
  for _, task in pairs(tasks) do
    if writeMode == WRITE_REBUILD_ENABLED then
      task.removed = clearAllPoints(task.param)
    elseif writeMode == WRITE_OVERWRITE_RANGES then
      task.removed = clearRanges(task.param, ranges)
    end
  end
end

local function writeAllTasks(tasks)
  for _, task in pairs(tasks) do
    local entries = sortedPointEntries(task.points)
    task.generated = #entries
    task.created, task.updated = writePoints(task.param, entries)
  end
end

local function countTasks(tasks)
  local count = 0
  for _ in pairs(tasks) do
    count = count + 1
  end
  return count
end

local function buildSummary(noteCount, taskCount, processedPitchDrops, tasks, skipped, options)
  local totalGenerated = 0
  local totalRemoved = 0
  local totalCreated = 0
  local totalUpdated = 0
  local totalCollisions = 0

  for _, task in pairs(tasks) do
    totalGenerated = totalGenerated + task.generated
    totalRemoved = totalRemoved + task.removed
    totalCreated = totalCreated + task.created
    totalUpdated = totalUpdated + task.updated
    totalCollisions = totalCollisions + task.collisions
  end

  local summary = "哭腔参数已生成。\n"
    .. "预设: "
    .. options.presetLabel
    .. "\n"
    .. "处理音符: "
    .. noteCount
    .. "\n启用参数: "
    .. taskCount
    .. "\n生成点: "
    .. totalGenerated
    .. "，新建 "
    .. totalCreated
    .. "，更新 "
    .. totalUpdated
    .. "\n清理旧点: "
    .. totalRemoved

  if processedPitchDrops > 0 then
    summary = summary .. "\n尾部下坠音符: " .. processedPitchDrops
  end

  if totalCollisions > 0 then
    summary = summary .. "\n合并同位置点: " .. totalCollisions
  end

  if #skipped > 0 then
    summary = summary .. "\n跳过不可用参数: " .. table.concat(skipped, ", ")
  end

  return summary
end

function main()
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)

  if #selectedNotes == 0 then
    SV:showMessageBox("提示", "请先在钢琴窗中选中一个或多个音符。")
    return
  end

  local inputForm = {
    title = "自动哭腔参数设置 V6",
    message = "选择预设即可直接生成哭腔。自定义预设会使用下方高级包络和下坠参数。",
    buttons = "OkCancel",
    widgets = {
      {
        name = "preset",
        type = "ComboBox",
        label = "哭腔预设",
        choices = buildPresetChoices(),
        default = 1,
      },
      {
        name = "intensity",
        type = "Slider",
        label = "预设强度倍率",
        format = "%1.1f",
        minValue = 0.5,
        maxValue = 1.6,
        interval = 0.1,
        default = 1.0,
      },
      {
        name = "writeMode",
        type = "ComboBox",
        label = "写入模式",
        choices = {
          "覆盖选中音符范围",
          "仅追加/更新同位置点",
          "清空已启用参数后重建",
        },
        default = 0,
      },
      {
        name = "addVibrato",
        type = "CheckBox",
        text = "添加颤音包络",
        default = true,
      },
      {
        name = "addBreath",
        type = "CheckBox",
        text = "添加气声",
        default = true,
      },
      {
        name = "addTension",
        type = "CheckBox",
        text = "添加张力",
        default = true,
      },
      {
        name = "addPitchDrop",
        type = "CheckBox",
        text = "添加音高哭腔/尾部下坠",
        default = true,
      },
      {
        name = "attackPercent",
        type = "Slider",
        label = "起势位置 (%)",
        format = "%1.0f",
        minValue = 0,
        maxValue = 40,
        interval = 1,
        default = 12,
      },
      {
        name = "peakPercent",
        type = "Slider",
        label = "峰值位置 (%)",
        format = "%1.0f",
        minValue = 20,
        maxValue = 80,
        interval = 1,
        default = 45,
      },
      {
        name = "releasePercent",
        type = "Slider",
        label = "回落位置 (%)",
        format = "%1.0f",
        minValue = 60,
        maxValue = 100,
        interval = 1,
        default = 88,
      },
      {
        name = "randomAmount",
        type = "Slider",
        label = "张力随机量",
        format = "%1.2f",
        minValue = 0,
        maxValue = 0.4,
        interval = 0.01,
        default = 0.12,
      },
      {
        name = "fixedRandom",
        type = "CheckBox",
        text = "固定随机结果",
        default = true,
      },
      {
        name = "dropStartPercent",
        type = "Slider",
        label = "下坠开始位置 (%)",
        format = "%1.0f",
        minValue = 40,
        maxValue = 95,
        interval = 1,
        default = 75,
      },
      {
        name = "dropDepth",
        type = "Slider",
        label = "下坠深度 (cents)",
        format = "%1.0f",
        minValue = 20,
        maxValue = 400,
        interval = 5,
        default = 150,
      },
      {
        name = "dropLastNotesOnly",
        type = "CheckBox",
        text = "仅对每段选区最后一个音符添加下坠",
        default = false,
      },
      {
        name = "restorePitch",
        type = "CheckBox",
        text = "尾后恢复音高偏移",
        default = false,
      },
    },
  }

  local result = SV:showCustomDialog(inputForm)
  if not result or not result.status then
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

  local options = resolveOptions(result.answers)

  local tasks, skipped = getEnabledTasks(groupTarget, options)
  local taskCount = countTasks(tasks)

  if taskCount == 0 then
    SV:showMessageBox("提示", "没有可用或启用的参数，未写入任何点。")
    return
  end

  local ranges = collectMergedRanges(selectedNotes)
  local processedPitchDrops = buildEffectPoints(selectedNotes, ranges, tasks, options)

  safeCall(function()
    SV:getProject():newUndoRecord()
    return true
  end)

  applyWriteMode(tasks, ranges, options.writeMode)
  writeAllTasks(tasks)

  local summary = buildSummary(#selectedNotes, taskCount, processedPitchDrops, tasks, skipped, options)

  if safeCall(function()
    return currentGroup:isMain()
  end) == false then
    summary = summary
      .. "\n\n注意: 参数写入当前音符组目标；如果该目标被多个引用复用，其他引用也会同步变化。"
  end

  SV:showMessageBox("完成", summary)
  SV:finish()
end
]====],
  ["Flatten_Pitch_Curve"] = [====[
function getClientInfo()
  return {
    name = "Flatten Pitch Curve",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 2,
    minEditorVersion = 65537,
  }
end

local SCOPE_NOTES = "notes"
local SCOPE_GROUPS = "groups"
local SCOPE_BOTH = "both"

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end
  return nil
end

local function getParameterSafe(group, typeName)
  return safeCall(function()
    return group:getParameter(typeName)
  end)
end

local function getSortedSelectedNotes(selection)
  local notes = safeCall(function()
    return selection:getSelectedNotes()
  end)

  if type(notes) ~= "table" then
    return {}
  end

  table.sort(notes, function(a, b)
    return a:getOnset() < b:getOnset()
  end)

  return notes
end

local function appendSelectedGroups(selection, groups)
  if selection == nil then
    return
  end

  local selectedGroups = safeCall(function()
    return selection:getSelectedGroups()
  end)

  if type(selectedGroups) ~= "table" then
    return
  end

  for _, groupRef in ipairs(selectedGroups) do
    table.insert(groups, groupRef)
  end
end

local function getSelectedGroups(editor)
  local groups = {}

  appendSelectedGroups(editor:getSelection(), groups)

  local arrangementSelection = safeCall(function()
    return SV:getArrangement():getSelection()
  end)
  appendSelectedGroups(arrangementSelection, groups)

  return groups
end

local function collectMergedRanges(ranges)
  table.sort(ranges, function(a, b)
    return a.start < b.start
  end)

  local merged = {}
  for _, range in ipairs(ranges) do
    if range.finish > range.start then
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
  end

  return merged
end

local function collectNoteRanges(notes)
  local ranges = {}

  for _, note in ipairs(notes) do
    local startPos = note:getOnset()
    local endPos = note:getEnd()
    if endPos > startPos then
      table.insert(ranges, {
        start = startPos,
        finish = endPos,
      })
    end
  end

  return collectMergedRanges(ranges)
end

local function getGroupName(groupTarget)
  local name = safeCall(function()
    return groupTarget:getName()
  end)

  if type(name) == "string" and name ~= "" then
    return name
  end

  return "未命名音符组"
end

local function getGroupKey(groupTarget)
  local uuid = safeCall(function()
    return groupTarget:getUUID()
  end)

  if type(uuid) == "string" and uuid ~= "" then
    return uuid
  end

  return tostring(groupTarget)
end

local function getOrCreateOperation(operations, groupTarget)
  local key = getGroupKey(groupTarget)

  if operations[key] == nil then
    operations[key] = {
      groupTarget = groupTarget,
      label = getGroupName(groupTarget),
      ranges = {},
      notes = {},
      noteKeys = {},
    }
  end

  return operations[key]
end

local function addFlatNoteToOperation(operation, startPos, endPos, pitch)
  if type(startPos) ~= "number" or type(endPos) ~= "number" or type(pitch) ~= "number" then
    return false
  end

  if endPos <= startPos then
    return false
  end

  local key = tostring(startPos) .. ":" .. tostring(endPos) .. ":" .. tostring(pitch)
  if operation.noteKeys[key] then
    return false
  end

  operation.noteKeys[key] = true
  table.insert(operation.notes, {
    start = startPos,
    finish = endPos,
    pitch = pitch,
  })

  return true
end

local function addRangesToOperation(operation, ranges)
  for _, range in ipairs(ranges) do
    table.insert(operation.ranges, {
      start = range.start,
      finish = range.finish,
    })
  end
end

local function getGroupReferenceRange(groupRef, groupTarget)
  local timeOffset = safeCall(function()
    return groupRef:getTimeOffset()
  end) or 0

  local startPos = safeCall(function()
    return groupRef:getOnset()
  end)

  local endPos = safeCall(function()
    return groupRef:getEnd()
  end)

  if type(startPos) == "number" and type(endPos) == "number" and endPos > startPos then
    return {
      start = startPos - timeOffset,
      finish = endPos - timeOffset,
    }
  end

  local maxEnd = 0
  local numNotes = safeCall(function()
    return groupTarget:getNumNotes()
  end) or 0

  for i = 1, numNotes do
    local note = groupTarget:getNote(i)
    local noteEnd = note:getEnd()
    if noteEnd > maxEnd then
      maxEnd = noteEnd
    end
  end

  if maxEnd <= 0 then
    return nil
  end

  return {
    start = 0,
    finish = maxEnd,
  }
end

local function buildScopeChoices(noteCount, groupCount)
  local choices = {}
  local values = {}

  if noteCount > 0 then
    table.insert(choices, "选中音符")
    table.insert(values, SCOPE_NOTES)
  end

  if groupCount > 0 then
    table.insert(choices, "选中音符组")
    table.insert(values, SCOPE_GROUPS)
  end

  if noteCount > 0 and groupCount > 0 then
    table.insert(choices, "选中音符 + 音符组")
    table.insert(values, SCOPE_BOTH)
  end

  return choices, values
end

local function rangeOverlaps(startPos, endPos, range)
  return endPos >= range.start and startPos <= range.finish
end

local function addNoteOperations(operations, currentGroup, selectedNotes)
  local groupTarget = currentGroup:getTarget()
  if groupTarget == nil then
    return 0
  end

  local ranges = collectNoteRanges(selectedNotes)
  if #ranges == 0 then
    return 0
  end

  local operation = getOrCreateOperation(operations, groupTarget)
  addRangesToOperation(operation, ranges)

  for _, note in ipairs(selectedNotes) do
    addFlatNoteToOperation(operation, note:getOnset(), note:getEnd(), note:getPitch())
  end

  return #ranges
end

local function addGroupNotesToOperation(operation, range)
  local added = 0
  local numNotes = safeCall(function()
    return operation.groupTarget:getNumNotes()
  end) or 0

  for i = 1, numNotes do
    local note = operation.groupTarget:getNote(i)
    local noteStart = note:getOnset()
    local noteEnd = note:getEnd()

    if rangeOverlaps(noteStart, noteEnd, range) then
      local startPos = math.max(noteStart, range.start)
      local endPos = math.min(noteEnd, range.finish)
      if addFlatNoteToOperation(operation, startPos, endPos, note:getPitch()) then
        added = added + 1
      end
    end
  end

  return added
end

local function addGroupOperations(operations, selectedGroups)
  local added = 0

  for _, groupRef in ipairs(selectedGroups) do
    local groupTarget = safeCall(function()
      return groupRef:getTarget()
    end)

    if groupTarget ~= nil then
      local range = getGroupReferenceRange(groupRef, groupTarget)
      if range ~= nil then
        local operation = getOrCreateOperation(operations, groupTarget)
        table.insert(operation.ranges, range)
        addGroupNotesToOperation(operation, range)
        added = added + 1
      end
    end
  end

  return added
end

local function finalizeOperations(operations)
  local list = {}

  for _, operation in pairs(operations) do
    operation.ranges = collectMergedRanges(operation.ranges)
    if #operation.ranges > 0 then
      table.insert(list, operation)
    end
  end

  table.sort(list, function(a, b)
    return a.label < b.label
  end)

  return list
end

local function countPoints(param, range)
  local points = safeCall(function()
    return param:getPoints(range.start, range.finish)
  end)

  if type(points) ~= "table" then
    return 0
  end

  return #points
end

local function addAutomationPoint(param, blick, value)
  if blick < 0 then
    return false, false
  end

  local didCreate = param:add(blick, value)
  return didCreate == true, didCreate ~= true
end

local function flattenPitchDelta(operation, options)
  local param = getParameterSafe(operation.groupTarget, "pitchDelta")
  if param == nil then
    return {
      removed = 0,
      created = 0,
      updated = 0,
      unavailable = true,
    }
  end

  local stats = {
    removed = 0,
    created = 0,
    updated = 0,
    unavailable = false,
  }

  for _, range in ipairs(operation.ranges) do
    local beforeBlick = range.start - 1
    local afterBlick = range.finish + 1
    local beforeValue = nil
    local afterValue = nil

    if options.protectOutside and beforeBlick >= 0 then
      beforeValue = param:get(beforeBlick)
    end
    if options.protectOutside then
      afterValue = param:get(afterBlick)
    end

    stats.removed = stats.removed + countPoints(param, range)
    param:remove(range.start, range.finish)

    if options.protectOutside and beforeValue ~= nil then
      local created, updated = addAutomationPoint(param, beforeBlick, beforeValue)
      if created then
        stats.created = stats.created + 1
      elseif updated then
        stats.updated = stats.updated + 1
      end
    end

    local startCreated, startUpdated = addAutomationPoint(param, range.start, 0)
    if startCreated then
      stats.created = stats.created + 1
    elseif startUpdated then
      stats.updated = stats.updated + 1
    end

    local endCreated, endUpdated = addAutomationPoint(param, range.finish, 0)
    if endCreated then
      stats.created = stats.created + 1
    elseif endUpdated then
      stats.updated = stats.updated + 1
    end

    if options.protectOutside and afterValue ~= nil then
      local created, updated = addAutomationPoint(param, afterBlick, afterValue)
      if created then
        stats.created = stats.created + 1
      elseif updated then
        stats.updated = stats.updated + 1
      end
    end
  end

  return stats
end

local function pitchControlSpan(control)
  local position = safeCall(function()
    return control:getPosition()
  end)

  if type(position) ~= "number" then
    return nil, nil
  end

  local startPos = position
  local endPos = position
  local points = safeCall(function()
    return control:getPoints()
  end)

  if type(points) == "table" then
    for _, point in ipairs(points) do
      local localTime = point[1]
      if type(localTime) == "number" then
        local globalTime = position + localTime
        if globalTime < startPos then
          startPos = globalTime
        end
        if globalTime > endPos then
          endPos = globalTime
        end
      end
    end
  end

  return startPos, endPos
end

local function pitchControlOverlapsRanges(control, ranges)
  local startPos, endPos = pitchControlSpan(control)
  if startPos == nil then
    return false
  end

  for _, range in ipairs(ranges) do
    if rangeOverlaps(startPos, endPos, range) then
      return true
    end
  end

  return false
end

local function removePitchControls(operation)
  local numControls = safeCall(function()
    return operation.groupTarget:getNumPitchControls()
  end)

  if type(numControls) ~= "number" or numControls <= 0 then
    return {
      removed = 0,
      unsupported = numControls == nil,
    }
  end

  local indexes = {}

  for i = 1, numControls do
    local control = safeCall(function()
      return operation.groupTarget:getPitchControl(i)
    end)

    if control ~= nil and pitchControlOverlapsRanges(control, operation.ranges) then
      table.insert(indexes, i)
    end
  end

  local removed = 0
  for i = #indexes, 1, -1 do
    local ok = safeCall(function()
      operation.groupTarget:removePitchControl(indexes[i])
      return true
    end)

    if ok then
      removed = removed + 1
    end
  end

  return {
    removed = removed,
    unsupported = false,
  }
end

local function createPitchControlCurve(startPos, endPos, pitch)
  local duration = endPos - startPos
  if duration <= 0 then
    return nil
  end

  local control = safeCall(function()
    return SV:create("PitchControlCurve")
  end)

  if control == nil then
    return nil
  end

  local ok = safeCall(function()
    control:setPosition(startPos)
    control:setPitch(pitch)
    control:setPoints({
      { 0, 0 },
      { duration, 0 },
    })
    return true
  end)

  if not ok then
    return nil
  end

  return control
end

local function drawFlatPitchControls(operation)
  local stats = {
    created = 0,
    failed = 0,
    unsupported = false,
  }

  for _, note in ipairs(operation.notes) do
    local control = createPitchControlCurve(note.start, note.finish, note.pitch)
    if control == nil then
      stats.failed = stats.failed + 1
    else
      local ok = safeCall(function()
        operation.groupTarget:addPitchControl(control)
        return true
      end)

      if ok then
        stats.created = stats.created + 1
      else
        stats.failed = stats.failed + 1
        stats.unsupported = true
      end
    end
  end

  return stats
end

local function buildOperations(scope, currentGroup, selectedNotes, selectedGroups)
  local operations = {}

  if scope == SCOPE_NOTES or scope == SCOPE_BOTH then
    addNoteOperations(operations, currentGroup, selectedNotes)
  end

  if scope == SCOPE_GROUPS or scope == SCOPE_BOTH then
    addGroupOperations(operations, selectedGroups)
  end

  return finalizeOperations(operations)
end

local function buildSummary(operations, pitchStats, removedControlStats, drawnControlStats, options)
  local totalRanges = 0
  local totalNotes = 0

  for _, operation in ipairs(operations) do
    totalRanges = totalRanges + #operation.ranges
    totalNotes = totalNotes + #operation.notes
  end

  local summary = "音高曲线已抹平。\n处理音符组目标: "
    .. #operations
    .. "\n处理范围: "
    .. totalRanges
    .. "\n水平音高线目标音符: "
    .. totalNotes

  if options.drawFlatPitchControls then
    summary = summary .. "\n水平 Pitch Control Curve: 创建 " .. drawnControlStats.created .. " 条"

    if drawnControlStats.failed > 0 then
      summary = summary .. "，失败 " .. drawnControlStats.failed .. " 条"
    end

    if drawnControlStats.unsupported > 0 then
      summary = summary .. "\n不支持写入 Pitch Control Curve 的目标: " .. drawnControlStats.unsupported
    end
  end

  if options.flattenPitchDelta then
    summary = summary
      .. "\npitchDelta: 删除 "
      .. pitchStats.removed
      .. " 点，写入 "
      .. pitchStats.created
      .. " 个 0 点，更新 "
      .. pitchStats.updated
      .. " 点"

    if pitchStats.unavailable > 0 then
      summary = summary .. "\n不可用 pitchDelta 目标: " .. pitchStats.unavailable
    end
  end

  if options.clearPitchControls then
    summary = summary .. "\n原有 Studio 2 音高控制: 移除 " .. removedControlStats.removed .. " 个对象"
    if removedControlStats.unsupported > 0 then
      summary = summary .. "\n不支持音高控制 API 的目标: " .. removedControlStats.unsupported
    end
  end

  summary = summary
    .. "\n\n提示: 本脚本修改音符组目标。如果目标被多个引用复用，其他引用也会同步变化。"

  return summary
end

function main()
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)
  local selectedGroups = getSelectedGroups(editor)

  if #selectedNotes == 0 and #selectedGroups == 0 then
    SV:showMessageBox("提示", "请先在钢琴窗选中音符，或在轨道中选中音符组。")
    return
  end

  local currentGroup = editor:getCurrentGroup()
  if #selectedNotes > 0 and currentGroup == nil then
    SV:showMessageBox("错误", "检测到选中音符，但未检测到当前音符组。")
    return
  end

  local scopeChoices, scopeValues = buildScopeChoices(#selectedNotes, #selectedGroups)
  local inputForm = {
    title = "音高曲线抹平 V2",
    message = "为选中音符绘制完全水平的 Studio 2 音高控制曲线，并可清理原有 pitchDelta 和音高控制。",
    buttons = "OkCancel",
    widgets = {
      {
        name = "scope",
        type = "ComboBox",
        label = "处理范围",
        choices = scopeChoices,
        default = 0,
      },
      {
        name = "drawFlatPitchControls",
        type = "CheckBox",
        text = "绘制水平 Studio 2 Pitch Control Curve",
        default = true,
      },
      {
        name = "flattenPitchDelta",
        type = "CheckBox",
        text = "同时清零 pitchDelta 曲线",
        default = true,
      },
      {
        name = "clearPitchControls",
        type = "CheckBox",
        text = "先移除范围内原有 Studio 2 音高控制点/曲线",
        default = true,
      },
      {
        name = "protectOutside",
        type = "CheckBox",
        text = "保护选区外相邻 pitchDelta 曲线",
        default = true,
      },
    },
  }

  local result = SV:showCustomDialog(inputForm)
  if not result or not result.status then
    return
  end

  local options = {
    scope = scopeValues[(result.answers.scope or 0) + 1],
    drawFlatPitchControls = result.answers.drawFlatPitchControls,
    flattenPitchDelta = result.answers.flattenPitchDelta,
    clearPitchControls = result.answers.clearPitchControls,
    protectOutside = result.answers.protectOutside,
  }

  if not options.drawFlatPitchControls and not options.flattenPitchDelta and not options.clearPitchControls then
    SV:showMessageBox("提示", "没有启用任何处理项。")
    return
  end

  local operations = buildOperations(options.scope, currentGroup, selectedNotes, selectedGroups)
  if #operations == 0 then
    SV:showMessageBox("提示", "没有找到可处理的有效范围。")
    return
  end

  safeCall(function()
    SV:getProject():newUndoRecord()
    return true
  end)

  local pitchStats = {
    removed = 0,
    created = 0,
    updated = 0,
    unavailable = 0,
  }
  local controlStats = {
    removed = 0,
    unsupported = 0,
  }
  local drawnControlStats = {
    created = 0,
    failed = 0,
    unsupported = 0,
  }

  for _, operation in ipairs(operations) do
    if options.clearPitchControls then
      local stats = removePitchControls(operation)
      controlStats.removed = controlStats.removed + stats.removed
      if stats.unsupported then
        controlStats.unsupported = controlStats.unsupported + 1
      end
    end

    if options.flattenPitchDelta then
      local stats = flattenPitchDelta(operation, options)
      pitchStats.removed = pitchStats.removed + stats.removed
      pitchStats.created = pitchStats.created + stats.created
      pitchStats.updated = pitchStats.updated + stats.updated
      if stats.unavailable then
        pitchStats.unavailable = pitchStats.unavailable + 1
      end
    end

    if options.drawFlatPitchControls then
      local stats = drawFlatPitchControls(operation)
      drawnControlStats.created = drawnControlStats.created + stats.created
      drawnControlStats.failed = drawnControlStats.failed + stats.failed
      if stats.unsupported then
        drawnControlStats.unsupported = drawnControlStats.unsupported + 1
      end
    end
  end

  SV:showMessageBox("完成", buildSummary(operations, pitchStats, controlStats, drawnControlStats, options))
  SV:finish()
end
]====],
  ["Pitch_To_Param"] = [====[
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
  if not result or not result.status then
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
]====],
  -- EMBEDDED_SOURCES_END
}

local scriptSelectValue = nil
local scriptInfoValue = nil
local selectionStatusValue = nil
local runButtonValue = nil
local detailsButtonValue = nil
local refreshButtonValue = nil
local initialized = false
local callbacksRegistered = false
local scriptRunQueued = false

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end
  return nil
end

local function safeSetValue(widgetValue, value)
  if widgetValue == nil then
    return
  end

  safeCall(function()
    widgetValue:setValue(value)
    return true
  end)
end

local function safeSetEnabled(widgetValue, enabled)
  if widgetValue == nil then
    return
  end

  safeCall(function()
    widgetValue:setEnabled(enabled)
    return true
  end)
end

local function safeGetValue(widgetValue, fallback)
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

local function createWidgetValue(defaultValue, enabled)
  local widgetValue = safeCall(function()
    return SV:create("WidgetValue")
  end)

  if widgetValue == nil then
    widgetValue = safeCall(function()
      return SV.create("WidgetValue")
    end)
  end

  if widgetValue ~= nil then
    safeSetValue(widgetValue, defaultValue)
    if enabled ~= nil then
      safeSetEnabled(widgetValue, enabled)
    end
  end

  return widgetValue
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

local function getScriptDisplayChoices()
  local choices = {}

  for _, entry in ipairs(SCRIPT_ENTRIES) do
    table.insert(choices, entry.name .. " " .. entry.version)
  end

  return choices
end

local function getManagedPath(entry)
  return MANAGED_DIRECTORY .. "/" .. entry.folder .. "/" .. entry.file
end

local function getSelectedEntry()
  local index = tonumber(safeGetValue(scriptSelectValue, 0)) or 0
  local entry = SCRIPT_ENTRIES[index + 1]

  if entry == nil then
    return SCRIPT_ENTRIES[1]
  end

  return entry
end

local function buildScriptInfo(entry)
  return entry.name
    .. " "
    .. entry.version
    .. "\n\n"
    .. entry.summary
    .. "\n\n需要: "
    .. entry.requires
    .. "\n\n用法: "
    .. entry.usage
    .. "\n\n同步来源: "
    .. getManagedPath(entry)
    .. "\n运行方式: 侧边栏使用内置源码，不依赖文件路径。"
end

local function updateScriptInfo()
  safeSetValue(scriptInfoValue, buildScriptInfo(getSelectedEntry()))
end

local function getCountLabel(count, singular, plural)
  if count == 1 then
    return "1 " .. singular
  end

  return tostring(count) .. " " .. plural
end

local function countSelectedNotes()
  local selection = safeCall(function()
    return SV:getMainEditor():getSelection()
  end)

  local notes = nil
  if selection ~= nil then
    notes = safeCall(function()
      return selection:getSelectedNotes()
    end)
  end

  if type(notes) ~= "table" then
    return 0
  end

  return #notes
end

local function countSelectedGroups()
  local arrangementSelection = safeCall(function()
    return SV:getArrangement():getSelection()
  end)

  local groups = nil
  if arrangementSelection ~= nil then
    groups = safeCall(function()
      return arrangementSelection:getSelectedGroups()
    end)
  end

  if type(groups) ~= "table" then
    return 0
  end

  return #groups
end

local function hasCurrentGroup()
  local currentGroup = safeCall(function()
    return SV:getMainEditor():getCurrentGroup()
  end)

  return currentGroup ~= nil
end

local function updateSelectionStatus()
  local noteCount = countSelectedNotes()
  local groupCount = countSelectedGroups()
  local currentGroupStatus = "当前音符组: 未检测到"

  if hasCurrentGroup() then
    currentGroupStatus = "当前音符组: 已就绪"
  end

  local status = getCountLabel(noteCount, "note selected", "notes selected")
    .. " | "
    .. getCountLabel(groupCount, "group selected", "groups selected")
    .. " | "
    .. currentGroupStatus

  safeSetValue(selectionStatusValue, status)
end

local function registerSelectionCallbacks()
  if callbacksRegistered then
    return
  end

  callbacksRegistered = true

  local editorSelection = safeCall(function()
    return SV:getMainEditor():getSelection()
  end)

  if editorSelection ~= nil then
    safeCall(function()
      editorSelection:registerSelectionCallback(function(selectionType)
        if selectionType == "note" or selectionType == "pitchControl" then
          updateSelectionStatus()
        end
      end)
      return true
    end)

    safeCall(function()
      editorSelection:registerClearCallback(function(selectionType)
        if selectionType == "notes" or selectionType == "pitchControls" then
          updateSelectionStatus()
        end
      end)
      return true
    end)
  end

  local arrangementSelection = safeCall(function()
    return SV:getArrangement():getSelection()
  end)

  if arrangementSelection ~= nil then
    safeCall(function()
      arrangementSelection:registerSelectionCallback(function(selectionType)
        if selectionType == "group" then
          updateSelectionStatus()
        end
      end)
      return true
    end)

    safeCall(function()
      arrangementSelection:registerClearCallback(function(selectionType)
        if selectionType == "groups" then
          updateSelectionStatus()
        end
      end)
      return true
    end)
  end
end

local function createSVProxy()
  local proxy = {}

  setmetatable(proxy, {
    __index = function(_, key)
      if key == "finish" then
        return function() end
      end

      local value = SV[key]
      if type(value) == "function" then
        return function(firstArg, ...)
          if firstArg == proxy then
            return value(SV, ...)
          end

          return value(SV, firstArg, ...)
        end
      end

      return value
    end,
  })

  return proxy
end

local function createScriptEnvironment()
  local env = {
    SV = createSVProxy(),
    _VERSION = _VERSION,
    assert = assert,
    collectgarbage = collectgarbage,
    coroutine = coroutine,
    error = error,
    getmetatable = getmetatable,
    ipairs = ipairs,
    load = load,
    math = math,
    next = next,
    os = os,
    pairs = pairs,
    pcall = pcall,
    rawequal = rawequal,
    rawget = rawget,
    rawlen = rawlen,
    rawset = rawset,
    require = require,
    select = select,
    setmetatable = setmetatable,
    string = string,
    table = table,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    utf8 = utf8,
    xpcall = xpcall,
  }

  env._G = env
  return setmetatable(env, {
    __index = _G,
  })
end

local function loadEmbeddedScriptChunk(entry, env)
  if type(load) ~= "function" then
    return nil, "当前 Lua 环境不可用 load。"
  end

  local source = EMBEDDED_SCRIPT_SOURCES[entry.sourceKey]
  if type(source) ~= "string" or source == "" then
    return nil, "管理器没有内置 " .. entry.name .. " 的脚本源码。"
  end

  local ok, chunk, loadError = pcall(load, source, "@" .. getManagedPath(entry), "t", env)
  if not ok then
    return nil, chunk
  end

  if chunk == nil then
    return nil, loadError
  end

  return chunk, nil
end

local function runEntry(entry)
  local env = createScriptEnvironment()

  local chunk, loadError = loadEmbeddedScriptChunk(entry, env)
  if chunk == nil then
    SV:showMessageBox("运行失败", entry.name .. " 加载时出错:\n" .. tostring(loadError))
    return
  end

  local ok, runtimeError = pcall(chunk)
  if not ok then
    SV:showMessageBox("运行失败", entry.name .. " 加载时出错:\n" .. tostring(runtimeError))
    return
  end

  if type(env.main) ~= "function" then
    SV:showMessageBox("运行失败", entry.name .. " 没有可调用的 main()。")
    return
  end

  local runOk, runError = pcall(env.main)
  if not runOk then
    SV:showMessageBox("运行失败", entry.name .. " 执行时出错:\n" .. tostring(runError))
    return
  end

  updateSelectionStatus()
end

local function showEntryDetails(entry)
  SV:showMessageBox("脚本信息", buildScriptInfo(entry))
end

local function initializeValues()
  if initialized then
    return
  end

  initialized = true

  scriptSelectValue = createWidgetValue(0, true)
  scriptInfoValue = createWidgetValue("", false)
  selectionStatusValue = createWidgetValue("", false)
  runButtonValue = createWidgetValue(false, true)
  detailsButtonValue = createWidgetValue(false, true)
  refreshButtonValue = createWidgetValue(false, true)

  setValueChangeCallback(scriptSelectValue, function()
    updateScriptInfo()
  end)

  setValueChangeCallback(runButtonValue, function()
    if scriptRunQueued then
      return
    end

    scriptRunQueued = true
    local entry = getSelectedEntry()
    safeCall(function()
      runButtonValue:setValue(false)
      return true
    end)

    local scheduled = safeCall(function()
      SV:setTimeout(0, function()
        scriptRunQueued = false
        runEntry(entry)
      end)
      return true
    end)

    if not scheduled then
      scriptRunQueued = false
      runEntry(entry)
    end
  end)

  setValueChangeCallback(detailsButtonValue, function()
    showEntryDetails(getSelectedEntry())
  end)

  setValueChangeCallback(refreshButtonValue, function()
    updateSelectionStatus()
    updateScriptInfo()
  end)

  updateScriptInfo()
  updateSelectionStatus()
  registerSelectionCallbacks()
end

function getSidePanelSectionState()
  initializeValues()

  return {
    title = SCRIPT_TITLE,
    rows = {
      {
        type = "Label",
        text = "Managed scripts",
      },
      {
        type = "Container",
        columns = {
          {
            type = "ComboBox",
            choices = getScriptDisplayChoices(),
            value = scriptSelectValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Container",
        columns = {
          {
            type = "Button",
            text = "Run",
            value = runButtonValue,
            width = 0.34,
          },
          {
            type = "Button",
            text = "Details",
            value = detailsButtonValue,
            width = 0.33,
          },
          {
            type = "Button",
            text = "Refresh",
            value = refreshButtonValue,
            width = 0.33,
          },
        },
      },
      {
        type = "Label",
        text = "Selection",
      },
      {
        type = "Container",
        columns = {
          {
            type = "TextBox",
            value = selectionStatusValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Label",
        text = "Description",
      },
      {
        type = "Container",
        columns = {
          {
            type = "TextArea",
            value = scriptInfoValue,
            height = 170,
            width = 1.0,
          },
        },
      },
    },
  }
end
