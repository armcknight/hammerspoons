--- === ITerm2WindowChooser ===
---
--- Fuzzy-searchable chooser over every iTerm2 window, across all macOS Spaces.
---
--- Reads iTerm2 over AppleScript rather than using `hs.window`, because the
--- macOS window title isn't useful here: iTerm2's titlebar is governed by the
--- profile's "Title components" setting, which by default renders job +
--- working directory ("work term ~/d/billing") for every window. The *session*
--- name is separately settable — the shell's title (fish's `fish_title`,
--- forwarded out of tmux by `set-titles`) writes "<path> [<branch>]" into it —
--- but iTerm2 doesn't surface that in the window title without a profile
--- change. Reading it directly over AppleScript sidesteps that entirely.
---
--- Focusing also goes through iTerm2 (`select` + `activate`) rather than
--- `hs.window:focus()`, which means macOS handles the Space switch itself —
--- no `hs.spaces`, whose private CGSInternal APIs are unreliable on recent
--- macOS.
---
--- Requires Automation permission for Hammerspoon to control iTerm2 (macOS
--- prompts once on first use).

local obj = {}
obj.__index = obj

obj.name = "ITerm2WindowChooser"
obj.version = "1.0.0"
obj.author = "Andrew McKnight (andrew@mcknight.rocks)"
obj.homepage = "https://github.com/armcknight/hammerspoons"
obj.license = "Apache-2.0"

--- ITerm2WindowChooser.appName
--- Variable
--- Application name used for both the running-app check and the AppleScript
--- `tell` target. Change alongside `bundleID` if you fork this for another
--- terminal with a comparable AppleScript dictionary.
obj.appName = "iTerm2"

--- ITerm2WindowChooser.bundleID
--- Variable
--- Bundle identifier, used only to pull the chooser row icon.
obj.bundleID = "com.googlecode.iterm2"

obj.hotkey = nil

-- Emit one "<window id>|<current session name>" line per window. The session
-- name is wrapped in a `try` because a window mid-teardown can fail to answer.
local LIST_SCRIPT = [[
tell application "%s"
    set out to ""
    repeat with w in windows
        set sname to ""
        try
            set sname to name of current session of w
        end try
        set out to out & (id of w as text) & "|" & sname & "
"
    end repeat
    return out
end tell
]]

local FOCUS_SCRIPT = [[
tell application "%s"
    repeat with w in windows
        if (id of w as text) is "%s" then
            select w
            exit repeat
        end if
    end repeat
    activate
end tell
]]

-- iTerm2 renders session names as "<name> (<job>)". Split so the chooser's
-- primary text is the name the shell set and the job lands in the subtitle.
-- Falls back to the whole string when there's no parenthesised job.
local function splitSessionName(sessionName)
  local name, job = sessionName:match("^(.*) %((.-)%)$")
  if not name or name == "" then
    return sessionName, nil
  end
  return name, job
end

--- ITerm2WindowChooser:windows()
--- Method
--- Returns a list of `{ id = <string>, name = <string>, job = <string|nil> }`
--- for every open window, or nil plus an error string.
function obj:windows()
  local ok, output = hs.osascript.applescript(string.format(LIST_SCRIPT, self.appName))
  if not ok or not output then
    return nil, "could not query " .. self.appName .. " windows"
  end

  local windows = {}
  for line in tostring(output):gmatch("[^\r\n]+") do
    local winID, sessionName = line:match("^(%d+)|(.*)$")
    if winID then
      local name, job = splitSessionName(sessionName)
      if name and name ~= "" then
        table.insert(windows, { id = winID, name = name, job = job })
      end
    end
  end
  return windows
end

--- ITerm2WindowChooser:focus(winID)
--- Method
--- Brings the window with the given AppleScript id to the front, switching
--- Spaces if needed. Returns true on success.
function obj:focus(winID)
  local ok, _, err = hs.osascript.applescript(
    string.format(FOCUS_SCRIPT, self.appName, winID)
  )
  if not ok then
    print(self.name .. ": focus failed: " .. hs.inspect(err))
  end
  return ok
end

--- ITerm2WindowChooser:show()
--- Method
--- Displays the chooser. No-ops with an alert if the app isn't running or has
--- no windows.
function obj:show()
  if not hs.application.find(self.appName) then
    hs.alert(self.appName .. " is not running")
    return self
  end

  local windows, err = self:windows()
  if not windows then
    hs.alert(err)
    return self
  end
  if #windows == 0 then
    hs.alert("No " .. self.appName .. " windows")
    return self
  end

  local icon = hs.image.imageFromAppBundle(self.bundleID)
  local choices = {}
  for _, w in ipairs(windows) do
    table.insert(choices, {
      text = w.name,
      subText = w.job and ("job: " .. w.job) or ("window " .. w.id),
      image = icon,
      winID = w.id,
    })
  end

  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    if not self:focus(choice.winID) then
      hs.alert("Could not focus that " .. self.appName .. " window")
    end
  end)
  chooser:choices(choices)
  chooser:show()
  return self
end

--- ITerm2WindowChooser:bindHotkeys(mods, key)
--- Method
--- Binds a hotkey that opens the chooser. Signature matches the sibling
--- XcodeSCStatus spoon (positional mods + key) rather than the upstream Spoon
--- `bindHotkeys(mapping)` convention.
--- @param mods table: modifier keys, e.g. {"ctrl","alt","cmd"}
--- @param key string: key, e.g. "W"
function obj:bindHotkeys(mods, key)
  if self.hotkey then self.hotkey:delete() end
  self.hotkey = hs.hotkey.bind(mods, key, function()
    self:show()
  end)
  return self
end

function obj:stop()
  if self.hotkey then
    self.hotkey:delete()
    self.hotkey = nil
  end
  return self
end

return obj
