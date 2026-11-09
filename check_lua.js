'use strict';

const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const ROOT = process.cwd();
const TOC_PATH = path.join(ROOT, 'FeelsGoodUI.toc');
const SKIP_DIRS = new Set(['.git', 'node_modules', 'libs']);
const errors = [];

function relative(file) {
    return path.relative(ROOT, file).split(path.sep).join('/');
}

function walk(dir, output) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (entry.isDirectory() && SKIP_DIRS.has(entry.name)) continue;

        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            walk(fullPath, output);
        } else if (entry.isFile() && entry.name.endsWith('.lua')) {
            output.push(fullPath);
        }
    }
}

function parseLua(file) {
    const code = fs.readFileSync(file, 'utf8');
    try {
        luaparse.parse(code, {
            comments: false,
            locations: true,
            luaVersion: '5.1',
            scope: true,
        });
    } catch (error) {
        const location = error.line ? `:${error.line}:${error.column || 0}` : '';
        errors.push(`${relative(file)}${location}: ${error.message}`);
    }
}

function readToc() {
    if (!fs.existsSync(TOC_PATH)) {
        errors.push('FeelsGoodUI.toc: missing');
        return [];
    }

    const seen = new Map();
    const entries = [];
    const lines = fs.readFileSync(TOC_PATH, 'utf8').split(/\r?\n/);

    lines.forEach((raw, index) => {
        const value = raw.trim();
        if (!value || value.startsWith('#')) return;

        const normalized = value.replace(/\\/g, '/');
        if (!/\.(lua|xml)$/i.test(normalized)) return;

        const previous = seen.get(normalized);
        if (previous) {
            errors.push(`FeelsGoodUI.toc:${index + 1}: duplicate '${normalized}' (first at line ${previous})`);
            return;
        }

        seen.set(normalized, index + 1);
        entries.push(normalized);

        if (!fs.existsSync(path.join(ROOT, normalized))) {
            errors.push(`FeelsGoodUI.toc:${index + 1}: missing '${normalized}'`);
        }
    });

    return entries;
}

function assertBefore(entries, first, second) {
    const firstIndex = entries.indexOf(first);
    const secondIndex = entries.indexOf(second);
    if (firstIndex < 0 || secondIndex < 0 || firstIndex >= secondIndex) {
        errors.push(`FeelsGoodUI.toc: expected '${first}' before '${second}'`);
    }
}


function readSource(name) {
    const file = path.join(ROOT, name);
    if (!fs.existsSync(file)) {
        errors.push(`${name}: missing`);
        return '';
    }
    return fs.readFileSync(file, 'utf8');
}

function assertSourceIncludes(name, text) {
    if (!readSource(name).includes(text)) {
        errors.push(`${name}: expected source contract '${text}'`);
    }
}

function assertSourceExcludes(name, pattern, label) {
    const source = readSource(name);
    if (pattern.test(source)) {
        errors.push(`${name}: forbidden ${label || pattern}`);
    }
}

