"""Programmatic grader for vibe-coding-workflow iteration-1.

Reads outputs/ for each (eval, configuration), evaluates assertions,
writes grading.json into each run directory.
"""
from __future__ import annotations
import json
import re
from pathlib import Path
from typing import Callable

ITER = Path(__file__).parent

# ------ helpers ------

def read(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""

def has_cjk(s: str) -> bool:
    return bool(re.search(r"[一-鿿]", s))

def list_files(d: Path) -> list[str]:
    if not d.exists():
        return []
    return [str(p.relative_to(d)).replace("\\", "/") for p in d.rglob("*") if p.is_file()]

# ------ assertions ------

def eval1_assertions(outputs: Path) -> list[dict]:
    files = list_files(outputs)
    files_lower = [f.lower() for f in files]
    dedupe = outputs / "dedupe.py"
    readme_present = any(f.lower() == "readme.md" for f in files)
    test_files = [f for f in files_lower if ("test_" in f or "_test.py" in f) and f.endswith(".py")]
    transcript = read(outputs / "TRANSCRIPT.md")
    commit_plan = read(outputs / "COMMIT_PLAN.md")
    test_text = "\n".join(read(outputs / f) for f in test_files)

    # Extract commit message lines from COMMIT_PLAN.md
    # Look for lines that look like conventional commits or are inside backticks
    commit_msgs = re.findall(r"`([^`\n]+)`", commit_plan) + \
                  re.findall(r"^\s*(?:feat|fix|chore|refactor|test|docs|build|ci|perf|style)(?:\([^)]+\))?:.*$",
                             commit_plan, flags=re.MULTILINE | re.IGNORECASE)
    commit_msg_text = "\n".join(commit_msgs) if commit_msgs else commit_plan

    edge_keywords = ["empty", "空", "missing", "not found", "不存在", "未知列", "unknown column",
                     "no such", "invalid", "缺失", "ValueError"]
    edge_hits = sum(1 for k in edge_keywords if k.lower() in test_text.lower())

    return [
        {"text": "dedupe.py 文件存在且非空", "passed": dedupe.exists() and dedupe.stat().st_size > 0,
         "evidence": f"size={dedupe.stat().st_size if dedupe.exists() else 0}"},
        {"text": "测试文件存在（test_*.py 或 *_test.py）", "passed": len(test_files) > 0,
         "evidence": f"matches={test_files}"},
        {"text": "README.md 存在", "passed": readme_present,
         "evidence": f"files={[f for f in files if f.lower().endswith('readme.md')]}"},
        {"text": "TRANSCRIPT.md 提到 Plan/方案/阶段（说明走了流程）", "passed": any(k in transcript for k in ["Plan", "方案", "阶段", "stage"]),
         "evidence": transcript[:120]},
        {"text": "COMMIT_PLAN.md 存在", "passed": (outputs / "COMMIT_PLAN.md").exists(),
         "evidence": f"size={len(commit_plan)}"},
        {"text": "Commit message 是英文（不含中文）", "passed": bool(commit_msg_text) and not has_cjk(commit_msg_text),
         "evidence": commit_msg_text[:200]},
        {"text": "测试覆盖至少 2 个边界场景关键词", "passed": edge_hits >= 2,
         "evidence": f"edge_keyword_hits={edge_hits}"},
    ]

def eval2_assertions(outputs: Path) -> list[dict]:
    files = list_files(outputs)
    pkg_path = outputs / "package.json"
    pkg = read(pkg_path)
    try:
        pkg_json = json.loads(pkg) if pkg else {}
    except Exception:
        pkg_json = {}
    deps = {**(pkg_json.get("dependencies") or {}), **(pkg_json.get("devDependencies") or {})}

    # find entry & test files
    js_files = [outputs / f for f in files if f.endswith(".js")]
    js_text = "\n".join(read(p) for p in js_files)
    test_files = [outputs / f for f in files if (".test.js" in f.lower() or "/tests/" in f.lower() or "/__tests__/" in f.lower()) and f.endswith(".js")]
    test_text = "\n".join(read(p) for p in test_files)

    readme = read(outputs / "README.md")
    commit_plan = read(outputs / "COMMIT_PLAN.md")
    commit_msgs = re.findall(r"`([^`\n]+)`", commit_plan) + \
                  re.findall(r"^\s*(?:feat|fix|chore|refactor|test|docs|build|ci|perf|style)(?:\([^)]+\))?:.*$",
                             commit_plan, flags=re.MULTILINE | re.IGNORECASE)
    commit_msg_text = "\n".join(commit_msgs) if commit_msgs else commit_plan

    return [
        {"text": "package.json 存在且合法 JSON", "passed": bool(pkg_json),
         "evidence": f"keys={list(pkg_json.keys())[:6]}"},
        {"text": "package.json 含 express ^4.x", "passed": "express" in deps and (deps["express"].startswith("^4") or deps["express"].startswith("4")),
         "evidence": f"express={deps.get('express')}"},
        {"text": "package.json 含 jest 依赖", "passed": "jest" in deps,
         "evidence": f"jest={deps.get('jest')}"},
        {"text": "入口含 /health 路由", "passed": "/health" in js_text,
         "evidence": f"js_files={[str(p.relative_to(outputs)) for p in js_files]}"},
        {"text": "测试文件存在", "passed": len(test_files) > 0,
         "evidence": f"test_files={[str(p.relative_to(outputs)) for p in test_files]}"},
        {"text": "测试覆盖三个字段 status/uptime/timestamp", "passed": all(k in test_text for k in ["status", "uptime", "timestamp"]),
         "evidence": f"hits={[k for k in ['status','uptime','timestamp'] if k in test_text]}"},
        {"text": "README 含启动命令（npm 或 node）", "passed": ("npm" in readme) or ("node " in readme),
         "evidence": f"readme_len={len(readme)}"},
        {"text": "COMMIT_PLAN.md 含英文 commit message", "passed": (outputs / "COMMIT_PLAN.md").exists() and bool(commit_msg_text) and not has_cjk(commit_msg_text),
         "evidence": commit_msg_text[:200]},
    ]

def eval3_assertions(outputs: Path, is_with_skill: bool) -> list[dict]:
    hello = read(outputs / "hello.py")
    transcript = read(outputs / "TRANSCRIPT.md")
    files = list_files(outputs)
    # over-engineering: presence of test files, Plan-like docs
    extra_test = [f for f in files if "test" in f.lower() and f.endswith(".py")]
    extra_plan = [f for f in files if "plan" in f.lower() and f.lower() != "commit_plan.md"]
    extras = extra_test + extra_plan

    base = [
        {"text": "hello.py 含 import logging", "passed": bool(re.search(r"^\s*import\s+logging", hello, re.MULTILINE)),
         "evidence": hello[:160]},
        {"text": "hello.py 不再含 print( 调用", "passed": "print(" not in hello,
         "evidence": "found print(" if "print(" in hello else "ok"},
        {"text": "hello.py 调用 logger 的 .info(", "passed": ".info(" in hello,
         "evidence": "ok" if ".info(" in hello else hello[:160]},
        {"text": "TRANSCRIPT.md 存在", "passed": (outputs / "TRANSCRIPT.md").exists(),
         "evidence": f"len={len(transcript)}"},
    ]
    if is_with_skill:
        base.append({
            "text": "TRANSCRIPT.md 明确说明识别为简单任务并退出完整流程（with_skill 应有的判断）",
            "passed": any(k in transcript for k in ["简单任务", "退出", "不走完整", "exit", "skip", "10 行", "不用走", "边界与例外"]),
            "evidence": transcript[:300],
        })
        base.append({
            "text": "没有过度产出（无独立测试、无 Plan 文档）",
            "passed": len(extras) == 0,
            "evidence": f"extras={extras}",
        })
    return base

# ------ driver ------

EVALS = [
    {
        "name": "eval-1-csv-dedupe-cli",
        "fn": lambda out, is_ws: eval1_assertions(out),
    },
    {
        "name": "eval-2-express-health",
        "fn": lambda out, is_ws: eval2_assertions(out),
    },
    {
        "name": "eval-3-print-to-logging",
        "fn": lambda out, is_ws: eval3_assertions(out, is_ws),
    },
]

def main():
    for ev in EVALS:
        for cfg in ["with_skill", "without_skill"]:
            outputs = ITER / ev["name"] / cfg / "outputs"
            is_ws = cfg == "with_skill"
            assertions = ev["fn"](outputs, is_ws)
            passed = sum(1 for a in assertions if a["passed"])
            total = len(assertions)
            grading = {
                "eval_name": ev["name"],
                "configuration": cfg,
                "expectations": assertions,
                "passed": passed,
                "total": total,
                "pass_rate": passed / total if total else 0,
            }
            out_path = ITER / ev["name"] / cfg / "grading.json"
            out_path.write_text(json.dumps(grading, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"{ev['name']} / {cfg}: {passed}/{total} ({100*passed/total:.0f}%)")

if __name__ == "__main__":
    main()
