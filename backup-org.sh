#!/usr/bin/env bash
set -e

echo "=== GitHub Org Backup ==="

# --- Prerequisites ---
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh (GitHub CLI) is not installed or not in PATH." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed or not in PATH." >&2
    exit 1
fi

# --- Arguments ---
ORG_NAME="$1"
if [ -z "$ORG_NAME" ]; then
    echo "Usage: ./backup-org.sh <organization>" >&2
    exit 1
fi

BACKUP_ROOT="$PWD/$ORG_NAME"
mkdir -p "$BACKUP_ROOT"

# --- List repos ---
echo "Listing repositories from '$ORG_NAME'..."
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Use a file for output so set -e catches gh failures properly
gh repo list "$ORG_NAME" --limit 1000 --json name --jq '.[].name' > "$TEMP_FILE"

if [ ! -s "$TEMP_FILE" ]; then
    echo "No repositories found for organization '$ORG_NAME'." >&2
    echo "Check that the org name is correct and you have access." >&2
    exit 1
fi

TOTAL=$(wc -l < "$TEMP_FILE" | tr -d ' ')
CURRENT=0
echo "Found $TOTAL repositories."

# --- Process each repo ---
while IFS= read -r REPO_NAME; do
    CURRENT=$((CURRENT + 1))
    echo ""
    echo "[$CURRENT/$TOTAL] $REPO_NAME"

    TARGET_DIR="$BACKUP_ROOT/$REPO_NAME"

    if [ ! -d "$TARGET_DIR/.git" ]; then
        echo "  Cloning..."
        if ! gh repo clone "$ORG_NAME/$REPO_NAME" "$TARGET_DIR" -- --quiet; then
            echo "  WARNING: Clone failed, skipping." >&2
            continue
        fi
        echo "  Cloned successfully."
    else
        echo "  Already cloned, updating..."
    fi

    cd "$TARGET_DIR" || continue

    echo "  Fetching all branches..."
    if ! git fetch --all --prune --quiet; then
        echo "  WARNING: Fetch failed, skipping." >&2
        cd "$BACKUP_ROOT" || true
        continue
    fi

    # Create local tracking branches for every remote branch
    git branch -r | grep -v '\->' | sed 's|^[[:space:]]*origin/||' | while IFS= read -r branch; do
        if ! git show-ref --verify --quiet "refs/heads/$branch"; then
            git branch "$branch" "origin/$branch" 2>/dev/null || true
        fi
    done

    cd "$BACKUP_ROOT" || true
done < "$TEMP_FILE"

echo ""
echo "Backup completed. Repos saved to: $BACKUP_ROOT"
