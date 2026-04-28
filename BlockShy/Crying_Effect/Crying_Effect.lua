local SIDE_PANEL_MIN_VERSION = 131330

local function getHostVersionNumber()
  local ok, hostInfo = pcall(function()
    return SV:getHostInfo()
  end)

  if ok and type(hostInfo) == "table" and type(hostInfo.hostVersionNumber) == "number" then
    return hostInfo.hostVersionNumber
  end

  return 0
end

local function isSidePanelHost()
  return getHostVersionNumber() >= SIDE_PANEL_MIN_VERSION
end

function getClientInfo()
  local info = {
    name = "Crying Effect",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 12,
    minEditorVersion = 0,
  }

  if isSidePanelHost() then
    info.minEditorVersion = SIDE_PANEL_MIN_VERSION
    info.type = "SidePanelSection"
  end

  return info
end

local WRITE_OVERWRITE_RANGES = 0
local WRITE_REBUILD_ENABLED = 2

local PARAM_DEFS = {
  vibratoEnv = { label = "颤音包络", labelEn = "Vibrato envelope", defaultMin = 0.0, defaultMax = 2.0 },
  breathiness = { label = "气声", labelEn = "Breathiness", defaultMin = -1.0, defaultMax = 1.0 },
  tension = { label = "张力", labelEn = "Tension", defaultMin = -1.0, defaultMax = 1.0 },
  pitchDelta = { label = "音高偏移", labelEn = "Pitch offset", defaultMin = -1200.0, defaultMax = 1200.0 },
}

