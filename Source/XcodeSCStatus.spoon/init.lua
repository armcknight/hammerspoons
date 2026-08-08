--- === XcodeSCStatus ===
---
--- Toggle Xcode's "Files with source-control status" checkbox in the Project Navigator.
---
--- Requires Accessibility permissions for Hammerspoon.

local obj = {}
obj.__index = obj

obj.name = "XcodeSCStatus"
obj.version = "1.0"
obj.author = "Andrew McKnight (andrew@mcknight.rocks)"
obj.homepage = "https://github.com/armcknight/hammerspoons"
obj.license = "Apache-2.0"

obj.targetLabel = "Files with source-control status"
obj.hotkey = nil

local ax = require("hs.axuielement")
local app = require("hs.application")

-- Depth-first search through AX tree
local function findDescendant(root, predicate, maxDepth)
  maxDepth = maxDepth or 20

  local function walk(node, depth)
    if not node or depth > maxDepth then return nil end

    local ok, attrs = pcall(function() return node:allAttributeValues() end)
    if not ok then return nil end

    if predicate(node, attrs) then
      return node
    end

    local children = attrs.AXChildren or {}
    for _, child in ipairs(children) do
      local found = walk(child, depth + 1)
      if found then return found end
    end
    return nil
  end

  return walk(root, 0)
end

local function getBoolState(attrs)
  -- Common patterns: AXValue = 0/1, AXSelected = true/false
  if attrs.AXValue ~= nil then
    if type(attrs.AXValue) == "number" then return attrs.AXValue ~= 0 end
    if type(attrs.AXValue) == "boolean" then return attrs.AXValue end
  end
  if type(attrs.AXSelected) == "boolean" then return attrs.AXSelected end
  return nil
end

local function clickCenter(el)
  local frame = el:attributeValue("AXFrame")
  if not frame then return false end
  hs.eventtap.leftClick(hs.geometry.rect(frame).center)
  return true
end

local function toggleAXControl(el, attrs)
  -- 1) Try setting AXValue if we can infer state
  local state = getBoolState(attrs)
  if state ~= nil then
    local ok = pcall(function()
      -- Try AXValue first
      if attrs.AXValue ~= nil then
        el:setAttributeValue("AXValue", state and 0 or 1)
      elseif attrs.AXSelected ~= nil then
        el:setAttributeValue("AXSelected", not state)
      end
    end)
    if ok then return true end
  end

  -- 2) Try AXPress (may be one-way in Xcode, but cheap to attempt)
  local actions = el:actionNames() or {}
  for _, a in ipairs(actions) do
    if a == "AXPress" then
      pcall(function() el:performAction("AXPress") end)
      break
    end
  end

  -- 3) Real mouse click fallback (often works when AXPress doesn't)
  return clickCenter(el)
end

function obj:toggle()
  local xcode = app.get("Xcode")
  if not xcode then
    xcode = app.launchOrFocus("Xcode")
  end
  if not xcode then return end

  hs.timer.usleep(200000)

  local axApp = ax.applicationElement(xcode)
  local win = axApp:attributeValue("AXFocusedWindow")
  if not win then
    hs.alert.show("No focused Xcode window")
    return
  end

  local targetTitle = "Files with source-control status"

  local button = findDescendant(win, function(_, a)
    return a.AXRole == "AXCheckBox" and a.AXTitle == targetTitle
  end, 16)

  if not button then
    hs.alert.show("Couldn't find: " .. targetTitle .. "\n(Is the File Navigator visible?)")
    return
  end

  -- Prefer accessibility press action
  local actions = button:actionNames() or {}
  for _, name in ipairs(actions) do
    if name == "AXPress" then
      button:performAction("AXPress")
      return
    end
  end

  local buttonAttrs = button:allAttributeValues() or {}
  if not toggleAXControl(button, buttonAttrs) then
    hs.alert.show("Found it, but couldn't toggle it")
  end
end

--- Binds a hotkey to toggle the setting.
--- @param mods table: modifier keys, e.g. {"ctrl","alt","cmd"}
--- @param key string: key, e.g. "S"
function obj:bindHotkeys(mods, key)
  if self.hotkey then self.hotkey:delete() end
  self.hotkey = hs.hotkey.bind(mods, key, function()
    self:toggle()
  end)
  return self
end

function obj:stop()
  if self.hotkey then
    self.hotkey:delete()
    self.hotkey = nil
  end
end

return obj
