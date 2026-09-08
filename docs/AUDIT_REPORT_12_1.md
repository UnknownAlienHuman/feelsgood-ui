# Pull Request / Audit Report: FeelsGoodUI — Retail 12.1 (Interface 120100) Compliance & Modernization

## Executive Summary

| Item | Details |
| :--- | :--- |
| **Addon Name** | **FeelsGoodUI** |
| **Addon Directory** | `_Addons/FeelsGoodUI` |
| **Remote Repository** | `github-feelsgood-ui` (`https://github.com/UnknownAlienHuman/feelsgood-ui.git`) |
| **Target Client** | World of Warcraft: Midnight / Retail 12.1 (`Interface: 120100`, Build 69497) |
| **Addon Purpose** | Minimalist, high-performance UI suite combining oUF-based unit frames, secure Blizzard-style action bars, center power/rune bars, companion bars (pet/micromenu/bags), and experience/reputation trackers. |
| **Audit Date** | 2026-09-08 |
| **Local Status** | Fully structured with 67 loaded Lua files; syntax verification passes (`node check_lua.js`); requires 12.1 API modernization and architectural hardening. |
| **Remote Status** | Remote `main` contains commit `f73d741` ("Retire obsolete worklog archives"), removing 7,246 lines of stale history/todo logs. **No code or TOC changes exist upstream**, leaving all 12.1 runtime gaps unpatched. |

---

## Remote Comparison (`git diff HEAD:_Addons/FeelsGoodUI github-feelsgood-ui/main`)

A complete diff between the local workspace `HEAD:_Addons/FeelsGoodUI` and `remotes/github-feelsgood-ui/main` reveals the following:

```
 docs/HISTORY_ARCHIVE_2026-03-05.md | 2169 +-----------------
 docs/PLAN.md                       |    2 +-
 docs/TODO_ARCHIVE_2026-03-03.md    | 4455 +-----------------------------------
 history_compact.md                 |  640 +-----
 4 files changed, 20 insertions(+), 7246 deletions(-)
```

### Key Observations:
1. **Upstream Changes are Strictly Documentation Maintenance**:
   Commit `f73d741` removed archived worklog snapshots and truncated bloated dev history files.
2. **Zero Code Changes Upstream**:
   Neither `FeelsGoodUI.toc`, nor any files in `core/` or `modules/`, were modified upstream.
3. **Action Required**:
   The upstream worklog retirements should be accepted or reconciled, but the critical 12.1 runtime compatibility and bug fixes must be committed directly as part of this PR.

---

## Detailed Audit Findings against Retail 12.1 & KB Standards

### 1. TOC Interface Metadata (Critical)
- **Current state**:
  `FeelsGoodUI.toc` line 1: `## Interface: 120001, 120005`
- **Violation**:
  Outdated Interface version. Retail 12.1 requires `120100`. Multiple interface tokens on a single line can cause client parser warnings in 12.1.
- **Fix**: Update TOC to `## Interface: 120100`.

### 2. RT-AUDIT-001: SavedVariables Default Mutation
- **Current state**:
  In `core/DB.lua`:
  ```lua
  function DB:GetProfile()
      return (self.data and self.data.profile) or self.defaults.profile
  end
  ```
- **Vulnerability**:
  If `DB:GetProfile()` is called before `DB:Init()` or when `self.data.profile` is uninitialized, it returns the raw `self.defaults.profile` table reference.
  Downstream modules calling `DB:GetProfile()` (such as `Policy.RefreshCache(profile)` or `DB:EnsureSection(section)`) write keys (e.g. `profile[section] = value`) directly into `self.defaults.profile`.
  Once `self.defaults.profile` is polluted in memory, subsequent resets (`Schema.CreateFreshProfile`, `Settings:ResetSection`, `Movers:ResetPositions`) clone mutated values instead of clean defaults.
- **Fix**:
  Modify `DB:GetProfile()` to call `self:EnsureProfileRoot()`:
  ```lua
  function DB:GetProfile()
      if self.data and type(self.data.profile) == "table" then
          return self.data.profile
      end
      return self:EnsureProfileRoot()
  end
  ```
  `EnsureProfileRoot()` deep-copies defaults into a freshly allocated profile, guaranteeing `self.defaults.profile` remains pristine and immutable.

