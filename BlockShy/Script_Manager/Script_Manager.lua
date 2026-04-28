function getClientInfo()
  return {
    name = "BlockShy Script Manager",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 1,
    minEditorVersion = 131330,
    type = "SidePanelSection",
  }
end

local SCRIPT_TITLE = "BlockShy Script Manager"
local MANAGED_DIRECTORY = "BlockShy"

local SCRIPT_ENTRIES = {
  {
    name = "BPM Rescaler",
    folder = "BPM_Rescaler",
    file = "BPM_Rescaler.lua",
    version = "V6",
    requires = "当前钢琴窗需要有当前音符组。",
    summary = "按 BPM 比例缩放当前音符组目标内的音符、参数曲线和 Studio 2 音高控制。",
    usage = "点击运行后，在弹窗中填写当前 BPM、原始 BPM、缩放锚点和处理范围。",
  },
  {
    name = "Pitch to Parameter",
    folder = "Pitch_To_Param",
    file = "Pitch_To_Param.lua",
    version = "V5",
    requires = "需要先在钢琴窗中选中一个或多个音符。",
    summary = "把选中音符的音高或 pitchDelta 弯音映射为目标参数曲线。",
    usage = "点击运行后，选择目标参数、音高来源、点密度、写入模式和映射强度。",
  },
  {
    name = "Crying Effect",
    folder = "Crying_Effect",
    file = "Crying_Effect.lua",
    version = "V6",
    requires = "需要先在钢琴窗中选中一个或多个音符。",
    summary = "为选中音符生成哭腔参数，包含气声、张力、颤音包络和音高哭腔手势。",
    usage = "点击运行后，直接选择哭腔预设、强度、写入模式和启用参数。",
  },
}

local scriptSelectValue = nil
local scriptInfoValue = nil
local selectionStatusValue = nil
local runButtonValue = nil
local detailsButtonValue = nil
local refreshButtonValue = nil
local initialized = false
local callbacksRegistered = false

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

local function getPathCandidates(entry)
  local managedPath = getManagedPath(entry)
  local siblingPath = "../" .. entry.folder .. "/" .. entry.file
  local authorRootPath = entry.folder .. "/" .. entry.file

  local rawCandidates = {
    managedPath,
    "./" .. managedPath,
    authorRootPath,
    "./" .. authorRootPath,
    siblingPath,
    "./" .. siblingPath,
  }

  local seen = {}
  local candidates = {}
  for _, path in ipairs(rawCandidates) do
    if not seen[path] then
      seen[path] = true
      table.insert(candidates, path)
    end
  end

  return candidates
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
    .. "\n\n管理路径: "
    .. getManagedPath(entry)
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
    loadfile = loadfile,
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

local function loadScriptChunk(path, env)
  if type(loadfile) ~= "function" then
    return nil, "当前 Lua 环境不可用 loadfile。"
  end

  local ok, chunk, loadError = pcall(loadfile, path, "t", env)
  if not ok then
    return nil, chunk
  end

  if chunk == nil then
    return nil, loadError
  end

  return chunk, nil
end

local function compactErrors(errors)
  local lines = {}
  local maxLines = math.min(#errors, 5)

  for i = 1, maxLines do
    table.insert(lines, errors[i])
  end

  if #errors > maxLines then
    table.insert(lines, "...")
  end

  return table.concat(lines, "\n")
end

local function runEntry(entry)
  local env = createScriptEnvironment()
  local errors = {}

  for _, path in ipairs(getPathCandidates(entry)) do
    local chunk, loadError = loadScriptChunk(path, env)
    if chunk ~= nil then
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
      return
    end

    table.insert(errors, path .. ": " .. tostring(loadError))
  end

  SV:showMessageBox(
    "运行失败",
    "无法从管理目录加载 "
      .. entry.name
      .. "。\n\n已尝试:\n"
      .. compactErrors(errors)
      .. "\n\n请确认脚本目录仍保持在 "
      .. MANAGED_DIRECTORY
      .. "/ 下。"
  )
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
    runEntry(getSelectedEntry())
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
