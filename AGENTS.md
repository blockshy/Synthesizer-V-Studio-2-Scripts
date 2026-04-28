# Project Instructions

## Project

This repository contains scripts for Synthesizer V Studio 2, a singing voice synthesis application. The official scripting manual is:

https://resource.dreamtonics.com/scripting/

Use the official manual as the primary source for API behavior. When an API differs between Synthesizer V Studio versions, prefer guarded compatibility code instead of assuming that every user has the same minor version.

## Directory Structure

Scripts are organized by author/category and then by script folder:

```text
BlockShy/
  Script_Name/
    Script_Name.lua
    README.zh.md
    README.en.md
```

Rules:

- One script lives in one folder.
- Each script folder must contain localized README files in Chinese and English.
- When script behavior changes, update both README files in the same folder.
- Keep `getClientInfo()` metadata accurate, especially `name`, `category`, `author`, `versionNumber`, and `minEditorVersion`.

## Scripting Guidelines

- Prefer documented Synthesizer V APIs over ad hoc assumptions.
- Avoid fixed finite blick ranges when processing all automation data; use APIs such as `Automation:getAllPoints()` when available.
- Validate user input from `SV:showCustomDialog()` before changing project data.
- Warn users before broad transformations that may affect shared note group targets or projects with multiple tempo marks.
- Use `pcall` around optional or version-dependent APIs, such as Studio 2 pitch controls or compatibility-only parameter names.
- Preserve musical values when moving timing data: rescale note start and end positions, then derive duration from the new boundaries.
- Be explicit about collision behavior when multiple automation points map to the same blick after scaling.
- Keep edits scoped to the requested script and its documentation unless the task explicitly asks for repository-wide changes.

## Verification

Installed Lua tooling:

- `lua` / `luac`: Lua 5.4.8
- `luacheck`: 1.2.0
- `stylua`: 2.4.1
- `luarocks`: 3.12.2, used for installing `luacheck`

Tool paths:

- Unified command entry: `/huyu/software/bin`
- Lua runtime: `/huyu/environment/lua-5.4.8`
- LuaRocks / luacheck: `/huyu/software/luarocks`
- StyLua: `/huyu/software/stylua-2.4.1`

Repository verification config:

- `luacheck` uses `.luacheckrc`.
- `stylua` uses `.stylua.toml`.

Before finishing script changes:

- Run `lua -v` if the Lua toolchain availability is uncertain.
- Run `luac -p your.lua` on changed `.lua` files.
- Run `luacheck your.lua` on changed `.lua` files.
- Run `stylua --check your.lua` on changed `.lua` files.
- Check the final directory layout with `rg --files`.
- Review `git status --short` and avoid reverting unrelated user changes.
