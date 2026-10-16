"""A fake agent that mimics `claude -p` / `codex exec` for testing the harness without real agents.

Behaviour comes from a JSON plan (env STUB_PLAN): {"builder": [step, ...], "reviewer": [step, ...]}.
Each call consumes the next step (the last one repeats). Builder step keys: write (relpath -> text), sleep (s),
print (text), exit (code). Reviewer step keys: output (text). Every call is appended to <plan>.calls.jsonl.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", required=True)
    parser.add_argument("--model", default="")
    parser.add_argument("--output-file", default="")
    args = parser.parse_args()
    prompt = sys.stdin.read()
    plan_path = Path(os.environ["STUB_PLAN"])
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    counter = Path(str(plan_path) + f".{args.role}.count")
    count = int(counter.read_text()) if counter.exists() else 0
    counter.write_text(str(count + 1))
    steps = plan.get(args.role, [{}])
    step = steps[min(count, len(steps) - 1)]
    with open(str(plan_path) + ".calls.jsonl", "a", encoding="utf-8") as log:
        log.write(json.dumps({"role": args.role, "model": args.model, "call": count + 1, "prompt_chars": len(prompt),
                              "prompt_head": prompt[:200], "prompt": prompt}) + "\n")
    if step.get("sleep"):
        time.sleep(float(step["sleep"]))
    for relpath in step.get("delete", []):
        Path(relpath).unlink(missing_ok=True)
    for relpath, text in (step.get("write") or {}).items():
        target = Path(relpath)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    text = step.get("output") if args.role == "reviewer" else step.get("print", "done")
    text = text if text is not None else ""
    if args.output_file:
        Path(args.output_file).write_text(text, encoding="utf-8")
    print(text)
    return int(step.get("exit", 0))


if __name__ == "__main__":
    sys.exit(main())
