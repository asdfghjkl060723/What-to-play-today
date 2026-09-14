--[[
  library.lua — 通过 Steam 自身的清单文件扫描“已安装的游戏”
  数据来源：
    1. <Steam>/steamapps/libraryfolders.vdf  → 所有库目录（含外接盘 / 其他分区）
    2. <库目录>/steamapps/appmanifest_<appid>.acf → 单个游戏的安装信息
       （name / installdir / SizeOnDisk / StateFlags）
  过滤规则：StateFlags 第 3 位（值 4）为 1 表示“已完全安装”。
]]

local fs = require("fs")
local utils = require("utils")
local logger = require("logger")
local millennium = require("millennium")

local M = {}

local function unescape_vdf(value)
  if not value then return value end
  value = value:gsub("\\\\", "\\")
  value = value:gsub('\\"', '"')
  return value
end

local function read_text(path)
  if not fs.exists(path) then return nil end
  local content, err = utils.read_file(path)
  if not content then
    logger:error("[今天玩什么] 读取文件失败 " .. tostring(path) .. " : " .. tostring(err))
    return nil
  end
  return content
end

--- 收集所有 Steam 库根目录（Steam 安装目录 + libraryfolders.vdf 中登记的目录）
local function library_roots(steam_path)
  local roots, seen = {}, {}

  local function push(path)
    if not path or path == "" then return end
    local normalized = path:gsub("[/\\]+$", "")
    if normalized == "" then return end
    local key = normalized:lower()
    if seen[key] then return end
    seen[key] = true
    table.insert(roots, normalized)
  end

  push(steam_path)

  local vdf = read_text(fs.join(steam_path, "steamapps", "libraryfolders.vdf"))
  if vdf then
    for value in vdf:gmatch('"path"%s+"([^"]+)"') do
      push(unescape_vdf(value))
    end
  end

  return roots
end

--- 解析单个 appmanifest_*.acf，返回游戏信息；未安装完成时返回 nil
local function parse_appmanifest(path, library_path)
  local content = read_text(path)
  if not content then return nil end

  local appid = tonumber(content:match('"appid"%s+"(%d+)"'))
  if not appid then return nil end

  local name = content:match('"name"%s+"([^"]*)"')
  local installdir = content:match('"installdir"%s+"([^"]*)"')
  local size = tonumber(content:match('"SizeOnDisk"%s+"(%d+)"')) or 0
  local flags = tonumber(content:match('"StateFlags"%s+"(%d+)"'))

  -- StateFlags 的第 3 位（=4）为 1 表示已完全安装
  if flags and (math.floor(flags / 4) % 2) ~= 1 then
    return nil
  end

  return {
    appid = appid,
    name = (name and unescape_vdf(name)) or ("App " .. appid),
    install_dir = installdir and unescape_vdf(installdir) or nil,
    sizeOnDisk = size,
    library = library_path,
  }
end

--- 扫描所有库目录，返回已安装游戏列表
---@return table[]
function M.scan_installed_games()
  local steam_path = millennium.steam_path()
  if not steam_path or steam_path == "" then
    logger:error("[今天玩什么] 无法获取 Steam 安装目录")
    return {}
  end

  local games, seen = {}, {}

  for _, root in ipairs(library_roots(steam_path)) do
    local steamapps = fs.join(root, "steamapps")
    if fs.exists(steamapps) and fs.is_directory(steamapps) then
      local entries = fs.list(steamapps)
      for _, entry in ipairs(entries or {}) do
        if entry.is_file and entry.name and entry.name:match("^appmanifest_%d+%.acf$") then
          local info = parse_appmanifest(entry.path, root)
          if info and not seen[info.appid] then
            seen[info.appid] = true
            table.insert(games, info)
          end
        end
      end
    end
  end

  table.sort(games, function(a, b) return tostring(a.name) < tostring(b.name) end)
  logger:info("[今天玩什么] 清单扫描到已安装游戏 " .. #games .. " 款")
  return games
end

return M
