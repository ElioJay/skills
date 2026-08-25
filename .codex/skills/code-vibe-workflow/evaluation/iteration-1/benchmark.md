# Skill Benchmark: vibe-coding-workflow

**Date**: 2026-05-19T07:02:21Z
**Evals**: 3 × 1 run per configuration

## Summary

| Configuration | Pass rate | Avg time (s) | Avg tokens |
|---|---|---|---|
| with_skill    | 100.00% ± 0.00% | 126.1 ± 58.5 | 44524 ± 8222 |
| without_skill | 95.20% ± 6.70% | 66.0 ± 21.2 | 30282 ± 2219 |
| **Δ**         | +0.048 | +60.1 | +14242 |

## Per-eval breakdown

| Eval | with_skill | without_skill |
|---|---|---|
| eval-1-csv-dedupe-cli | 7/7 in 196s (52777 tok) | 6/7 in 88s (32342 tok) |
| eval-2-express-health | 8/8 in 130s (47491 tok) | 8/8 in 72s (31301 tok) |
| eval-3-print-to-logging | 6/6 in 52s (33304 tok) | 4/4 in 38s (27202 tok) |

## Analyst notes

- with_skill pass_rate 1.00 vs baseline 0.95（delta +0.048）— skill 让全部断言通过，baseline 在 eval-1 漏掉了 'TRANSCRIPT 提到 Plan/阶段' 一项，说明 skill 确实驱动模型把流程显性化。
- with_skill 平均耗时 126s vs baseline 66s（+60s，约 +91%）—— 走完整 6 阶段必然更慢，是预期成本。
- with_skill 平均 tokens 44524 vs baseline 30282（+14242）—— 额外开销主要来自读 SKILL.md + references，以及输出 TRANSCRIPT/Plan/Review 等结构化交付物。
- eval-3（极简任务）with_skill 即便正确识别为简单任务并退出，仍多花 ~40% 时间和 token —— 这是 skill 设计的固定开销。如果用户的工作流里小任务占比高，应优化触发条件，让小任务直接走默认行为。
- 断言主要检查产物存在性和结构正确性（程序化可验证），未覆盖代码风格 / 测试质量等主观维度——建议人工 review 时补这一层。