function getClientInfo()
  return {
    name = "Flatten Pitch Curve",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 1,
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
    }
  end

  return operations[key]
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

  return #ranges
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

local function rangeOverlaps(startPos, endPos, range)
  return endPos >= range.start and startPos <= range.finish
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

local function buildSummary(operations, pitchStats, controlStats, options)
  local totalRanges = 0

  for _, operation in ipairs(operations) do
    totalRanges = totalRanges + #operation.ranges
  end

  local summary = "音高曲线已抹平。\n处理音符组目标: "
    .. #operations
    .. "\n处理范围: "
    .. totalRanges

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
    summary = summary .. "\nStudio 2 音高控制: 移除 " .. controlStats.removed .. " 个对象"
    if controlStats.unsupported > 0 then
      summary = summary .. "\n不支持音高控制 API 的目标: " .. controlStats.unsupported
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
    title = "音高曲线抹平 V1",
    message = "将选中范围内的 pitchDelta 写回 0 cents，并可移除 Studio 2 音高控制对象。",
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
        name = "flattenPitchDelta",
        type = "CheckBox",
        text = "抹平 pitchDelta 曲线到 0 cents",
        default = true,
      },
      {
        name = "clearPitchControls",
        type = "CheckBox",
        text = "移除范围内 Studio 2 音高控制点/曲线",
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
    flattenPitchDelta = result.answers.flattenPitchDelta,
    clearPitchControls = result.answers.clearPitchControls,
    protectOutside = result.answers.protectOutside,
  }

  if not options.flattenPitchDelta and not options.clearPitchControls then
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

  for _, operation in ipairs(operations) do
    if options.flattenPitchDelta then
      local stats = flattenPitchDelta(operation, options)
      pitchStats.removed = pitchStats.removed + stats.removed
      pitchStats.created = pitchStats.created + stats.created
      pitchStats.updated = pitchStats.updated + stats.updated
      if stats.unavailable then
        pitchStats.unavailable = pitchStats.unavailable + 1
      end
    end

    if options.clearPitchControls then
      local stats = removePitchControls(operation)
      controlStats.removed = controlStats.removed + stats.removed
      if stats.unsupported then
        controlStats.unsupported = controlStats.unsupported + 1
      end
    end
  end

  SV:showMessageBox("完成", buildSummary(operations, pitchStats, controlStats, options))
  SV:finish()
end
