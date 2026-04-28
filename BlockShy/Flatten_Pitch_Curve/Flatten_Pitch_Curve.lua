function getClientInfo()
  return {
    name = "Flatten Pitch Curve",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 4,
    minEditorVersion = 131330,
    type = "SidePanelSection",
  }
end

local SCOPE_NOTES = "notes"
local SCOPE_GROUPS = "groups"
local SCOPE_BOTH = "both"
local languageValue = nil

local function safeCall(fn)
  local ok, result = pcall(fn)
  if ok then
    return result
  end
  return nil
end

local function isEnglish()
  if languageValue == nil then
    return false
  end

  return safeCall(function()
    return languageValue:getValue()
  end) == 1
end

local function tr(zh, en)
  if isEnglish() then
    return en
  end

  return zh
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

  local summary = tr(
    "音高曲线已抹平。\n处理音符组目标: ",
    "Pitch curve flattened.\nNote group targets: "
  ) .. #operations .. tr("\n处理范围: ", "\nRanges: ") .. totalRanges .. tr(
    "\n水平音高线目标音符: ",
    "\nFlat pitch target notes: "
  ) .. totalNotes

  if options.drawFlatPitchControls then
    summary = summary
      .. tr("\n水平 Pitch Control Curve: 创建 ", "\nHorizontal Pitch Control Curve: created ")
      .. drawnControlStats.created
      .. tr(" 条", " curves")

    if drawnControlStats.failed > 0 then
      summary = summary .. tr("，失败 ", ", failed ") .. drawnControlStats.failed .. tr(" 条", " curves")
    end

    if drawnControlStats.unsupported > 0 then
      summary = summary
        .. tr(
          "\n不支持写入 Pitch Control Curve 的目标: ",
          "\nTargets that do not support Pitch Control Curve writing: "
        )
        .. drawnControlStats.unsupported
    end
  end

  if options.flattenPitchDelta then
    summary = summary
      .. tr("\npitchDelta: 删除 ", "\npitchDelta: removed ")
      .. pitchStats.removed
      .. tr(" 点，写入 ", " points, wrote ")
      .. pitchStats.created
      .. tr(" 个 0 点，更新 ", " zero points, updated ")
      .. pitchStats.updated
      .. tr(" 点", " points")

    if pitchStats.unavailable > 0 then
      summary = summary
        .. tr("\n不可用 pitchDelta 目标: ", "\nUnavailable pitchDelta targets: ")
        .. pitchStats.unavailable
    end
  end

  if options.clearPitchControls then
    summary = summary
      .. tr("\n原有 Studio 2 音高控制: 移除 ", "\nExisting Studio 2 pitch controls: removed ")
      .. removedControlStats.removed
      .. tr(" 个对象", " objects")
    if removedControlStats.unsupported > 0 then
      summary = summary
        .. tr("\n不支持音高控制 API 的目标: ", "\nTargets that do not support pitch control APIs: ")
        .. removedControlStats.unsupported
    end
  end

  summary = summary
    .. tr(
      "\n\n提示: 本脚本修改音符组目标。如果目标被多个引用复用，其他引用也会同步变化。",
      "\n\nNote: This script edits note group targets. "
        .. "If a target is reused by multiple references, those references will change as well."
    )

  return summary
end

local scopeValue = nil
local drawFlatPitchControlsValue = nil
local flattenPitchDeltaValue = nil
local clearPitchControlsValue = nil
local protectOutsideValue = nil
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

local function getSelectionStatus()
  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)
  local selectedGroups = getSelectedGroups(editor)

  return tr("选中音符: ", "Selected notes: ")
    .. #selectedNotes
    .. tr(" | 选中音符组: ", " | selected note groups: ")
    .. #selectedGroups
end

local function updateStatus()
  setWidgetValue(statusValue, getSelectionStatus())
end

local function resolvePanelScope(selectedNotes, _selectedGroups)
  local choice = getWidgetValue(scopeValue, 0) or 0

  if choice == 1 then
    return SCOPE_NOTES
  end

  if choice == 2 then
    return SCOPE_GROUPS
  end

  if choice == 3 then
    return SCOPE_BOTH
  end

  if #selectedNotes > 0 then
    return SCOPE_NOTES
  end

  return SCOPE_GROUPS
