local repoRoot = arg[1] or "."

local blockshyRoot = repoRoot .. "/BlockShy"
local managerPath = blockshyRoot .. "/Script_Manager/Script_Manager.lua"

local function readFile(path)
  local handle = assert(io.open(path, "rb"), "cannot open " .. path)
  local content = assert(handle:read("*a"))
  handle:close()
  return content
end

local function writeFile(path, content)
  local handle = assert(io.open(path, "wb"), "cannot write " .. path)
  assert(handle:write(content))
  handle:close()
end

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function normalizeText(value)
  value = tostring(value or "")
  value = value:gsub("\r\n", "\n")
  value = value:gsub("\r", "\n")
  value = value:gsub("[ \t]+", " ")
  value = value:gsub("\n%s*\n", "\n")
  return trim(value)
end

local function shellQuote(path)
  return "'" .. tostring(path):gsub("'", "'\\''") .. "'"
end

local function luaQuote(value)
  return string.format("%q", tostring(value or ""))
end

local function makeSVStub()
  local stub = {}
  setmetatable(stub, {
    __index = function()
      return function()
        return nil
      end
    end,
  })
  return stub
end

local function createScriptEnvironment()
  local env = {
    SV = makeSVStub(),
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
  return env
end

local function getScriptInfo(path, source)
  local env = createScriptEnvironment()
  local chunk, loadError = load(source, "@" .. path, "t", env)
  if chunk == nil then
    return nil, loadError
  end

  local ok, runtimeError = pcall(chunk)
  if not ok then
    return nil, runtimeError
  end

  if type(env.getClientInfo) ~= "function" or type(env.main) ~= "function" then
    return nil, "missing getClientInfo() or main()"
  end

  local infoOk, info = pcall(env.getClientInfo)
  if not infoOk or type(info) ~= "table" then
    return nil, "getClientInfo() did not return a table"
  end

  if info.type == "SidePanelSection" then
    return nil, "side panel script"
  end

  return info, nil
end

local function listLuaFiles()
  local command = "find " .. shellQuote(blockshyRoot) .. " -mindepth 2 -maxdepth 2 -type f -name '*.lua' | sort"
  local pipe = assert(io.popen(command, "r"), "cannot scan script files")
  local files = {}

  for line in pipe:lines() do
    table.insert(files, line)
  end

  local ok, _, status = pipe:close()
  if not ok and status ~= 0 then
    error("find command failed")
  end

  return files
end

local function splitScriptPath(path)
  local folder, file = path:match("/BlockShy/([^/]+)/([^/]+%.lua)$")
  if folder == nil then
    folder, file = path:match("^%.?/BlockShy/([^/]+)/([^/]+%.lua)$")
  end
  return folder, file
end

local function getReadmePath(folder, language)
  return blockshyRoot .. "/" .. folder .. "/README." .. language .. ".md"
end

local function tryReadFile(path)
  local handle = io.open(path, "rb")
  if handle == nil then
    return nil
  end

  local content = handle:read("*a")
  handle:close()
  return content
end

local function getSection(markdown, names)
  if markdown == nil then
    return nil
  end

  markdown = markdown:gsub("\r\n", "\n"):gsub("\r", "\n")

  for _, name in ipairs(names) do
    local pattern = "\n##%s+" .. name .. "%s*\n(.-)\n##%s+"
    local section = markdown:match(pattern)
    if section ~= nil then
      return section
    end

    section = markdown:match("\n##%s+" .. name .. "%s*\n(.+)$")
    if section ~= nil then
      return section
    end
  end

  return nil
end

local function firstParagraph(section)
  if section == nil then
    return nil
  end

  section = section:gsub("\r\n", "\n"):gsub("\r", "\n")
  for block in section:gmatch("[^\n][^\n]*(.-)\n%s*\n") do
    local value = normalizeText(block)
    if value ~= "" and not value:match("^%-") then
      return value
    end
  end

  local fallback = normalizeText(section:match("([^\n]+)") or "")
  if fallback ~= "" then
    return fallback
  end

  return nil
end

local function numberedLines(section, limit)
  local lines = {}
  if section == nil then
    return lines
  end

  for line in section:gmatch("[^\n]+") do
    local text = line:match("^%s*%d+%.%s*(.+)$")
    if text ~= nil then
      table.insert(lines, trim(text))
      if #lines >= limit then
        return lines
      end
    end
  end

  return lines
end

local function buildDescription(folder, info)
  local zhReadme = tryReadFile(getReadmePath(folder, "zh"))
  local enReadme = tryReadFile(getReadmePath(folder, "en"))
  local featureSection = getSection(zhReadme, { "功能" }) or getSection(enReadme, { "Features", "Feature" })
  local usageSection = getSection(zhReadme, { "用法" }) or getSection(enReadme, { "Usage" })
  local usageLines = numberedLines(usageSection, 4)
  local requires = usageLines[1] or "请在运行前完成脚本所需的选择。"
  local usage = "运行后按脚本弹窗提示设置参数。"

  if #usageLines > 1 then
    usage = table.concat(usageLines, "\n")
  elseif #usageLines == 1 then
    usage = usageLines[1]
  end

  return {
    summary = firstParagraph(featureSection) or tostring(info.name or folder),
    requires = requires,
    usage = usage,
  }
end

local function collectScripts()
  local scripts = {}
  local files = listLuaFiles()

  for _, path in ipairs(files) do
    local folder, file = splitScriptPath(path)
    if folder ~= nil and folder ~= "Script_Manager" then
      local source = readFile(path)
      local info = getScriptInfo(path, source)
      if info ~= nil then
        local description = buildDescription(folder, info)
        table.insert(scripts, {
          folder = folder,
          file = file,
          sourceKey = folder,
          name = info.name or folder,
          version = "V" .. tostring(info.versionNumber or 1),
          summary = description.summary,
          requires = description.requires,
          usage = description.usage,
          source = source,
        })
      end
    end
  end

  table.sort(scripts, function(left, right)
    return left.name:lower() < right.name:lower()
  end)

  return scripts
end

local function makeLongBracket(value)
  value = tostring(value or "")
  local level = 4

  while value:find("]" .. string.rep("=", level) .. "]", 1, true) do
    level = level + 1
  end

  local equals = string.rep("=", level)
  local suffix = ""
  if value:sub(-1) ~= "\n" then
    suffix = "\n"
  end

  return "[" .. equals .. "[\n" .. value .. suffix .. "]" .. equals .. "]"
end

local function renderEntries(scripts)
  local lines = { "  -- MANAGED_SCRIPT_ENTRIES_START" }

  for _, script in ipairs(scripts) do
    table.insert(lines, "  {")
    table.insert(lines, "    name = " .. luaQuote(script.name) .. ",")
    table.insert(lines, "    folder = " .. luaQuote(script.folder) .. ",")
    table.insert(lines, "    file = " .. luaQuote(script.file) .. ",")
    table.insert(lines, "    sourceKey = " .. luaQuote(script.sourceKey) .. ",")
    table.insert(lines, "    version = " .. luaQuote(script.version) .. ",")
    table.insert(lines, "    requires = " .. luaQuote(script.requires) .. ",")
    table.insert(lines, "    summary = " .. luaQuote(script.summary) .. ",")
    table.insert(lines, "    usage = " .. luaQuote(script.usage) .. ",")
    table.insert(lines, "  },")
  end

  table.insert(lines, "  -- MANAGED_SCRIPT_ENTRIES_END")
  return table.concat(lines, "\n")
end

local function renderSources(scripts)
  local lines = { "  -- EMBEDDED_SOURCES_START" }

  for _, script in ipairs(scripts) do
    table.insert(lines, "  [" .. luaQuote(script.sourceKey) .. "] = " .. makeLongBracket(script.source) .. ",")
  end

  table.insert(lines, "  -- EMBEDDED_SOURCES_END")
  return table.concat(lines, "\n")
end

local function replaceGeneratedBlock(content, startMarker, endMarker, replacement)
  local pattern = "%s*%-%- " .. startMarker .. "\n.-%s*%-%- " .. endMarker
  local updated, replacements = content:gsub(pattern, function()
    return "\n" .. replacement
  end)
  assert(replacements == 1, "marker block not found: " .. startMarker)
  return updated
end

local function main()
  local scripts = collectScripts()
  assert(#scripts > 0, "no managed scripts found")

  local manager = readFile(managerPath)
  manager =
    replaceGeneratedBlock(manager, "MANAGED_SCRIPT_ENTRIES_START", "MANAGED_SCRIPT_ENTRIES_END", renderEntries(scripts))
  manager = replaceGeneratedBlock(manager, "EMBEDDED_SOURCES_START", "EMBEDDED_SOURCES_END", renderSources(scripts))
  writeFile(managerPath, manager)

  print("Updated " .. managerPath)
  for _, script in ipairs(scripts) do
    print("- " .. script.name .. " " .. script.version .. " (" .. script.folder .. "/" .. script.file .. ")")
  end
end

main()
