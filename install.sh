#!/usr/bin/env bash
# Install this repo as a user-level Claude Code skill by symlinking it into
# ~/.claude/skills (or $CLAUDE_SKILLS_DIR). Safe to re-run.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
name="claude-solution-architect"
target="$skills_dir/$name"

mkdir -p "$skills_dir"

if [ -L "$target" ]; then
  current="$(readlink "$target")"
  if [ "$current" = "$repo_dir" ]; then
    echo "Already installed: $target -> $repo_dir"
    exit 0
  fi
  echo "Updating link (was -> $current)"
  ln -sfn "$repo_dir" "$target"
elif [ -e "$target" ]; then
  echo "Error: $target exists and is not a symlink. Move it aside and re-run." >&2
  exit 1
else
  ln -s "$repo_dir" "$target"
fi

echo "Installed: $target -> $repo_dir"
