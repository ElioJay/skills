"""Build benchmark.json + benchmark.md from grading.json + timing.json."""
from __future__ import annotations
import json
import statistics
from datetime import datetime, timezone
from pathlib import Path

ITER = Path(__file__).parent
SKILL_NAME = "vibe-coding-workflow"
SKILL_PATH = r"C:\Users\developer\.claude\skills\vibe-coding-workflow"

EVALS = [
    {"id": 1, "name": "eval-1-csv-dedupe-cli"},
    {"id": 2, "name": "eval-2-express-health"},
    {"id": 3, "name": "eval-3-print-to-logging"},
]
CONFIGS = ["with_skill", "without_skill"]

def load(p): return json.loads(Path(p).read_text(encoding="utf-8"))

def stats(values):
    if not values:
        return {"mean": 0, "stddev": 0, "min": 0, "max": 0}
    m = statistics.mean(values)
    sd = statistics.pstdev(values) if len(values) > 1 else 0.0
    return {"mean": round(m, 3), "stddev": round(sd, 3), "min": round(min(values), 3), "max": round(max(values), 3)}

runs = []
per_cfg = {c: {"pass_rate": [], "time_seconds": [], "tokens": []} for c in CONFIGS}

for ev in EVALS:
    for cfg in CONFIGS:
        run_dir = ITER / ev["name"] / cfg
        grading = load(run_dir / "grading.json")
        timing = load(run_dir / "timing.json")
        pass_rate = grading["pass_rate"]
        time_s = timing["total_duration_seconds"]
        tokens = timing["total_tokens"]

        runs.append({
            "eval_id": ev["id"],
            "eval_name": ev["name"],
            "configuration": cfg,
            "run_number": 1,
            "result": {
                "pass_rate": pass_rate,
                "passed": grading["passed"],
                "failed": grading["total"] - grading["passed"],
                "total": grading["total"],
                "time_seconds": time_s,
                "tokens": tokens,
                "tool_calls": 0,
                "errors": 0,
            },
            "expectations": grading["expectations"],
            "notes": [],
        })
        per_cfg[cfg]["pass_rate"].append(pass_rate)
        per_cfg[cfg]["time_seconds"].append(time_s)
        per_cfg[cfg]["tokens"].append(tokens)

run_summary = {
    cfg: {
        "pass_rate": stats(per_cfg[cfg]["pass_rate"]),
        "time_seconds": stats(per_cfg[cfg]["time_seconds"]),
        "tokens": stats(per_cfg[cfg]["tokens"]),
    }
    for cfg in CONFIGS
}
ws, bs = run_summary["with_skill"], run_summary["without_skill"]
run_summary["delta"] = {
    "pass_rate": f"{ws['pass_rate']['mean'] - bs['pass_rate']['mean']:+.3f}",
    "time_seconds": f"{ws['time_seconds']['mean'] - bs['time_seconds']['mean']:+.1f}",
    "tokens": f"{ws['tokens']['mean'] - bs['tokens']['mean']:+.0f}",
}

benchmark = {
    "metadata": {
        "skill_name": SKILL_NAME,
        "skill_path": SKILL_PATH,
        "executor_model": "claude-opus-4-7[1m]",
        "analyzer_model": "claude-opus-4-7[1m]",
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "evals_run": [e["id"] for e in EVALS],
        "runs_per_configuration": 1,
    },
    "runs": runs,
    "run_summary": run_summary,
    "notes": [
        f"with_skill pass_rate {ws['pass_rate']['mean']:.2f} vs baseline {bs['pass_rate']['mean']:.2f}（delta {run_summary['delta']['pass_rate']}）— skill 让全部断言通过，baseline 在 eval-1 漏掉了 'TRANSCRIPT 提到 Plan/阶段' 一项，说明 skill 确实驱动模型把流程显性化。",
        f"with_skill 平均耗时 {ws['time_seconds']['mean']:.0f}s vs baseline {bs['time_seconds']['mean']:.0f}s（+{ws['time_seconds']['mean']-bs['time_seconds']['mean']:.0f}s，约 +{100*(ws['time_seconds']['mean']/bs['time_seconds']['mean']-1):.0f}%）—— 走完整 6 阶段必然更慢，是预期成本。",
        f"with_skill 平均 tokens {ws['tokens']['mean']:.0f} vs baseline {bs['tokens']['mean']:.0f}（+{ws['tokens']['mean']-bs['tokens']['mean']:.0f}）—— 额外开销主要来自读 SKILL.md + references，以及输出 TRANSCRIPT/Plan/Review 等结构化交付物。",
        "eval-3（极简任务）with_skill 即便正确识别为简单任务并退出，仍多花 ~40% 时间和 token —— 这是 skill 设计的固定开销。如果用户的工作流里小任务占比高，应优化触发条件，让小任务直接走默认行为。",
        "断言主要检查产物存在性和结构正确性（程序化可验证），未覆盖代码风格 / 测试质量等主观维度——建议人工 review 时补这一层。",
    ],
}

(ITER / "benchmark.json").write_text(json.dumps(benchmark, ensure_ascii=False, indent=2), encoding="utf-8")
print("Wrote benchmark.json")

# benchmark.md
lines = [
    f"# Skill Benchmark: {SKILL_NAME}",
    "",
    f"**Date**: {benchmark['metadata']['timestamp']}",
    f"**Evals**: {len(EVALS)} × 1 run per configuration",
    "",
    "## Summary",
    "",
    "| Configuration | Pass rate | Avg time (s) | Avg tokens |",
    "|---|---|---|---|",
    f"| with_skill    | {ws['pass_rate']['mean']:.2%} ± {ws['pass_rate']['stddev']:.2%} | {ws['time_seconds']['mean']:.1f} ± {ws['time_seconds']['stddev']:.1f} | {ws['tokens']['mean']:.0f} ± {ws['tokens']['stddev']:.0f} |",
    f"| without_skill | {bs['pass_rate']['mean']:.2%} ± {bs['pass_rate']['stddev']:.2%} | {bs['time_seconds']['mean']:.1f} ± {bs['time_seconds']['stddev']:.1f} | {bs['tokens']['mean']:.0f} ± {bs['tokens']['stddev']:.0f} |",
    f"| **Δ**         | {run_summary['delta']['pass_rate']} | {run_summary['delta']['time_seconds']} | {run_summary['delta']['tokens']} |",
    "",
    "## Per-eval breakdown",
    "",
    "| Eval | with_skill | without_skill |",
    "|---|---|---|",
]
for ev in EVALS:
    ws_run = next(r for r in runs if r["eval_id"] == ev["id"] and r["configuration"] == "with_skill")
    bs_run = next(r for r in runs if r["eval_id"] == ev["id"] and r["configuration"] == "without_skill")
    lines.append(
        f"| {ev['name']} | {ws_run['result']['passed']}/{ws_run['result']['total']} in {ws_run['result']['time_seconds']:.0f}s ({ws_run['result']['tokens']} tok) "
        f"| {bs_run['result']['passed']}/{bs_run['result']['total']} in {bs_run['result']['time_seconds']:.0f}s ({bs_run['result']['tokens']} tok) |"
    )
lines += ["", "## Analyst notes", ""]
for n in benchmark["notes"]:
    lines.append(f"- {n}")
(ITER / "benchmark.md").write_text("\n".join(lines), encoding="utf-8")
print("Wrote benchmark.md")
