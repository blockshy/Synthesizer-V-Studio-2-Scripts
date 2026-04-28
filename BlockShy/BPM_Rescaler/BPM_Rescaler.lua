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
  if result.status == "Cancel" then
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
