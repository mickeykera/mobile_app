# Animation Improvement Plans

Generated at commit `$(git rev-parse --short HEAD)`.

## Execution Order (by leverage)

| # | Plan | Severity | Effort | Depends On | Status |
|---|------|----------|--------|------------|--------|
| 1 | [001-habit-completion-interruptibility.md](001-habit-completion-interruptibility.md) | HIGH | Low | — | **DONE** |
| 2 | [002-focus-breath-interruptibility.md](002-focus-breath-interruptibility.md) | HIGH | Low | — | **DONE** |
| 3 | [003-habits-stagger-performance.md](003-habits-stagger-performance.md) | HIGH | Low | — | **DONE** |
| 4 | [004-focus-breath-physicality.md](004-focus-breath-physicality.md) | HIGH | Medium | 002 | **DONE** |
| 5 | [005-pressable-haptic-spam.md](005-pressable-haptic-spam.md) | HIGH | Low | — | **DONE** |
| 6 | [006-reduced-motion-support.md](006-reduced-motion-support.md) | MEDIUM | Medium | — | **DONE** |
| 7 | [007-easing-duration-consistency.md](007-easing-duration-consistency.md) | MEDIUM | Medium | — | **DONE** |

## How to Execute

Each plan is self-contained. To implement:

```bash
# Read the plan
cat animation-plans/001-habit-completion-interruptibility.md

# Implement the changes in the specified files
# Run verification steps
# Update status to DONE in this README
```

## Notes

- All 7 plans complete
- 363 non-golden tests passing
- Golden tests need regeneration with `flutter test --update-goldens`