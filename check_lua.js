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
    }

    assertBefore(tocEntries, 'core/Secret.lua', 'core/Utils.lua');
    assertBefore(tocEntries, 'core/Settings.lua', 'core/Apply.lua');
    assertBefore(tocEntries, 'core/Perf.lua', 'core/RuntimeSettings.lua');
    assertBefore(tocEntries, 'core/FeatureRegistry.lua', 'core/RuntimeSettings.lua');
    assertBefore(tocEntries, 'core/RuntimeSettings.lua', 'core/Commands.lua');
    assertBefore(tocEntries, 'core/Apply.lua', 'core/PanelTransactions.lua');
    assertBefore(tocEntries, 'core/RuntimeSettings.lua', 'core/MoversTransactions.lua');
    assertBefore(tocEntries, 'core/MoversTransactions.lua', 'core/MoversShared.lua');
    assertBefore(tocEntries, 'core/OptionsSharedHelpers.lua', 'core/PanelTransactions.lua');
    assertBefore(tocEntries, 'core/PanelTransactions.lua', 'core/OptionsFieldBuilders.lua');
    assertBefore(tocEntries, 'modules/UnitFramesTarget.lua', 'modules/UnitFramesRender.lua');
    assertBefore(tocEntries, 'modules/UnitFramesRender.lua', 'modules/UnitFramesPolicy.lua');
    assertBefore(tocEntries, 'modules/CenterBarsRuntime.lua', 'modules/CenterBarsRender.lua');
    assertBefore(tocEntries, 'modules/CenterBarsRender.lua', 'modules/CenterBars.lua');

    assertSourceIncludes('core/FeatureRegistry.lua', 'movers = {');
    assertSourceIncludes('core/PanelTransactions.lua', 'function Tx:RollbackAfter(checkpoint, keys)');
    assertSourceIncludes('core/MoversTransactions.lua', 'function Transactions:CommitWrites');
    assertSourceIncludes('core/MoversTransactions.lua', 'CaptureWriteSnapshots');

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
