# hammerspoons

Personal [Hammerspoon](https://www.hammerspoon.org) Spoons, laid out as a Spoon
repository so they can be installed with
[SpoonInstall](https://www.hammerspoon.org/Spoons/SpoonInstall.html).

## Spoons

| Spoon | What it does | Permission needed |
|---|---|---|
| `ITerm2WindowChooser` | Fuzzy-searchable chooser over every iTerm2 window, across all macOS Spaces | Automation (to control iTerm2) |
| `XcodeSCStatus` | Toggles Xcode's "Files with source-control status" checkbox in the Project Navigator | Accessibility |

## Install

In your `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.armcknight = {
    url = "https://github.com/armcknight/hammerspoons",
    desc = "armcknight's personal Spoons",
    branch = "main",
}

spoon.SpoonInstall:andUse("ITerm2WindowChooser", {
    repo = "armcknight",
    fn = function(s) s:bindHotkeys({ "ctrl", "alt", "cmd" }, "W") end,
})

spoon.SpoonInstall:andUse("XcodeSCStatus", {
    repo = "armcknight",
    fn = function(s) s:bindHotkeys({ "ctrl", "alt", "cmd" }, "S") end,
})
```

`branch = "main"` is required — SpoonInstall defaults to `master`, which does
not exist here.

Both Spoons take `bindHotkeys(mods, key)` positionally rather than the upstream
Spoon `bindHotkeys(mapping)` convention, which is why the snippet above uses
`fn` rather than SpoonInstall's `hotkeys` option.

### Without SpoonInstall

Download the zip from `Spoons/` and unpack it into `~/.hammerspoon/Spoons/`, or
copy the directory straight out of `Source/`. Then:

```lua
hs.loadSpoon("ITerm2WindowChooser")
spoon.ITerm2WindowChooser:bindHotkeys({ "ctrl", "alt", "cmd" }, "W")
```

## ITerm2WindowChooser notes

The chooser lists iTerm2's *session* names, not macOS window titles. iTerm2's
titlebar is driven by the profile's "Title components" setting and usually
shows job + working directory, which is near-useless when several windows sit
in different checkouts of the same repo. The session name is whatever the shell
last wrote via OSC, so it's worth making that useful. With fish:

```fish
function fish_title
    set -l branch (git branch --show-current 2>/dev/null)
    if test -n "$branch"
        echo -- (prompt_pwd)" [$branch]"
    else
        echo -- (prompt_pwd)
    end
end
```

Inside tmux that only sets the *pane* title, so tmux has to forward it out:

```tmux
set -g set-titles on
set -g set-titles-string "#{pane_title}"
```

Beyond `:show()`, the Spoon exposes `:windows()` — returning
`{ id, name, job }` per window — so the AppleScript parsing can be exercised
without opening the UI.

## Repo layout

```
Source/<Name>.spoon/     editable source — change this
Spoons/<Name>.spoon.zip  installable artifacts, committed; regenerate via ./build.sh
docs/docs.json           repo index SpoonInstall reads to resolve names
```

After editing anything in `Source/`, run `./build.sh` and commit the refreshed
zips. Adding or renaming a Spoon also means updating `docs/docs.json`.

## License

MIT — see [LICENSE](LICENSE).