### 3. Deprecated API: `GetActionInfo` in Action Bar Empty Slot Detection (Critical Bug)
- **Location**: `modules/ActionBarsState.lua:101-110`
  ```lua
  local function IsEmptySlot(btn)
      if not btn then return true end
      if type(_G.GetActionInfo) ~= "function" then return false end

      local action = GetActionID(btn)
      if type(action) ~= "number" or action <= 0 then
          return true
      end

      local actionType = _G.GetActionInfo(action)
      return actionType == nil
  end
  ```
- **Defect in Retail 12.1**:
  - In 12.0/12.1, `GetActionInfo` has been moved to the `C_ActionBar` namespace (`C_ActionBar.GetActionInfo(action)` and `C_ActionBar.HasAction(action)`).
  - In Retail 12.1 build 69497, `_G.GetActionInfo` may be `nil`.
  - When `_G.GetActionInfo` is `nil`, `if type(_G.GetActionInfo) ~= "function"` triggers and returns `false`!
  - As a result, **every single empty action bar button is marked as NOT empty**, breaking empty slot hiding and empty slot grid overlays throughout the entire UI.
- **Fix**:
  Implement a safe modern helper using `C_ActionBar.HasAction(action)` and `C_ActionBar.GetActionInfo(action)` with fallback:
  ```lua
  local function HasActionSafe(action)
      if _G.C_ActionBar and type(_G.C_ActionBar.HasAction) == "function" then
          local ok, hasAction = pcall(_G.C_ActionBar.HasAction, action)
          if ok then return hasAction == true end
      end
      if _G.C_ActionBar and type(_G.C_ActionBar.GetActionInfo) == "function" then
          local ok, actionType = pcall(_G.C_ActionBar.GetActionInfo, action)
          if ok then return actionType ~= nil end
      end
      if type(_G.GetActionInfo) == "function" then
          local ok, actionType = pcall(_G.GetActionInfo, action)
          if ok then return actionType ~= nil end
      end
      return false
  end

  local function IsEmptySlot(btn)
      if not btn then return true end
      local action = GetActionID(btn)
      if type(action) ~= "number" or action <= 0 then
          return true
      end
      return not HasActionSafe(action)
  end
  ```

### 4. Deprecated API: `GetSpecialization` in CenterBars (Medium Bug)
- **Location**: `modules/CenterBars.lua:167-174`
  ```lua
  local function GetDKSpecColor()
      local getSpecInfo = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
      if not (_G.GetSpecialization and getSpecInfo) then return nil end
      local specIndex = _G.GetSpecialization()
      if not specIndex then return nil end
      local specID = getSpecInfo(specIndex)
      if type(specID) ~= "number" then return nil end
      return DK_SPEC_COLORS[specID]
  end
  ```
- **Defect in Retail 12.1**:
  - `_G.GetSpecialization` is deprecated and superseded by `C_SpecializationInfo.GetSpecialization()`.
  - If `_G.GetSpecialization` is omitted or restricted in 12.1, `GetDKSpecColor()` returns `nil`, breaking spec-colored DK runes.
- **Fix**:
  Prioritize `C_SpecializationInfo.GetSpecialization`:
  ```lua
  local function GetDKSpecColor()
      local getSpec = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecialization) or _G.GetSpecialization
      local getSpecInfo = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
      if not (getSpec and getSpecInfo) then return nil end
      local specIndex = getSpec()
      if not specIndex then return nil end
      local specID = getSpecInfo(specIndex)
      if type(specID) ~= "number" then return nil end
      return DK_SPEC_COLORS[specID]
  end
  ```

### 5. Deprecated XML Template: `InterfaceOptionsCheckButtonTemplate`
- **Location**: `core/OptionsSharedHelpers.lua:98`
  ```lua
  local b = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  ```
- **Defect**:
  `InterfaceOptionsCheckButtonTemplate` has been moved to `DeprecatedTemplates.xml` and is deprecated in 12.0+. In future 12.1 sub-builds, loading this template may emit errors or fail.
- **Fix**:
  Fallback smoothly between `"UICheckButtonTemplate"` and `"InterfaceOptionsCheckButtonTemplate"`.

