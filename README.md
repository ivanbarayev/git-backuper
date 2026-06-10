## Overview

Single-script utility to clone and mirror all repositories in a GitHub organization including all branches from every repo.

## How to run

```bash
# MUST use Git Bash on Windows (not PowerShell, not CMD)
./backup-org.sh <org-name>
```

## Prerequisites

- `gh` ([GitHub CLI](https://cli.github.com/)) must be installed and authenticated (`gh auth login`)
- `git` must be available on PATH
- On Windows: use **Git Bash** terminal (comes with Git for Windows). PowerShell and CMD cannot execute `.sh` files directly.

## What it does

1. Lists all repos in the org via `gh repo list` (up to 1000)
2. For each repo: clones with `gh repo clone` (handles auth automatically), or if already cloned, fetches all branches with `git fetch --all --prune`
3. Creates local tracking branches for every remote branch
4. Skips repos that fail, continues with remaining repos

Output goes to `$PWD/<org-name>/<repo-name>/`.

## Architecture

Single Bash file. No config, no dependencies beyond `gh` and `git`.

### Error handling

- `set -e` exits on critical failures (missing prerequisites, invalid org)
- Repo-level failures (clone/fetch) are caught and skipped, the script continues with the next repo
- Repo list is written to a temp file (not piped directly into while-read) so `set -e` catches `gh repo list` failures
- `trap` cleans up temp file on exit

### Gotchas

- **Windows**: PowerShell `.\backup-org.sh` will not execute. Use Git Bash.
- Branch names must not contain spaces or special characters
- Org sizes > 1000 repos are truncated at the `--limit 1000` cap
- Empty repos produce a warning but are handled gracefully
