function getClientInfo()
  return {
    name = "BPM Rescaler",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 9,
    minEditorVersion = 131330,
    type = "SidePanelSection",
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

local currentBpmValue = nil
local originalBpmValue = nil
local anchorModeValue = nil
local processAutomationValue = nil
local processPitchControlsValue = nil
local languageValue = nil
local runButtonValue = nil
local detectButtonValue = nil
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

local function detectCurrentBpm()
  local editor = SV:getMainEditor()
  local project = SV:getProject()
  local timeAxis = project:getTimeAxis()
  local currentGroup = editor:getCurrentGroup()

  if currentGroup == nil then
    setWidgetValue(statusValue, tr("未检测到当前音符组。", "No current note group detected."))
    return nil, 0
  end

  local groupOnset = getGroupOnset(currentGroup)
  local detectedBPM = getTempoAt(timeAxis, groupOnset)
  local tempoMarkCount = getTempoMarkCount(timeAxis)

  return detectedBPM, tempoMarkCount
end

local function refreshDetectedBpm()
  local detectedBPM, tempoMarkCount = detectCurrentBpm()
  if detectedBPM == nil then
    return
  end

  setWidgetValue(currentBpmValue, formatNumber(detectedBPM))
  setWidgetValue(originalBpmValue, formatNumber(detectedBPM / 2))

  local status = tr("检测 BPM: ", "Detected BPM: ") .. formatNumber(detectedBPM)
  if tempoMarkCount > 1 then
    status = status .. tr(" | 多个 BPM 标记", " | multiple tempo marks")
  end

  setWidgetValue(statusValue, status)
end

local function runPanel()
  if isRunning then
    return
  end

  isRunning = true

  local editor = SV:getMainEditor()
  local project = SV:getProject()
  local timeAxis = project:getTimeAxis()
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
      tr(
        "未检测到选中的轨道或音符组，请先选中一个轨道。",
        "No selected track or note group target detected. Select a track first."
      )
    )
    isRunning = false
    return
  end

  local groupOnset = getGroupOnset(currentGroup)
  local tempoMarkCount = getTempoMarkCount(timeAxis)

  local currentBPM = tonumber(getWidgetValue(currentBpmValue, ""))
  local originalBPM = tonumber(getWidgetValue(originalBpmValue, ""))

  if currentBPM == nil or currentBPM <= 0 or originalBPM == nil or originalBPM <= 0 then
    showMessage(tr("错误", "Error"), tr("请输入有效的 BPM 数值。", "Enter valid BPM values."))
    isRunning = false
    return
  end

  local ratio = currentBPM / originalBPM
  local anchor = 0
  local anchorLabel = tr("音符组内部 0 位置", "Note group local 0")

  if getWidgetValue(anchorModeValue, 0) == 1 then
    anchor = getFirstNoteOnset(groupTarget)
    anchorLabel = tr("第一个音符起点", "First note onset")
  end

  local noteCount = rescaleNotes(groupTarget, anchor, ratio)
  local automationStats = { tracks = 0, points = 0, keptPoints = 0, collisions = 0 }
  local pitchStats = { objects = 0, curvePoints = 0 }

  if getWidgetValue(processAutomationValue, true) then
    automationStats = rescaleAutomation(groupTarget, anchor, ratio)
  end

  if getWidgetValue(processPitchControlsValue, true) then
    pitchStats = rescalePitchControls(groupTarget, anchor, ratio)
  end

  local summary = tr("缩放完成。\n", "Rescale complete.\n")
    .. tr("比例: ", "Ratio: ")
    .. formatNumber(ratio)
    .. " ("
    .. formatNumber(originalBPM)
    .. " -> "
    .. formatNumber(currentBPM)
    .. " BPM)\n"
    .. tr("锚点: ", "Anchor: ")
    .. anchorLabel
    .. "\n"
    .. tr("音符: ", "Notes: ")
    .. noteCount
    .. "\n"
    .. tr("参数曲线: ", "Automation: ")
    .. automationStats.tracks
    .. tr(" 条 / ", " tracks / ")
    .. automationStats.points
    .. tr(" 点", " points")

  if automationStats.collisions > 0 then
    summary = summary
      .. tr("，合并冲突 ", ", merged collisions: ")
      .. automationStats.collisions
      .. tr(" 点", " points")
  end

  summary = summary
    .. tr("\n音高控制: ", "\nPitch controls: ")
    .. pitchStats.objects
    .. tr(" 个对象 / ", " objects / ")
    .. pitchStats.curvePoints
    .. tr(" 个曲线点", " curve points")

  if tempoMarkCount > 1 then
    summary = summary
      .. tr(
        "\n\n提示: 工程中存在多个 BPM 标记，本次按单一比例处理。",
        "\n\nNote: The project has multiple tempo marks; this run used one global ratio."
      )
  end

  local isMainGroup = safeCall(function()
    return currentGroup:isMain()
  end)

  if isMainGroup == false then
    summary = summary
      .. tr(
        "\n\n注意: 当前脚本修改的是音符组目标。如果该目标被多个引用复用，其他引用也会同步变化。",
        "\n\nWarning: This script edits the note group target. "
          .. "If the target is reused by multiple references, those references will change as well."
      )
  end

  showMessage(tr("完成", "Done"), summary)
  setWidgetValue(
    statusValue,
    tr("完成缩放，引用位置 BPM: ", "Rescale complete, reference BPM: ")
      .. formatNumber(getTempoAt(timeAxis, groupOnset))
  )
  isRunning = false