end

local function runPanel()
  if isRunning then
    return
  end

  isRunning = true

  local editor = SV:getMainEditor()
  local selection = editor:getSelection()
  local selectedNotes = getSortedSelectedNotes(selection)
  local selectedGroups = getSelectedGroups(editor)

  if #selectedNotes == 0 and #selectedGroups == 0 then
    showMessage(
      tr("提示", "Notice"),
      tr(
        "请先在钢琴窗选中音符，或在轨道中选中音符组。",
        "Select notes in the piano roll, or select note groups in the arrangement first."
      )
    )
    isRunning = false
    return
  end

  local currentGroup = editor:getCurrentGroup()
  if #selectedNotes > 0 and currentGroup == nil then
    showMessage(
      tr("错误", "Error"),
      tr(
        "检测到选中音符，但未检测到当前音符组。",
        "Selected notes were detected, but no current note group was found."
      )
    )
    isRunning = false
    return
  end

  local options = {
    scope = resolvePanelScope(selectedNotes, selectedGroups),
    drawFlatPitchControls = getWidgetValue(drawFlatPitchControlsValue, true),
    flattenPitchDelta = getWidgetValue(flattenPitchDeltaValue, true),
    clearPitchControls = getWidgetValue(clearPitchControlsValue, true),
    protectOutside = getWidgetValue(protectOutsideValue, true),
  }

  if not options.drawFlatPitchControls and not options.flattenPitchDelta and not options.clearPitchControls then
    showMessage(tr("提示", "Notice"), tr("没有启用任何处理项。", "No processing option is enabled."))
    isRunning = false
    return
  end

  local operations = buildOperations(options.scope, currentGroup, selectedNotes, selectedGroups)
  if #operations == 0 then
    showMessage(
      tr("提示", "Notice"),
      tr("没有找到可处理的有效范围。", "No valid processable range was found.")
    )
    isRunning = false
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

  showMessage(tr("完成", "Done"), buildSummary(operations, pitchStats, controlStats, drawnControlStats, options))
  updateStatus()
  isRunning = false
end

local function initializePanel()
  if initialized then
    return
  end

  initialized = true
  languageValue = createWidgetValue(0)
  scopeValue = createWidgetValue(0)
  drawFlatPitchControlsValue = createWidgetValue(true)
  flattenPitchDeltaValue = createWidgetValue(true)
  clearPitchControlsValue = createWidgetValue(true)
  protectOutsideValue = createWidgetValue(true)
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

function getSidePanelSectionState()
  initializePanel()

  return {
    title = "Flatten Pitch Curve",
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
        text = tr("处理范围", "Scope"),
      },
      {
        type = "Container",
        columns = {
          {
            type = "ComboBox",
            choices = {
              tr("自动：优先音符", "Auto: prefer notes"),
              tr("选中音符", "Selected notes"),
              tr("选中音符组", "Selected note groups"),
              tr("选中音符 + 音符组", "Selected notes + note groups"),
            },
            value = scopeValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Container",
        columns = {
          {
            type = "CheckBox",
            text = tr("绘制水平 Studio 2 Pitch Control Curve", "Draw horizontal Studio 2 Pitch Control Curve"),
            value = drawFlatPitchControlsValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Container",
        columns = {
          {
            type = "CheckBox",
            text = tr("同时清零 pitchDelta 曲线", "Also reset the pitchDelta curve"),
            value = flattenPitchDeltaValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Container",
        columns = {
          {
            type = "CheckBox",
            text = tr(
              "先移除范围内原有 Studio 2 音高控制",
              "First remove existing Studio 2 pitch controls in range"
            ),
            value = clearPitchControlsValue,
            width = 1.0,
          },
        },
      },
      {
        type = "Container",
        columns = {
          {
            type = "CheckBox",
            text = tr("保护选区外相邻 pitchDelta 曲线", "Protect adjacent pitchDelta curve outside selection"),
            value = protectOutsideValue,
            width = 1.0,
          },
        },
      },
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
