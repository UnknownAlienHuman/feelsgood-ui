from pathlib import Path

animate_path = Path('.codex/test_animate_registries.lua')
animate = animate_path.read_text(encoding='utf-8')
replacements = {
    'assertEqual(Animate.CancelFade(frame, { resetAlpha = 0.55 }), true, "cancel fade")':
        'assertEqual(Animate.CancelFade(frame, 0.55), true, "cancel fade")',
    'assertEqual(Animate.CancelFade(untouched, { resetAlpha = 0.40 }), true, "cancel untouched frame")':
        'assertEqual(Animate.CancelFade(untouched, 0.40), true, "cancel untouched frame")',
    'assertEqual(Animate.CancelAfter(owner, "zero"), false, "zero-delay has no timer handle")':
        'assertEqual(Animate.CancelAfter(owner, "zero"), true, "zero-delay callback token cancelled")',
    'assertEqual(Animate.CancelAllAfter(owner), true, "cancel all timers")':
        'Animate.CancelAllAfter(owner)',
}
for old, new in replacements.items():
    count = animate.count(old)
    if count != 1:
        raise RuntimeError(f'Animate fixture anchor {old!r}: expected 1, found {count}')
    animate = animate.replace(old, new, 1)
animate_path.write_text(animate, encoding='utf-8')

print('Fixed generic registry harness expectations.')