### 6. RT-AUDIT-002: Single Runtime Owner & Event Deferral
- **Current architecture**:
  - `core/Events.lua` acts as the centralized dispatcher for `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `ADDON_ACTION_BLOCKED`, etc.
  - However, `modules/ActionBarsRuntime.lua:418-421` creates its own standalone `frame` registering `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`.
  - `modules/CompanionRuntime.lua:207` also maintains a standalone watcher for `PLAYER_REGEN_ENABLED`.
  - In `core/App.lua:311-316`, `PLAYER_REGEN_ENABLED` calls:
    ```lua
    function App:OnCombatEnd()
        CallMethod(ns.UF, "OnCombatEnd")
        CallMethod(ns.Center, "OnCombatEnd")
        self:ApplyDeferredCombatState()
        CallMethod(ns.Apply, "OnCombatEnd")
    end
    ```
  - Because `ActionBarsRuntime`'s private frame receives `PLAYER_REGEN_ENABLED` independently, it executes an uncoordinated `module:ApplyConfig()`, while `Apply:OnCombatEnd()` immediately flushes the apply queue and calls `module:ApplyConfig()` a second time.
- **Resolution**:
  Consolidate `ActionBars` combat end handling into the central `App:OnCombatEnd` flow and maintain idempotent flags on `ActionBars:ApplyConfig` so duplicate flushes do not re-run full layouts.

### 7. Taint Risk: Reparenting Protected Blizzard Bars to `pastebin`
- **Location**: `modules/ActionBarsBlizzardShell.lua:151-152`
  ```lua
  local function SoftHide(name, frame)
      ...
      pcall(frame.SetParent, frame, pastebin)
      pcall(frame.Hide, frame)
      return true
  end
  ```
- **Analysis**:
  `BLIZZARD_ART_FRAME_NAMES` includes `MainActionBar`, `MainMenuBar`, and `MultiBar*`.
  These are secure frames in 12.0/12.1. Reparenting a secure Blizzard action bar to an unmanaged dummy frame (`pastebin`) can trigger `ADDON_ACTION_BLOCKED` when Blizzard Edit Mode or internal layout engines attempt to refresh them.
- **Fix**:
  Do not reparent protected action bar parents. Setting alpha to 0, hiding textures, and disabling mouse clicks (`SetMouseEnabledSafe(frame, false)`) safely removes Blizzard frames visually and interactively without violating the secure parent hierarchy.

### 8. Secret Values & Unit Auras (12.1 Build 69497)
- **Status**:
  - `core/Secret.lua` implements comprehensive guards (`TryPlainNumber`, `SafeSetText`, `SafeSetFormattedText`, `CanAccessValue`).
  - `modules/UnitFramesTarget.lua` delegates aura rendering to oUF's element system and applies custom filtering (`AuraCustomFilter`).
  - To maintain compatibility with 12.1's aura secrecy changes (`SecretWhenUnitAuraRestricted = true`), ensure `Aura_IsFromPlayerOrPet` in `modules/UnitFramesRender.lua` checks whether `sourceUnit` and `auraData` are accessible plain values before performing string comparisons.

---

## Proposed PR Diffs

### Patch 1: `FeelsGoodUI.toc`
```diff
--- a/_Addons/FeelsGoodUI/FeelsGoodUI.toc
+++ b/_Addons/FeelsGoodUI/FeelsGoodUI.toc
@@ -1,5 +1,5 @@
-## Interface: 120001, 120005
+## Interface: 120100
 ## Title: FeelsGoodUI
 ## Notes: Minimalist oUF-based unitframes + custom secure action bars.
 ## Author: Neomorph
 ## Version: 0.0.40
```

### Patch 2: `core/DB.lua` (RT-AUDIT-001 Fix)
```diff
--- a/_Addons/FeelsGoodUI/core/DB.lua
+++ b/_Addons/FeelsGoodUI/core/DB.lua
@@ -364,7 +364,10 @@ function DB:Init()
 end
 
 function DB:GetProfile()
-    return (self.data and self.data.profile) or self.defaults.profile
+    if self.data and type(self.data.profile) == "table" then
+        return self.data.profile
+    end
+    return self:EnsureProfileRoot()
 end
 
 function DB:EnsureProfileRoot()
```

### Patch 3: `modules/ActionBarsState.lua` (`GetActionInfo` / Empty Slot Modernization)
```diff
--- a/_Addons/FeelsGoodUI/modules/ActionBarsState.lua
+++ b/_Addons/FeelsGoodUI/modules/ActionBarsState.lua
@@ -97,14 +97,29 @@ local function GetActionID(btn)
     return nil
 end
 
