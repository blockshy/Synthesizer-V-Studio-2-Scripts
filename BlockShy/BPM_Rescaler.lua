function getClientInfo()
  return {
    name = "BPM Rescaler",
    category = "BlockShy",
    author = "BlockShy",
    versionNumber = 5,
    minEditorVersion = 65537
  }
end

-- 定义需要处理的参数类型列表
local PARAM_TYPES = {"pitchDelta", "vibratoEnv", "loudness", "tension", "breathiness", "voicing", "gender"}

function main()
  local editor = SV:getMainEditor()
  local project = SV:getProject()
  local timeAxis = project:getTimeAxis()

  local currentGroup = editor:getCurrentGroup()
  local groupTarget = currentGroup:getTarget()

  if groupTarget == nil then
    SV:showMessageBox("错误", "未检测到选中的轨道或音符组，请先选中一个轨道。", 0)
    return
  end

  -- 获取当前工程BPM
  local tempoMark = timeAxis:getTempoMarkAt(0)
  local currentBPM = tempoMark.bpm

  -- 用户输入对话框
  local inputForm = {
    title = "BPM 缩放修复 (含参数)",
    message = "当前工程 BPM 为: " .. currentBPM .. "\n请输入该 MIDI/轨道 原始的 BPM:",
    buttons = "OkCancel",
    widgets = {
      {
        name = "orgBpm",
        type = "TextBox",
        label = "原始 BPM (Original BPM)",
        default = tostring(math.floor(currentBPM / 2))
      }
    }
  }

  local result = SV:showCustomDialog(inputForm)
  
  if result.status == "Cancel" then
    return
  end

  local originalBPM = tonumber(result.answers.orgBpm)

  if originalBPM == nil or originalBPM <= 0 then
    SV:showMessageBox("错误", "请输入有效的 BPM 数值！", 0)
    return
  end

  -- 计算缩放比例
  local ratio = currentBPM / originalBPM
  
  -- 定义一个足够大的时间范围，确保覆盖所有参数点 (比如 100 亿 blick)
  local MAX_BLICK = 10000000000 

  -- === 第一步：处理音符 (Note) ===
  local numNotes = groupTarget:getNumNotes()
  local noteList = {}
  
  -- 收集音符
  for i = 1, numNotes do
    table.insert(noteList, groupTarget:getNote(i))
  end

  -- 批量缩放音符
  for i, note in ipairs(noteList) do
    local oldOnset = note:getOnset()
    local oldDur = note:getDuration()
    
    local newOnset = math.floor(oldOnset * ratio)
    local newDur = math.floor(oldDur * ratio)
    
    if newDur < 1 then newDur = 1 end

    note:setOnset(newOnset)
    note:setDuration(newDur)
  end

  -- === 第二步：处理参数曲线 (Automation) ===
  for _, typeName in ipairs(PARAM_TYPES) do
    local track = groupTarget:getParameter(typeName)
    
    if track then
      -- 1. 获取该参数所有的控制点 (从 0 到 极大值)
      -- API 返回的是一个数组，每个元素是 {blick, value}
      local points = track:getPoints(0, MAX_BLICK)
      
      if points and #points > 0 then
        -- 2. 清空旧点
        -- 既然我们已经把数据备份在 points 表里了，就可以安全地移除旧点了
        -- 遍历 points 列表，根据旧的时间点进行移除
        for _, p in ipairs(points) do
           -- p[1] 是时间(blick), p[2] 是数值
           track:remove(p[1])
        end
        
        -- 3. 计算新位置并写回
        for _, p in ipairs(points) do
          local oldBlick = p[1]
          local value = p[2]
          
          local newBlick = math.floor(oldBlick * ratio)
          
          -- 将点写回新的位置
          track:add(newBlick, value)
        end
      end
    end
  end

  SV:finish()
end