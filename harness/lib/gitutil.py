"""Small git helpers. Worktrees live outside the repo; the harness never merges and never deletes branches."""
from __future__ import annotations

import re
import subprocess
from pathlib import Path


class GitError(Exception):
    pass


def git(args: list[str], cwd: Path, check: bool = True) -> str:
    result = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and result.returncode != 0:
        raise GitError(f"git {' '.join(args)} failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def slugify(text: str, limit: int = 40) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return (slug[:limit].strip("-")) or "task"


def resolve_sha(repo: Path, ref: str) -> str:
    return git(["rev-parse", ref], repo).strip()


def branch_exists(repo: Path, branch: str) -> bool:
    return git(["rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"], repo, check=False).strip() != ""


def unique_branch(repo: Path, label: str, slug: str) -> str:
    base = f"agent/{label}/{slug}"
    name, n = base, 2
    while branch_exists(repo, name):
        name = f"{base}-{n}"
        n += 1
    return name


def create_worktree(repo: Path, worktrees_dir: Path, branch: str, base_ref: str) -> Path:
    worktrees_dir.mkdir(parents=True, exist_ok=True)
    path = worktrees_dir / branch.split("/", 1)[1].replace("/", "-")
    n = 2
    original = path
    while path.exists():
        path = Path(f"{original}-{n}")
        n += 1
    git(["worktree", "add", "-b", branch, str(path), base_ref], repo)
    return path


def stage_all(worktree: Path) -> None:
    git(["add", "-A"], worktree)


def changed_files(worktree: Path, base_sha: str) -> list[str]:
    """Files changed since base_sha: committed, staged and untracked (everything is staged first)."""
    stage_all(worktree)
    out = git(["diff", "--cached", "--name-only", base_sha], worktree)
    return [line for line in out.splitlines() if line.strip()]


def diff_text(worktree: Path, base_sha: str, limit: int) -> str:
    stage_all(worktree)
    text = git(["diff", "--cached", "--no-color", base_sha], worktree)
    if len(text) > limit:
        text = text[:limit] + f"\n[... diff truncated at {limit} characters ...]\n"
    return text


def commit_all(worktree: Path, message: str) -> str:
    stage_all(worktree)
    git(["commit", "-q", "-m", message], worktree)
    return git(["rev-parse", "HEAD"], worktree).strip()


def list_worktrees(repo: Path) -> list[dict[str, str]]:
    out = git(["worktree", "list", "--porcelain"], repo)
    items: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in out.splitlines():
        if not line.strip():
            if current:
                items.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        current[key] = value
    if current:
        items.append(current)
    return items


def worktree_is_clean(path: Path) -> bool:
    return git(["status", "--porcelain"], path, check=False).strip() == ""