local CRY_PRESETS = {
  {
    label = "轻微哽咽",
    labelEn = "Light sob",
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
    labelEn = "Natural cry (Recommended)",
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
    labelEn = "Obvious cry",
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
    labelEn = "Strong cry",
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
    labelEn = "Tail sob",
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
local languageValue = nil
local legacyLanguageValue = 0

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end
  return nil
end

local function isEnglish()
  if languageValue == nil then
    return legacyLanguageValue == 1
  end

  local value = safeCall(function()
    return languageValue:getValue()
  end)

  if value == nil then
    value = legacyLanguageValue
  end

  return value == 1
end

local function tr(zh, en)
  if isEnglish() then
    return en
  end

  return zh
end

local function getParamLabel(typeName)
  local definition = PARAM_DEFS[typeName]
  if definition == nil then
    return typeName
  end

  return tr(definition.label, definition.labelEn or definition.label)
end

local function getPresetLabel(preset)
  if preset == nil then
    return tr("自定义", "Custom")
  end

  return tr(preset.label, preset.labelEn or preset.label)
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
    table.insert(choices, getPresetLabel(preset))
  end

  table.insert(choices, tr("自定义（使用下方高级参数）", "Custom (use advanced controls below)"))
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
    local oldPoints = safeCall(function()
      return param:getPoints(range.start, range.finish)
    end)

    if type(oldPoints) == "table" then
      removed = removed + #oldPoints
    end

    if type(oldPoints) ~= "table" or #oldPoints > 0 then
      safeCall(function()
        param:remove(range.start, range.finish)
        return true
      end)
    end
  end

  return removed
end

local function clearAllPoints(param)
  local oldPoints = safeCall(function()
    return param:getAllPoints()
  end)

  if type(oldPoints) ~= "table" then
    safeCall(function()
      param:removeAll()
      return true
    end)
    return 0
  end

  local removed = #oldPoints

  if removed > 0 then
    local cleared = safeCall(function()
      param:removeAll()
      return true
    end)

    if not cleared then
      return 0
    end
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
    label = getParamLabel(typeName),
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
      table.insert(skipped, getParamLabel(typeName) .. " (" .. typeName .. ")")
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
    presetLabel = tr("自定义", "Custom"),
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
    options.presetLabel = getPresetLabel(preset)
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

  local summary = tr("哭腔参数已生成。\n", "Crying effect parameters generated.\n")
    .. tr("预设: ", "Preset: ")
    .. options.presetLabel
    .. tr("\n处理音符: ", "\nProcessed notes: ")
    .. noteCount
    .. tr("\n启用参数: ", "\nEnabled parameters: ")
    .. taskCount
    .. tr("\n生成点: ", "\nGenerated points: ")
    .. totalGenerated
    .. tr("，新建 ", ", created ")
    .. totalCreated
    .. tr("，更新 ", ", updated ")
    .. totalUpdated
    .. tr("\n清理旧点: ", "\nRemoved old points: ")
    .. totalRemoved

  if processedPitchDrops > 0 then
    summary = summary .. tr("\n尾部下坠音符: ", "\nTail-drop notes: ") .. processedPitchDrops
  end

  if totalCollisions > 0 then
    summary = summary .. tr("\n合并同位置点: ", "\nMerged same-position points: ") .. totalCollisions
  end

  if #skipped > 0 then
    summary = summary
      .. tr("\n跳过不可用参数: ", "\nSkipped unavailable parameters: ")
      .. table.concat(skipped, ", ")
  end

  return summary
end

local presetValue = nil
local intensityValue = nil
local writeModeValue = nil
local addVibratoValue = nil
local addBreathValue = nil
local addTensionValue = nil
local addPitchDropValue = nil
local attackPercentValue = nil
local peakPercentValue = nil
local releasePercentValue = nil
local randomAmountValue = nil
local fixedRandomValue = nil
local dropStartPercentValue = nil
local dropDepthValue = nil
local dropLastNotesOnlyValue = nil
local restorePitchValue = nil
local introValue = nil
local introExpandedValue = nil
local runButtonValue = nil
local refreshButtonValue = nil
local statusValue = nil
local initialized = false
local isRunning = false

local function showMessage(title, message)
  local shown = safeCall(function()
    SV:showMessageBoxAsync(title, message)
    return true
  end)

  if shown then
    return
  end

  safeCall(function()
    SV:showMessageBox(title, message)
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

local function isIntroExpanded()
  return getWidgetValue(introExpandedValue, false) == true
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

local function setWidgetEnabled(widgetValue, enabled)
  if widgetValue == nil then
    return
  end

  safeCall(function()
    widgetValue:setEnabled(enabled)
    return true
  end)
end

local function refreshSidePanel()
  safeCall(function()
    SV:refreshSidePanel()
    return true
  end)
end

local function getIntroText()
  local zh = "功能: 为选中音符生成哭腔风格的颤音包络、气声、张力和音高哭腔/尾部下坠。\n\n"
    .. "用法: 在钢琴窗选中音符，选择哭腔预设、强度和写入模式，然后点击“运行”。"
  local en = "Purpose: Generate crying-style vibrato envelope, breathiness, tension, "
    .. "and pitch cry / tail-drop gestures for selected notes.\n\n"
    .. "Usage: Select notes in the piano roll, choose a preset, strength, and write mode, "
    .. "then click Run."
  return tr(zh, en)
end

local function updateIntro()
  setWidgetValue(introValue, getIntroText())
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

local function updateStatus()
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)
  setWidgetValue(statusValue, tr("选中音符: ", "Selected notes: ") .. #selectedNotes)
end

local function buildPanelAnswers()
  return {
    preset = getWidgetValue(presetValue, 1),
    intensity = getWidgetValue(intensityValue, 1.0),
    writeMode = getWidgetValue(writeModeValue, 0),
    addVibrato = getWidgetValue(addVibratoValue, true),
    addBreath = getWidgetValue(addBreathValue, true),
    addTension = getWidgetValue(addTensionValue, true),
    addPitchDrop = getWidgetValue(addPitchDropValue, true),
    attackPercent = getWidgetValue(attackPercentValue, 12),
    peakPercent = getWidgetValue(peakPercentValue, 45),
    releasePercent = getWidgetValue(releasePercentValue, 88),
    randomAmount = getWidgetValue(randomAmountValue, 0.12),
    fixedRandom = getWidgetValue(fixedRandomValue, true),
    dropStartPercent = getWidgetValue(dropStartPercentValue, 75),
    dropDepth = getWidgetValue(dropDepthValue, 150),
    dropLastNotesOnly = getWidgetValue(dropLastNotesOnlyValue, false),
    restorePitch = getWidgetValue(restorePitchValue, false),
  }
end

local function runCryingOptions(options)
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
      tr("请先在钢琴窗中选中一个或多个音符。", "Select one or more notes in the piano roll first.")
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

  local tasks, skipped = getEnabledTasks(groupTarget, options)
  local taskCount = countTasks(tasks)

  if taskCount == 0 then
    showMessage(
      tr("提示", "Notice"),
      tr(
        "没有可用或启用的参数，未写入任何点。",
        "No available or enabled parameter; no points were written."
      )
    )
    isRunning = false
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

local function runPanel()
  runCryingOptions(resolveOptions(buildPanelAnswers()))
end

local function getDialogAnswers(result)
  if type(result) ~= "table" then
    return nil
  end

  if result.status ~= true and result.status ~= "Ok" and result.status ~= "OK" and result.status ~= "ok" then
    return nil
  end

  return result.answers or {}
end

local function finishScript()
  safeCall(function()
    SV:finish()
    return true
  end)
end

function main()
  local result = SV:showCustomDialog({
    title = "Crying Effect",
    message = "为选中音符生成哭腔表现参数。\nGenerate crying-style expression parameters for selected notes.",
    buttons = "OkCancel",
    widgets = {
      {
        name = "language",
        type = "ComboBox",
        label = "语言 / Language",
        choices = { "中文", "English" },
        default = legacyLanguageValue,
      },
      {
        name = "preset",
        type = "ComboBox",
        label = "预设 / Preset",
        choices = buildPresetChoices(),
        default = 1,
      },
      {
        name = "intensity",
        type = "Slider",
        label = "预设强度倍率 / Preset strength",
        format = "%1.1f",
        minValue = 0.5,
        maxValue = 1.6,
        interval = 0.1,
        default = 1.0,
      },
      {
        name = "writeMode",
        type = "ComboBox",
        label = "写入模式 / Write mode",
        choices = {
          "覆盖选中音符范围 / Overwrite selected note ranges",
          "仅追加/更新同位置点 / Append/update only",
          "清空已启用参数后重建 / Clear enabled parameters and rebuild",
        },
        default = 0,
      },
      {
        name = "addVibrato",
        type = "CheckBox",
        text = "添加颤音包络 / Add vibrato envelope",
        default = true,
      },
      {
        name = "addBreath",
        type = "CheckBox",
        text = "添加气声 / Add breathiness",
        default = true,
      },
      {
        name = "addTension",
        type = "CheckBox",
        text = "添加张力 / Add tension",
        default = true,
      },
      {
        name = "addPitchDrop",
        type = "CheckBox",
        text = "添加音高哭腔/尾部下坠 / Add pitch cry / tail drop",
        default = true,
      },
      {
        name = "fixedRandom",
        type = "CheckBox",
        text = "固定随机结果 / Fixed random output",
        default = true,
      },
      {
        name = "dropLastNotesOnly",
        type = "CheckBox",
        text = "仅对每段选区最后一个音符添加下坠 / Drop only last note in each range",
        default = false,
      },
    },
  })

  local answers = getDialogAnswers(result)
  if answers == nil then
    finishScript()
    return
  end

  legacyLanguageValue = tonumber(answers.language) or 0
  local panelAnswers = {
    preset = tonumber(answers.preset) or 1,
    intensity = tonumber(answers.intensity) or 1.0,
    writeMode = tonumber(answers.writeMode) or 0,
    addVibrato = answers.addVibrato ~= false,
    addBreath = answers.addBreath ~= false,
    addTension = answers.addTension ~= false,
    addPitchDrop = answers.addPitchDrop ~= false,
    attackPercent = 12,
    peakPercent = 45,
    releasePercent = 88,
    randomAmount = 0.12,
    fixedRandom = answers.fixedRandom ~= false,
    dropStartPercent = 75,
    dropDepth = 150,
    dropLastNotesOnly = answers.dropLastNotesOnly == true,
    restorePitch = false,
  }

  runCryingOptions(resolveOptions(panelAnswers))
  finishScript()
end

local function initializePanel()
  if initialized then
    return
  end

  initialized = true
  languageValue = createWidgetValue(0)
  presetValue = createWidgetValue(1)
  intensityValue = createWidgetValue(1.0)
  writeModeValue = createWidgetValue(0)
  addVibratoValue = createWidgetValue(true)
  addBreathValue = createWidgetValue(true)
  addTensionValue = createWidgetValue(true)
  addPitchDropValue = createWidgetValue(true)
  attackPercentValue = createWidgetValue(12)
  peakPercentValue = createWidgetValue(45)
  releasePercentValue = createWidgetValue(88)
  randomAmountValue = createWidgetValue(0.12)
  fixedRandomValue = createWidgetValue(true)
  dropStartPercentValue = createWidgetValue(75)
  dropDepthValue = createWidgetValue(150)
  dropLastNotesOnlyValue = createWidgetValue(false)
  restorePitchValue = createWidgetValue(false)
  introValue = createWidgetValue("")
  introExpandedValue = createWidgetValue(false)
  runButtonValue = createWidgetValue(false)
  refreshButtonValue = createWidgetValue(false)
  statusValue = createWidgetValue("")
  setWidgetEnabled(introValue, false)

  setValueChangeCallback(runButtonValue, function()
    runPanel()
  end)

  setValueChangeCallback(refreshButtonValue, function()
    updateStatus()
  end)

  setValueChangeCallback(languageValue, function()
    updateIntro()
    updateStatus()
    refreshSidePanel()
  end)

  setValueChangeCallback(introExpandedValue, function()
    refreshSidePanel()
  end)

  updateIntro()
  updateStatus()
end

local function checkboxRow(text, value)
  return {
    type = "Container",
    columns = {
      {
        type = "CheckBox",
        text = text,
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

local function appendRows(rows, newRows)
  for _, row in ipairs(newRows) do
    table.insert(rows, row)
  end
end

local function buildBaseRows()
  local rows = {
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
    checkboxRow(
      isIntroExpanded() and tr("隐藏功能与用法", "Hide purpose & usage")
        or tr("显示功能与用法", "Show purpose & usage"),
      introExpandedValue
    ),
  }

  if isIntroExpanded() then
    appendRows(rows, {
      {
        type = "Label",
        text = tr("功能与用法", "Purpose & Usage"),
      },
      {
        type = "Container",
        columns = {
          {
            type = "TextArea",
            value = introValue,
            height = 128,
            width = 1.0,
          },
        },
      },
    })
  end

  return rows
end

function getSidePanelSectionState()
  initializePanel()

  local rows = buildBaseRows()
  appendRows(rows, {
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
      text = tr("预设", "Preset"),
    },
    {
      type = "Container",
      columns = {
        {
          type = "ComboBox",
          choices = buildPresetChoices(),
          value = presetValue,
          width = 1.0,
        },
      },
    },
    sliderRow(tr("预设强度倍率", "Preset strength"), intensityValue, "%1.1f", 0.5, 1.6, 0.1),
    {
      type = "Container",
      columns = {
        {
          type = "ComboBox",
          choices = {
            tr("覆盖选中音符范围", "Overwrite selected note ranges"),
            tr("仅追加/更新同位置点", "Append/update only"),
            tr("清空已启用参数后重建", "Clear enabled parameters and rebuild"),
          },
          value = writeModeValue,
          width = 1.0,
        },
      },
    },
    checkboxRow(tr("添加颤音包络", "Add vibrato envelope"), addVibratoValue),
    checkboxRow(tr("添加气声", "Add breathiness"), addBreathValue),
    checkboxRow(tr("添加张力", "Add tension"), addTensionValue),
    checkboxRow(tr("添加音高哭腔/尾部下坠", "Add pitch cry / tail drop"), addPitchDropValue),
    {
      type = "Label",
      text = tr("自定义包络", "Custom Envelope"),
    },
    sliderRow(tr("起势位置 (%)", "Attack position (%)"), attackPercentValue, "%1.0f", 0, 40, 1),
    sliderRow(tr("峰值位置 (%)", "Peak position (%)"), peakPercentValue, "%1.0f", 20, 80, 1),
    sliderRow(tr("回落位置 (%)", "Release position (%)"), releasePercentValue, "%1.0f", 60, 100, 1),
    sliderRow(tr("张力随机量", "Tension randomness"), randomAmountValue, "%1.2f", 0, 0.4, 0.01),
    checkboxRow(tr("固定随机结果", "Fixed random output"), fixedRandomValue),
    sliderRow(tr("下坠开始位置 (%)", "Drop start position (%)"), dropStartPercentValue, "%1.0f", 40, 95, 1),
    sliderRow(tr("下坠深度 (cents)", "Drop depth (cents)"), dropDepthValue, "%1.0f", 20, 400, 5),
    checkboxRow(
      tr("仅对每段选区最后一个音符添加下坠", "Apply drop only to the last note in each range"),
      dropLastNotesOnlyValue
    ),
    checkboxRow(tr("尾后恢复音高偏移", "Restore pitch after tail"), restorePitchValue),
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
  })

  return {
    title = tr("哭腔效果", "Crying Effect"),
    rows = rows,
  }
end
