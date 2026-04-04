#!/bin/bash
# =============================================================
# Week 1 — Git Repository Setup Script
# Run this ONCE after cloning the provided source code locally.
# =============================================================

# ---- STEP 1: Initialize repo (if not already a git repo) ----
git init
git remote add origin https://github.com/<YOUR_ORG>/achat.git

# ---- STEP 2: First commit on main ----
git add .
git commit -m "chore: initial commit — provided achat source code"
git branch -M main
git push -u origin main

# ---- STEP 3: Create develop branch ----
git checkout -b develop
git push -u origin develop

# ---- STEP 4: Add Week 1 files ----
# (Copy README.md, .gitignore, CONTRIBUTING.md, ARCHITECTURE.md
#  into the repo root, then:)
git add README.md .gitignore CONTRIBUTING.md ARCHITECTURE.md
git commit -m "docs: add week 1 project setup files"
git push origin develop

# ---- STEP 5: Protect main on GitHub ----
# Go to: GitHub repo → Settings → Branches → Add rule
# Branch name pattern: main
# Check: [x] Require a pull request before merging
# Check: [x] Require approvals (1)
# Check: [x] Do not allow bypassing the above settings
# Save changes.

# ---- STEP 6: Create your Scrum board ----
# Option A — GitHub Projects (free, integrated):
#   GitHub repo → Projects → New Project → Board template
#   Columns: Backlog | In Progress | In Review | Done
#
# Option B — Trello:
#   https://trello.com → create board → same 4 columns

echo "Week 1 Git setup complete."
echo "Next: open a Pull Request from develop → main to verify branch protection works."
