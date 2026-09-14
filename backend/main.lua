--[[
  今天玩什么 (What to Play Today) — Lua 后端入口
  backend/main.lua 暴露若干全局函数，前端通过
  Millennium.callServerMethod("what-to-play-today", "方法名", 参数) 调用。

  本插件前端优先使用 SteamClient.InstallFolder.GetInstallFolders() 获取已安装游戏，
  当该接口不可用（Steam 版本差异）时，回退调用本后端的 GetInstalledGames()，
  直接扫描 steamapps/libraryfolders.vdf 与 appmanifest_*.acf。
]]

local millennium = require("millennium")
local json = require("json")
local logger = require("logger")
local library = require("library")
local fs = require("fs")
local utils = require("utils")

--- 让空表序列化成 [] 而不是 {}
local function as_array(t)
  return setmetatable(t or {}, { __jsontype = "array" })
end

--- 返回库中已安装的游戏清单（JSON 字符串）
---@return string
function GetInstalledGames()
  local ok, result = pcall(library.scan_installed_games)
  if not ok then
    logger:error("[WhatToPlay] scan installed games failed: " .. tostring(result))
    return json.encode({ ok = false, error = tostring(result), games = as_array({}) })
  end
  return json.encode({ ok = true, games = as_array(result) })
end

--- 黑名单持久化文件路径
local function blacklist_path()
  local steam_path = millennium.steam_path()
  if not steam_path or steam_path == "" then return nil end
  return fs.join(steam_path, "millennium", "plugins", "what-to-play-today", "blacklist.json")
end

--- 读取黑名单（返回 JSON 字符串：{ ok=true, blacklist=[appid,...] }）
---@return string
function GetBlacklist()
  local path = blacklist_path()
  if not path or not fs.exists(path) then
    return json.encode({ ok = true, blacklist = as_array({}) })
  end
  local content = utils.read_file(path)
  if not content then
    return json.encode({ ok = true, blacklist = as_array({}) })
  end
  -- 直接返回文件内容（前端解析 JSON）
  local decoded = json.decode(content)
  if not decoded or not decoded.blacklist then
    return json.encode({ ok = true, blacklist = as_array({}) })
  end
  return json.encode({ ok = true, blacklist = as_array(decoded.blacklist) })
end

--- 保存黑名单（参数：JSON 数组字符串 [appid,...]）
---@param data string
---@return string
function SaveBlacklist(data)
  local path = blacklist_path()
  if not path then
    return json.encode({ ok = false, error = "cannot resolve blacklist path" })
  end
  -- 确保目录存在
  local dir = fs.join(millennium.steam_path(), "millennium", "plugins", "what-to-play-today")
  if not fs.exists(dir) then
    return json.encode({ ok = false, error = "plugin dir not found: " .. tostring(dir) })
  end
  -- data 已是 JSON 字符串，直接解析再重新编码确保格式
  local list = json.decode(data)
  if not list then
    list = {}
  end
  local payload = json.encode({ blacklist = as_array(list) })
  -- 使用 io.open 写入文件
  local file, err = io.open(path, "w")
  if not file then
    logger:error("[WhatToPlay] open blacklist file for write failed: " .. tostring(err))
    return json.encode({ ok = false, error = tostring(err) })
  end
  file:write(payload)
  file:close()
  logger:info("[WhatToPlay] blacklist saved, " .. #list .. " entries")
  return json.encode({ ok = true })
end

--- 后端连通性检查
---@return string
function Ping()
  return json.encode({ ok = true, plugin = "what-to-play-today", version = "1.0.0" })
end

--- 接收前端定位诊断日志（锚点候选数量 / 命中模式 / 最终坐标），写入插件日志
--- 用于排查「骰子按钮不可见 / 位置不对」问题：Steam 设置 → Millennium → 插件日志
---@param text string
---@return string
function LogDiag(text)
  local ok, err = pcall(function()
    logger:info("[WhatToPlay][diag] " .. tostring(text))
  end)
  if not ok then
    return json.encode({ ok = false, error = tostring(err) })
  end
  return json.encode({ ok = true })
end

--- 隐藏窗口打开 URL（Windows 用 rundll32，不经过 cmd）
--- 用系统默认浏览器打开 URL（避免 Steam 内置浏览器卡死）
---@param url string
---@return string
function OpenInBrowser(url)
  if not url or url == "" then
    return json.encode({ ok = false, error = "empty url" })
  end
  -- 只允许 http/https 协议，防止任意命令注入
  if not (url:sub(1, 7) == "http://" or url:sub(1, 8) == "https://") then
    return json.encode({ ok = false, error = "only http(s) allowed" })
  end
  if package.config:sub(1, 1) == "\\" then
    -- Windows: rundll32 不经过 cmd，不弹窗口
    os.execute('rundll32 url.dll,FileProtocolHandler "' .. url .. '"')
  else
    os.execute(string.format('xdg-open "%s" 2>/dev/null || open "%s" 2>/dev/null', url, url))
  end
  logger:info("[WhatToPlay] opened in browser: " .. url)
  return json.encode({ ok = true })
end

--- 缓存文件路径
local function cache_path()
  local steam_path = millennium.steam_path()
  if not steam_path or steam_path == "" then return nil end
  return fs.join(steam_path, "millennium", "plugins", "what-to-play-today", "games_cache.json")
end

--- 读取游戏列表缓存
---@return string
function GetGamesCache()
  local cpath = cache_path()
  if not cpath or not fs.exists(cpath) then
    return json.encode({ ok = false })
  end
  local content = utils.read_file(cpath)
  if not content then
    return json.encode({ ok = false })
  end
  return json.encode({ ok = true, data = content })
end

--- 保存游戏列表缓存（前端 fetch 到数据后调用）
---@param data string  JSON 字符串 { games: [...], game_count: N }
---@return string
function SaveGamesCache(data)
  local cpath = cache_path()
  if not cpath then
    return json.encode({ ok = false, error = "no cache path" })
  end
  local payload = json.encode({ ts = os.time(), data = data })
  local file = io.open(cpath, "w")
  if not file then
    return json.encode({ ok = false, error = "cannot write cache" })
  end
  file:write(payload)
  file:close()
  logger:info("[WhatToPlay] games cache saved")
  return json.encode({ ok = true })
end

local function on_load()
  logger:info("[WhatToPlay] backend loaded, Millennium version: " .. tostring(millennium.version()))
  millennium.ready()
end

local function on_frontend_loaded()
  logger:info("[WhatToPlay] frontend loaded, plugin ready")
end

local function on_unload()
  logger:info("[WhatToPlay] backend unloaded")
end

return {
  on_load = on_load,
  on_frontend_loaded = on_frontend_loaded,
  on_unload = on_unload,
}