try {
    const luaFiles = [];
    walk(ROOT, luaFiles);
    luaFiles.sort();
    luaFiles.forEach(parseLua);

    const tocEntries = readToc();
    const tocSet = new Set(tocEntries);

    for (const file of luaFiles) {
        const name = relative(file);
        const firstParty = name === 'FeelsGoodUI.lua'
            || name.startsWith('core/')
            || name.startsWith('modules/');
        if (firstParty && !tocSet.has(name)) {
            errors.push(`FeelsGoodUI.toc: first-party Lua file is not loaded: '${name}'`);
        }
        if (firstParty) {
            const source = fs.readFileSync(file, 'utf8');
            if (name !== 'core/DB.lua' && /\b(?:DB|db)(?:\.|:)\s*GetSection\b/.test(source)) {
                errors.push(`${name}: use DB:ReadSection for reads or DB:EnsureSection for writes; GetSection is compatibility-only`);
            }
            if (/__fguiBorder(?:Size)?/.test(source)) {
                errors.push(`${name}: border ownership must stay in Media's registry, not on target frames`);
            }
            if (name === 'modules/CompanionMicroBags.lua'
                && /_(?:fguiCompanionHooked|fguiSquareSkinHooked|fguiBagCountText|fguiBagSummary)\b/.test(source)) {
                errors.push(`${name}: Companion runtime metadata must stay on the owner, not Blizzard frames`);
            }
        }
    }

    assertSourceIncludes('core/Animate.lua', 'Animate._frameRegistry');
    assertSourceIncludes('core/Animate.lua', 'Animate._timerRegistry');
    assertSourceExcludes('core/Animate.lua', /_fguiAnimate(?:State|Timers)/, 'generic animation owner metadata');
    assertSourceExcludes('core/Animate.lua', /group\._fgui/, 'animation-group metadata fields');
    assertSourceExcludes('core/Utils.lua', /function U\.GetCooldownTimerText/, 'dead cooldown frame cache helper');
    assertSourceIncludes('core/MinimapIcon.lua', 'local dragHookRegistry = setmetatable');
    assertSourceIncludes('core/MinimapIcon.lua', 'local draggingButton = nil');
    assertSourceExcludes('core/MinimapIcon.lua', /_fguiTransactionalDragHooked/, 'LibDBIcon button metadata');
    assertSourceExcludes('core/MinimapIcon.lua', /local dragging = false/, 'global minimap drag boolean');

    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Target._frameRegistry');
    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Target._auraRoleRegistry');
    assertSourceIncludes('modules/UnitFramesTarget.lua', 'Target._headerHookRegistry');
    assertSourceIncludes('modules/UnitFramesTarget.lua', 'local attached, detail = Target.AttachOwner(owner)');
    assertSourceIncludes('modules/UnitFramesRuntime.lua', 'local reconciled, reconcileDetail = Target.ReconcileOwner(owner)');
    assertSourceExcludes('modules/UnitFramesRuntime.lua', /Target\.ReconcileOwner\(owner\)\s*\n\s*end/, 'ignored UnitFrames reconciliation result');
    assertSourceIncludes('modules/UnitFramesRender.lua', 'Render._lowHPRegistry');
    assertSourceIncludes('modules/UnitFramesRuntime.lua', 'Runtime._unitWatchRegistry');
    assertSourceExcludes('modules/UnitFramesTarget.lua', /_fgui/, 'oUF target observer or aura metadata');
    assertSourceExcludes('modules/UnitFramesRender.lua', /_fguiLowHP/, 'oUF low-health cache metadata');
    assertSourceExcludes('modules/UnitFramesRuntime.lua', /_fguiUnitWatch/, 'oUF unit-watch metadata');
    assertSourceExcludes('modules/UnitFramesTarget.lua', /unitframesCfg\.targetAuras\s*=/, 'runtime target-aura section repair');
    assertSourceExcludes('modules/UnitFramesTarget.lua', /targetAuras\.mode\s*=/, 'runtime target-aura mode write');

    assertSourceIncludes('modules/ActionBarsState.lua', 'State._buttonRegistry');
    assertSourceIncludes('modules/ActionBarsState.lua', 'function State.GetButtonRecord');
    assertSourceIncludes('modules/ActionBarsVisuals.lua', 'Visuals._regionRegistry');
    assertSourceIncludes('modules/ActionBarsVisuals.lua', 'local function GetRegionRecord');
    assertSourceExcludes('modules/ActionBarsState.lua', /btn\.(?:__fgui|_fgui(?:Skinned|Module|AutoHideHooks))/, 'ActionButton runtime metadata');
    assertSourceExcludes('modules/ActionBarsVisuals.lua', /(?:btn|hotkey|count|name|cooldown|timer)\._fgui/, 'ActionButton visual metadata');
    assertSourceExcludes('modules/ActionBarsRuntime.lua', /button\.__fgui/, 'ActionButton callback metadata');

    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:BeginButton');
    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:FinishButton');
    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:SuppressNativeBar');
    assertSourceIncludes('modules/CompanionPetState.lua', 'function State:RestoreAll');
    assertSourceIncludes('modules/CompanionPetState.lua', 'pcall(record.release, record.button)');
    assertSourceIncludes('modules/CompanionPetState.lua', 'ValidateCapturedComponents');
    assertSourceIncludes('modules/CompanionPetState.lua', 'ComponentsMatch');
    assertSourceIncludes('modules/CompanionPetState.lua', 'local structuralOwned = parentKnown');
    assertSourceIncludes('modules/CompanionPetState.lua', 'if currentShown == managed.shown then');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'release = ReleasePetButtonStyle');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:BeginButton');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'local pending = {}');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'Managed pet action button preview capture failed');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:FinishButton');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'PetState:RestoreAll(module)');
    assertSourceExcludes('modules/CompanionPetBar.lua', /RestoreTextureAlpha/, 'default-value pet texture restore');
    assertSourceExcludes('modules/CompanionPetBar.lua', /ResetPetButtonParent/, 'guessed pet-button parent restore');
    assertSourceExcludes('modules/CompanionPetBar.lua', /pcall\(_G\.PetActionBar\.SetAlpha/, 'direct native pet-bar alpha takeover');

    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._microSourceHooks');
    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._bagTextureHooks');
    assertSourceIncludes('modules/CompanionMicroBags.lua', 'module._bagCountTextByButton');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'local petApplied, petDetail');
    assertSourceIncludes('modules/CompanionRuntime.lua', 'local microApplied, microDetail');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'return true, "Pet action buttons pending runtime creation"');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'module._pendingPetButtons = nil');
    assertSourceExcludes('modules/CompanionPetBar.lua', /return false, "Pet action buttons unavailable"/, 'fatal transient pet-button startup');

    assertSourceIncludes('core/Media.lua', 'Media._borderRegistry');
    assertSourceIncludes('core/Media.lua', 'function Media:GetBorder(frame)');
    assertSourceIncludes('core/Media.lua', 'function Media:SetBorderColor(frame, r, g, b, a)');
    assertSourceIncludes('modules/CompanionPetBar.lua', 'Media:SetBorderColor(button, 0, 0, 0, 0)');

    assertSourceIncludes('modules/CenterBarsRender.lua', 'owner._classResourceSuppression');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'EnsureClassResourceShowHook');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'RestoreClassResourceRecord');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'ApplyClassResourceSuppression(record)');
    assertSourceIncludes('modules/CenterBarsRender.lua', 'elseif registry[name] then');
    assertSourceExcludes('modules/CenterBarsRender.lua', /pcall\(frame\.Hide,\s*frame\)/, 'native class-resource Hide takeover');
    assertSourceExcludes('modules/CenterBarsRender.lua', /pcall\(frame\.Show,\s*frame\)/, 'native class-resource Show restore');
    assertSourceExcludes('modules/CenterBarsRender.lua', /pcall\(frame\.Setup,\s*frame\)/, 'foreign class-resource Setup restore');
    assertSourceExcludes('modules/CenterBarsRender.lua', /_fguiSuppress(?:Requested|Hooked)/, 'foreign class-resource ownership markers');

    assertSourceIncludes('modules/ExperienceBar.lua', 'SuppressBlizzardStatusTracking');
    assertSourceIncludes('modules/ExperienceBar.lua', 'module._statusTrackingSnapshot');
    assertSourceIncludes('modules/ExperienceBar.lua', 'MaintainStatusTrackingOwnership');
    assertSourceIncludes('modules/ExperienceBar.lua', 'WriteFrameAlpha');
    assertSourceIncludes('modules/ExperienceBar.lua', 'WriteFrameMouseEnabled');
    assertSourceIncludes('modules/ExperienceBar.lua', 'RestoreStatusTrackingRecord');
    assertSourceIncludes('modules/ExperienceBar.lua', 'record.alphaOwned');
    assertSourceIncludes('modules/ExperienceBar.lua', 'record.mouseOwned');
    assertSourceIncludes('modules/ExperienceBar.lua', 'local maintained, maintainDetail = MaintainStatusTrackingOwnership(self)');
    assertSourceIncludes('modules/ExperienceBar.lua', 'local restored, restoreDetail = RestoreBlizzardStatusTracking(self)');
    assertSourceExcludes('modules/ExperienceBar.lua', /module\._statusTrackingSnapshot\s*=\s*nil\s*\n\s*for frame/, 'preemptive ExperienceBar journal discard');
    assertSourceExcludes('modules/ExperienceBar.lua', /CaptureStatusTrackingFrame\(module, frame\)[\s\S]{0,100}SetFrameAlpha\(frame, 0\)/, 'unverified native alpha takeover');
    assertSourceExcludes('modules/ExperienceBar.lua', /MaintainStatusTrackingOwnership\(self\)\s*\n\s*ev:RegisterEvent/, 'ignored native status ownership result');
    assertSourceExcludes('modules/ExperienceBar.lua', /pcall\(frame\.Hide,\s*frame\)/, 'native status-frame Hide takeover');
    assertSourceExcludes('modules/ExperienceBar.lua', /function\s+XP:Enable\(/, 'parallel ExperienceBar lifecycle enable owner');
    assertSourceExcludes('modules/ExperienceBar.lua', /function\s+XP:Disable\(/, 'parallel ExperienceBar lifecycle disable owner');
    assertSourceExcludes('modules/ExperienceBar.lua', /pcall\(manager\.Show/, 'unconditional Blizzard status manager Show');

    assertSourceIncludes('core/MinimapIcon.lua', 'local runtimeCfg = {}');
    assertSourceIncludes('core/MinimapIcon.lua', 'EnsureDragHooks');
    assertSourceIncludes('core/MinimapIcon.lua', 'CommitDraggedPosition');
    assertSourceIncludes('core/MinimapIcon.lua', 'LDBIcon:Register(addonName, obj, runtimeCfg)');
    assertSourceExcludes('core/MinimapIcon.lua', /LDBIcon:Register\(addonName,\s*obj,\s*cfg\)/, 'live minimap profile registration');
    assertSourceExcludes('core/MinimapIcon.lua', /LDBIcon:Refresh\(addonName,\s*cfg\)/, 'live minimap profile refresh');
    assertSourceExcludes('core/DB.lua', /minimapPos\s*=\s*220[\s\S]{0,120}radius\s*=/, 'dead minimap radius default');
    assertSourceExcludes('core/Settings.lua', /mm\.radius\s*=\s*ValidateNumber/, 'dead minimap radius normalization');

    assertSourceIncludes('core/DB.lua', 'function DB:ReadSection(section)');
    assertSourceIncludes('core/DB.lua', 'return self:ReadSection(section)');
    assertSourceExcludes('core/DB.lua', /function DB:GetSection[\s\S]*?EnsureSection/, 'write-on-read DB compatibility path');

    assertBefore(tocEntries, 'core/Secret.lua', 'core/Utils.lua');
    assertBefore(tocEntries, 'core/Settings.lua', 'core/Apply.lua');
    assertBefore(tocEntries, 'core/Perf.lua', 'core/RuntimeSettings.lua');
    assertBefore(tocEntries, 'core/FeatureRegistry.lua', 'core/RuntimeSettings.lua');
    assertBefore(tocEntries, 'core/RuntimeSettings.lua', 'core/Commands.lua');
    assertBefore(tocEntries, 'core/Apply.lua', 'core/PanelTransactions.lua');
    assertBefore(tocEntries, 'core/RuntimeSettings.lua', 'core/MoversTransactions.lua');
    assertBefore(tocEntries, 'core/MoversTransactions.lua', 'core/MoversShared.lua');
    assertBefore(tocEntries, 'core/OptionsSharedHelpers.lua', 'core/PanelTransactions.lua');
    assertBefore(tocEntries, 'core/PanelTransactions.lua', 'core/ProfileImport.lua');
    assertBefore(tocEntries, 'core/ProfileImport.lua', 'core/OptionsFieldBuilders.lua');
    assertBefore(tocEntries, 'core/ProfileImport.lua', 'core/ProfileTransfer.lua');
    assertBefore(tocEntries, 'modules/UnitFramesTarget.lua', 'modules/UnitFramesRender.lua');
    assertBefore(tocEntries, 'modules/UnitFramesRender.lua', 'modules/UnitFramesPolicy.lua');
    assertBefore(tocEntries, 'modules/CenterBarsRuntime.lua', 'modules/CenterBarsRender.lua');
    assertBefore(tocEntries, 'modules/CenterBarsRender.lua', 'modules/CenterBars.lua');
    assertBefore(tocEntries, 'modules/CompanionPetState.lua', 'modules/CompanionPetBar.lua');

    assertSourceIncludes('core/FeatureRegistry.lua', 'movers = {');
    assertSourceIncludes('core/PanelTransactions.lua', 'function Tx:RollbackAfter(checkpoint, keys)');
    assertSourceIncludes('core/MoversTransactions.lua', 'function Transactions:CommitWrites');
    assertSourceIncludes('core/MoversTransactions.lua', 'CaptureWriteSnapshots');
    assertSourceIncludes('core/MoversTransactions.lua', 'RestorePreview(spec.applyKeys)');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'CaptureNativeActionBarToggles');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'RestoreNativeActionBarToggles');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'NATIVE_TOGGLE_RECOVERY_KEY');
    assertSourceIncludes('modules/ActionBarsBlizzardShell.lua', 'RestorePersistedNativeActionBarToggles');
    assertSourceIncludes('core/App.lua', 'ActionBars.RestorePersistedNativeState');
    assertSourceExcludes('modules/ActionBarsBlizzardShell.lua', /ImportSideBarStateFromBlizzard/, 'implicit Blizzard-to-profile sidebar import');
    assertSourceExcludes('modules/ActionBarsBlizzardShell.lua', /barsCfg\s*\[\s*[45]\s*\]\.enabled\s*=/, 'direct sidebar profile mutation');
    assertSourceExcludes('modules/ActionBarsRuntime.lua', /\bab\.autoHide\s*=(?!=)/, 'runtime action-bar profile normalization');

    assertSourceExcludes('modules/UnitFramesPolicy.lua', /profile\s*\[\s*section\s*\]\s*=/, 'runtime UnitFrames section creation');
    assertSourceExcludes('modules/UnitFramesPolicy.lua', /function\s+Policy\.NormalizeUF/, 'runtime UnitFrames normalizer owner');
    assertSourceExcludes('modules/UnitFramesRuntime.lua', /NormalizeUF/, 'runtime UnitFrames profile normalization call');
    assertSourceExcludes('modules/UnitFramesRender.lua', /NormalizeUF/, 'render-time UnitFrames profile normalization call');
    assertSourceIncludes('modules/UnitFramesPolicy.lua', 'local EMPTY = {}');

    for (const name of [
        'modules/ActionBarsEditMode.lua',
        'modules/CenterBars.lua',
        'modules/UnitFramesPolicy.lua',
        'modules/CompanionPetBar.lua',
        'modules/ExperienceBar.lua',
    ]) {
        assertSourceExcludes(name, /\bsetScale\s*=\s*function/, 'direct mover setScale writer');
        assertSourceExcludes(name, /\bsetSize\s*=\s*function/, 'direct mover setSize writer');
        assertSourceExcludes(name, /\bonWheel\s*=\s*function/, 'direct mover onWheel writer');
    }

    for (const name of [
        'core/Movers.lua',
        'core/MoversShared.lua',
        'core/MoversEditor.lua',
        'core/MoversInspector.lua',
    ]) {
        assertSourceExcludes(name, /positions\s*\[[^\]]+\]\s*=/, 'direct persisted position write');
        assertSourceExcludes(name, /movers\.unlocked\s*=(?!=)/, 'direct persisted lock-state write');
    }

    if (errors.length > 0) {
        for (const error of errors) console.error(error);
        console.error(`Validation failed with ${errors.length} error(s).`);
        process.exitCode = 1;
    } else {
        console.log(`Validation passed: ${luaFiles.length} Lua files, ${tocEntries.length} TOC entries.`);
    }
} catch (error) {
    console.error(error && error.stack ? error.stack : String(error));
    process.exitCode = 1;
}
