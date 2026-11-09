from pathlib import Path

path = Path('.codex/test_actionbars_global_state_hooks.lua')
text = path.read_text(encoding='utf-8')
old = '''local moduleA = { _detached = false, refreshCalls = 0, autoCalls = 0 }
function moduleA:RefreshEmptySlots() self.refreshCalls = self.refreshCalls + 1 end
function moduleA:UpdateAutoHideState() self.autoCalls = self.autoCalls + 1 end
local moduleB = { _detached = false, refreshCalls = 0, autoCalls = 0 }
function moduleB:RefreshEmptySlots() self.refreshCalls = self.refreshCalls + 1 end
function moduleB:UpdateAutoHideState() self.autoCalls = self.autoCalls + 1 end
'''
new = '''local moduleA = { _detached = false, refreshCalls = 0, autoCalls = 0 }
local moduleB = { _detached = false, refreshCalls = 0, autoCalls = 0 }
State.RefreshEmptySlots = function(module)
    module.refreshCalls = module.refreshCalls + 1
end
State.UpdateAutoHideState = function(module)
    module.autoCalls = module.autoCalls + 1
end
'''
if text.count(old) != 1:
    raise RuntimeError(f'state dispatch fixture anchor: expected one, found {text.count(old)}')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('Aligned state-hook fixture with State-owned dispatch.')
