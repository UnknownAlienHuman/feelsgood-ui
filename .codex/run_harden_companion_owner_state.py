from pathlib import Path
import runpy

source_path = Path('.codex/harden_companion_owner_state.py')
source = source_path.read_text(encoding='utf-8')
start = source.index("queued_anchor = '''")
end = source.index(
    "micro = replace_once(\n    micro,\n    '''    module._applyingMicroLayout = nil",
    start,
)
replacement = '''queued_anchors = (
    (
        """                module._applyingMicroLayout = nil
                QueueMicroLayoutRetry(module)
                return
""",
        1,
    ),
    (
        """                    module._applyingMicroLayout = nil
                    QueueMicroLayoutRetry(module)
                    return
""",
        2,
    ),
)
for queued_anchor, expected_count in queued_anchors:
    count = micro.count(queued_anchor)
    if count != expected_count:
        raise RuntimeError(
            f'micro retry anchor count: expected {expected_count}, found {count}'
        )
    micro = micro.replace(
        queued_anchor,
        queued_anchor.replace(
            "return\\n",
            'return true, "Companion micro layout retry queued"\\n',
        ),
    )
'''
source = source[:start] + replacement + source[end:]

temp = Path('.codex/.harden_companion_owner_state.runtime.py')
temp.write_text(source, encoding='utf-8')
runpy.run_path(str(temp), run_name='__main__')