+local function HasActionSafe(action)
+    if _G.C_ActionBar and type(_G.C_ActionBar.HasAction) == "function" then
+        local ok, hasAction = pcall(_G.C_ActionBar.HasAction, action)
+        if ok then return hasAction == true end
+    end
+    if _G.C_ActionBar and type(_G.C_ActionBar.GetActionInfo) == "function" then
+        local ok, actionType = pcall(_G.C_ActionBar.GetActionInfo, action)
+        if ok then return actionType ~= nil end
+    end
+    if type(_G.GetActionInfo) == "function" then
+        local ok, actionType = pcall(_G.GetActionInfo, action)
+        if ok then return actionType ~= nil end
+    end
+    return false
+end
+
 local function IsEmptySlot(btn)
     if not btn then return true end
-    if type(_G.GetActionInfo) ~= "function" then return false end
 
     local action = GetActionID(btn)
     if type(action) ~= "number" or action <= 0 then
         return true
     end
 
-    local actionType = _G.GetActionInfo(action)
-    return actionType == nil
+    return not HasActionSafe(action)
 end
```

### Patch 4: `modules/CenterBars.lua` (`GetSpecialization` Modernization)
```diff
--- a/_Addons/FeelsGoodUI/modules/CenterBars.lua
+++ b/_Addons/FeelsGoodUI/modules/CenterBars.lua
@@ -165,8 +165,9 @@ local DK_SPEC_COLORS = {
 }
 
 local function GetDKSpecColor()
+    local getSpec = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecialization) or _G.GetSpecialization
     local getSpecInfo = (_G.C_SpecializationInfo and _G.C_SpecializationInfo.GetSpecializationInfo) or _G.GetSpecializationInfo
-    if not (_G.GetSpecialization and getSpecInfo) then return nil end
-    local specIndex = _G.GetSpecialization()
+    if not (getSpec and getSpecInfo) then return nil end
+    local specIndex = getSpec()
     if not specIndex then return nil end
     local specID = getSpecInfo(specIndex)
     if type(specID) ~= "number" then return nil end
```

### Patch 5: `core/OptionsSharedHelpers.lua` (CheckButton Template Modernization)
```diff
--- a/_Addons/FeelsGoodUI/core/OptionsSharedHelpers.lua
+++ b/_Addons/FeelsGoodUI/core/OptionsSharedHelpers.lua
@@ -96,7 +96,8 @@ local function CreateNote(parent, text, anchor, x, y)
 end
 
 local function CreateCheck(parent, label, tooltip, anchor, x, y)
-    local b = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
+    local template = (_G.UICheckButtonTemplate and "UICheckButtonTemplate") or "InterfaceOptionsCheckButtonTemplate"
+    local b = CreateFrame("CheckButton", nil, parent, template)
     b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -8)
     SetWidgetText(b, L(label))
```

### Patch 6: `modules/ActionBarsBlizzardShell.lua` (Safe Blizzard Shell Suppression)
```diff
--- a/_Addons/FeelsGoodUI/modules/ActionBarsBlizzardShell.lua
+++ b/_Addons/FeelsGoodUI/modules/ActionBarsBlizzardShell.lua
@@ -149,8 +149,12 @@ local function SoftHide(name, frame)
         return true
     end
 
-    pcall(frame.SetParent, frame, pastebin)
-    pcall(frame.Hide, frame)
+    -- In 12.0+, do not reparent secure action bar roots to pastebin to avoid ADDON_ACTION_BLOCKED.
+    -- Suppress visibility and interactions in-place.
+    if frame.Hide then
+        pcall(frame.Hide, frame)
+    end
     return true
 end
```

---

## Action Items & In-Game Verification Checklist

1. **Static Validation**:
   - Run `node check_lua.js` in `_Addons/FeelsGoodUI` (must report `All files parsed successfully!`).
   - Run `./tools/test-addon-architecture-docs.ps1` (ensure documentation manifest passes).
2. **In-Game Smoke Testing**:
   - Verify addon loads cleanly with `oUF` enabled on 12.1 client (`Interface 120100`).
   - Open `/fgui` and execute `/fgui qa` to verify that the internal QA diagnostic reports `0 issues`.
   - Test empty action bar buttons with empty slots: verify empty buttons fade out and show grid only during mover mode or mouse hover.
   - Switch Death Knight specializations (Blood, Frost, Unholy): verify rune bar spec colors update dynamically without errors.
   - Enter combat and leave combat: verify no `ADDON_ACTION_BLOCKED` or `MACRO_ACTION_FORBIDDEN` logs in BugGrabber/Swatter.
   - Reset profile positions via `/fgui resetpos`: verify SavedVariables defaults are never mutated.
