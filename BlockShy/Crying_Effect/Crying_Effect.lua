function getClientInfo()
  return {
    name = "Crying Effect",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 5,
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
  addEnvelopePoint(task, note, options.attackPercent, 1.0 + (0.08 * options.intensity))
  addEnvelopePoint(task, note, options.peakPercent, 1.0 + (0.32 * options.intensity))
  addEnvelopePoint(task, note, options.releasePercent, 1.0 + (0.18 * options.intensity))
  addEnvelopePoint(task, note, 100, 1.0)
end

local function buildBreathEnvelope(task, note, options)
  addEnvelopePoint(task, note, 0, 0.0)
  addEnvelopePoint(task, note, options.attackPercent, 0.16 * options.intensity)
  addEnvelopePoint(task, note, options.peakPercent, 0.42 * options.intensity)
  addEnvelopePoint(task, note, options.releasePercent, 0.22 * options.intensity)
  addEnvelopePoint(task, note, 100, 0.0)
end

local function buildTensionEnvelope(task, note, options)
  addEnvelopePoint(task, note, 0, 0.0)
  addEnvelopePoint(
    task,
    note,
    options.attackPercent,
    (0.12 * options.intensity) + randomJitter(options.randomAmount * 0.5)
  )
  addEnvelopePoint(task, note, options.peakPercent, (0.42 * options.intensity) + randomJitter(options.randomAmount))
  addEnvelopePoint(
    task,
    note,
    options.releasePercent,
    (0.18 * options.intensity) + randomJitter(options.randomAmount * 0.6)
  )
  addEnvelopePoint(task, note, 100, 0.0)
end

local function buildPitchDrop(task, note, options)
  local onset = note:getOnset()
  local duration = note:getDuration()
  local dropStart = onset + roundBlick(duration * (options.dropStartPercent / 100.0))
  local dropEnd = note:getEnd()
  local baseStart = task.param:get(dropStart)
  local dropAmount = -options.dropDepth * options.intensity

  addGeneratedPoint(task, dropStart, baseStart)
  addGeneratedPoint(task, dropEnd, baseStart + dropAmount)

  if options.restorePitch then
    local restoreOffset = math.floor((SV.QUARTER or 705600000) / 64)
    if restoreOffset < 1 then
      restoreOffset = 1
    end
    addGeneratedPoint(task, dropEnd + restoreOffset, baseStart)
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

    if tasks.pitchDelta and (not options.dropLastNotesOnly or isLastNoteInMergedRange(note, ranges, rangeLastEnds)) then
      buildPitchDrop(tasks.pitchDelta, note, options)
      processedPitchDrops = processedPitchDrops + 1
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

local function buildSummary(noteCount, taskCount, processedPitchDrops, tasks, skipped)
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
    title = "自动哭腔参数设置 V5",
    message = "为选中音符生成哭腔风格的颤音、气声、张力和相对音高下坠。",
    buttons = "OkCancel",
    widgets = {
      {
        name = "intensity",
        type = "Slider",
        label = "哭腔强度",
        format = "%1.1f",
        minValue = 0.2,
        maxValue = 2.0,
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
        text = "添加尾部下坠",
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

  local options = {
    intensity = result.answers.intensity,
    writeMode = result.answers.writeMode,
    addVibrato = result.answers.addVibrato,
    addBreath = result.answers.addBreath,
    addTension = result.answers.addTension,
    addPitchDrop = result.answers.addPitchDrop,
    attackPercent = result.answers.attackPercent,
    peakPercent = result.answers.peakPercent,
    releasePercent = result.answers.releasePercent,
    randomAmount = result.answers.randomAmount,
    fixedRandom = result.answers.fixedRandom,
    dropStartPercent = result.answers.dropStartPercent,
    dropDepth = result.answers.dropDepth,
    dropLastNotesOnly = result.answers.dropLastNotesOnly,
    restorePitch = result.answers.restorePitch,
  }

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

  local summary = buildSummary(#selectedNotes, taskCount, processedPitchDrops, tasks, skipped)

  if safeCall(function()
    return currentGroup:isMain()
  end) == false then
    summary = summary
      .. "\n\n注意: 参数写入当前音符组目标；如果该目标被多个引用复用，其他引用也会同步变化。"
  end

  SV:showMessageBox("完成", summary)
  SV:finish()
end
