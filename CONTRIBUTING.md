# Contributing Guide

## Branching strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, production-ready. **Protected — PR required.** |
| `develop` | Integration branch. All features merge here first. |
| `feature/<story-id>-short-description` | One branch per user story. |
| `hotfix/<description>` | Urgent fixes on main. |

### Branch naming examples
```
feature/US6.1-jenkins-setup
feature/US7.1-sonarqube-stage
hotfix/fix-null-pointer-facture
```

## Commit message convention

Format: `<type>: <short description>`

| Type | When to use |
|------|-------------|
| `feat` | New feature or user story |
| `fix` | Bug fix |
| `chore` | Build, config, tooling changes |
| `docs` | Documentation only |
| `ci` | Jenkins / pipeline changes |
| `test` | Adding or fixing tests |
| `refactor` | Code restructuring without behaviour change |
| `security` | Security-related changes |

### Examples
```
feat: add SonarQube stage to Jenkinsfile
fix: correct recovery rate calculation in FactureService
chore: add .gitignore entries for secrets
docs: update ARCHITECTURE.md with Docker section
ci: add OWASP dependency-check to pipeline
```

## Pull Request rules

1. Open PR from `feature/*` → `develop` (never directly to `main`).
2. PR title must reference the user story ID: `[US6.2] Jenkinsfile Checkout→Build→Test`.
3. At least **1 approval** required before merging.
4. Pipeline must be **green** (all stages pass) before merging.
5. No secrets, passwords, or API keys in any committed file.

## Definition of Done

A story is Done when:
- [ ] Code is committed on a feature branch
- [ ] PR is reviewed and approved by at least 1 teammate
- [ ] Jenkins pipeline passes (build + tests green)
- [ ] SonarQube Quality Gate passes (from Week 3)
- [ ] No new secrets introduced in the codebase
- [ ] Relevant documentation updated (README / ARCHITECTURE)
- [ ] Story moved to **Done** on the Scrum board
