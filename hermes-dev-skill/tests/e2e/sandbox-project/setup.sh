#!/usr/bin/env bash
# Tests/e2e/sandbox-project/setup.sh
# Creates a 50-line throwaway Python project for e2e tests.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if [ -d ".git" ]; then
    echo "sandbox-project already initialized"
    exit 0
fi

git init -b main
git config user.email "sandbox@test"
git config user.name "Sandbox"

cat > add.py <<'PY'
"""add two numbers"""


def add(a: int, b: int) -> int:
    return a + b


if __name__ == "__main__":
    print(add(1, 2))
PY

cat > test_add.py <<'PY'
from add import add


def test_add_basic():
    assert add(1, 2) == 3


def test_add_negative():
    assert add(-1, 1) == 0
PY

cat > README.md <<'MD'
# Sandbox Project
Throwaway 50-line Python project for hermes-dev e2e tests.
MD

git add -A
git commit -m "initial sandbox"
echo "sandbox-project ready"