end

local function initializePanel()
  if initialized then
    return
  end

  initialized = true
  currentBpmValue = createWidgetValue("120")
  originalBpmValue = createWidgetValue("60")
  anchorModeValue = createWidgetValue(0)
  processAutomationValue = createWidgetValue(true)
  processPitchControlsValue = createWidgetValue(true)
  languageValue = createWidgetValue(0)
  runButtonValue = createWidgetValue(false)
  detectButtonValue = createWidgetValue(false)
  statusValue = createWidgetValue("")

  setValueChangeCallback(runButtonValue, function()
    runPanel()
  end)

  setValueChangeCallback(detectButtonValue, function()
    refreshDetectedBpm()
  end)

  setValueChangeCallback(languageValue, function()
    refreshDetectedBpm()
    safeCall(function()
      SV:refreshSidePanel()
      return true
    end)
  end)

  refreshDetectedBpm()
end

local function textBoxRow(value)
  return {
    type = "Container",
    columns = {
      {
        type = "TextBox",
        value = value,
        width = 1.0,
      },
    },
  }
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

function getSidePanelSectionState()
  initializePanel()

  return {
    title = tr("BPM 重缩放", "BPM Rescaler"),
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
        text = tr("状态", "Status"),
      },
      textBoxRow(statusValue),
      {
        type = "Label",
        text = tr("当前 BPM", "Current BPM"),
      },
      textBoxRow(currentBpmValue),
      {
        type = "Label",
        text = tr("原始 BPM", "Original BPM"),
      },
      textBoxRow(originalBpmValue),
      {
        type = "Label",
        text = tr("缩放锚点", "Anchor"),
      },
      {
        type = "Container",
        columns = {
          {
            type = "ComboBox",
            choices = {
              tr("音符组内部 0 位置", "Note group local 0"),
              tr("第一个音符起点", "First note onset"),
            },
            value = anchorModeValue,
            width = 1.0,
          },
        },
      },
      checkboxRow(tr("同时缩放参数曲线", "Also rescale automation"), processAutomationValue),
      checkboxRow(
        tr("同时缩放 Studio 2 音高控制点/曲线", "Also rescale Studio 2 pitch controls"),
        processPitchControlsValue
      ),
      {
        type = "Container",
        columns = {
          {
            type = "Button",
            text = tr("检测 BPM", "Detect BPM"),
            value = detectButtonValue,
            width = 0.45,
          },
          {
            type = "Button",
            text = tr("运行", "Run"),
            value = runButtonValue,
            width = 0.55,
          },
        },
      },
    },
  }
end
