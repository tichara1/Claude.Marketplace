---
name: split-pr
description: Use when a feature branch is too large for review and needs to be split into multiple smaller PRs by architectural layer - manual invocation via /split-pr
---

# Splitting a Large PR

Split a large feature branch into multiple smaller PRs, each covering one architectural layer. The combined result is verified to be identical to the original branch.

**Announce at start:** "I'm using the split-pr skill to split this branch into smaller PRs."

## When to Use

- Current branch has too many changed files for a single review
- You want to split changes by architectural layer (contracts, tests, infrastructure, application, pipelines)

## When NOT to Use

- Branch has fewer than ~10 changed files
- Changes are tightly coupled and can't be split by layer
- Branch has merge conflicts with master

## The Process

### Step 1: Pre-flight — Azure DevOps CLI

Verify `az` CLI is ready. Run each check sequentially — stop at first failure.

**Check 1 — az installed?**
```bash
az --version 2>/dev/null
```
If missing:
> "Azure CLI is not installed. Install it:
> https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
> Then run: `az extension add --name azure-devops`
> Then: `az login`"

Wait for user to confirm installation before proceeding.

**Check 2 — azure-devops extension?**
```bash
az extension show --name azure-devops 2>/dev/null
```
If missing → run: `az extension add --name azure-devops`
If outdated → run: `az extension update --name azure-devops`

**Check 3 — logged in?**
```bash
az account show 2>/dev/null
```
If not logged in → ask user to run `az login` and wait for confirmation.

**Check 4 — parse remote URL and configure defaults**
```bash
git remote get-url origin
# Expected format: https://<company>@dev.azure.com/<company>/<project>/_git/<repository>
```
Extract `<company>`, `<project>`, `<repository>` from the URL.
```bash
az devops configure --defaults organization=https://dev.azure.com/<company> project=<project>
```

**If any check fails and user skips setup:** Set a flag to fall back to manual PR links at the end.

### Step 2: Initialization

Ask the user two questions (one at a time):
1. **JIRA ticket number** (e.g. `2231`)
2. **Vertical name** (e.g. `KAS`, `BZG`, `RDW`)

Then detect:
```bash
# Source branch
git branch --show-current

# Changed files
git diff --name-only master...<source-branch>
```

### Step 3: Classify Files into Layers

Classify each changed file by path pattern. **First match wins.**

| Layer | Branch suffix | Path patterns |
|-------|--------------|---------------|
| 1 | `db-contracts` | `*/Database/**`, `*/Migrations/**`, `*/Contracts/**`, `*/Models/**`, `*/Enums/**`, `*/Events/**`, `*/Dtos/**` |
| 2 | `unit-tests` | `*.Tests.Unit/**`, `*Tests.Unit*/**` |
| 3 | `infrastructure` | `*/Infrastructure/**`, `*/Repositories/**`, `*/Adapters/**`, `*/Persistence/**`, `*/Clients/**` |
| 4 | `application` | `*/Application/**`, `*/Handlers/**`, `*/Pipeline/**`, `*/Services/**`, `*/UseCases/**` |
| 5 | `integration-tests` | `*.Tests.Integration/**`, `*Tests.Integration*/**` |
| 6 | `pipelines` | `**/Dockerfile*`, `**/docker-compose*`, `**/pipelines/**`, `**/*.yaml`, `**/*.yml` |

**Unmatched files → Layer 4** with explanation printed:
```
⚠️  Unclassified → Layer 4: path/to/File.cs (reason)
```

**Skip layers with zero files silently.**

### Step 4: Display Plan & Get Approval

Present the complete plan before touching git:

```
Split plan for <source-branch> → <N> PRs:

Layer 1 — dtoll-<ticket>-<vertical>-db-contracts (from master)
  path/to/Models/Foo.cs
  path/to/Enums/Bar.cs
  Commit: [DTOLL-<ticket>] <Vertical> - add db migration, models and enums

Layer 2 — dtoll-<ticket>-<vertical>-unit-tests (from layer 1)
  path/to/Tests.Unit/FooTests.cs
  Commit: [DTOLL-<ticket>] <Vertical> - add unit tests

⚠️  Unclassified → Layer 4: path/to/Helper.cs (business logic)

Approve this plan? [y/n]
```

**Wait for approval.** If user says no → abort, no git changes made.

### Step 5: Execute Layer by Layer

For each non-empty layer:

**Layer 1 — from master:**
```bash
git checkout master
git checkout -b dtoll-<ticket>-<vertical>-db-contracts
git checkout <source-branch> -- <file1> <file2> ...
git add .
git commit -m "[DTOLL-<ticket>] <Vertical> - <description>"
```

**Layers 2–6 — from previous layer's branch:**
```bash
git checkout dtoll-<ticket>-<vertical>-<prev-suffix>
git checkout -b dtoll-<ticket>-<vertical>-<suffix>
git checkout <source-branch> -- <file1> <file2> ...
git add .
git commit -m "[DTOLL-<ticket>] <Vertical> - <description>"
```

**Default commit descriptions per layer:**
| Layer | Description |
|-------|-------------|
| 1 | `add db migration, models and enums` |
| 2 | `add unit tests` |
| 3 | `add repositories and infrastructure` |
| 4 | `add application handlers and pipeline` |
| 5 | `add integration tests` |
| 6 | `add docker and pipeline configuration` |

**After each layer, pause and ask:**
```
✓ Branch dtoll-<ticket>-<vertical>-<suffix> created (<N> files, 1 commit).
  Continue to layer <next> (<suffix>)? [y/n]
```

If user says no → stop. Already-created branches remain intact.

### Step 6: Final Verification

Compare combined result with original source branch:

```bash
git diff master...<last-layer-branch> > /tmp/split_combined.diff
git diff master...<source-branch> > /tmp/split_original.diff
diff /tmp/split_original.diff /tmp/split_combined.diff
rm -f /tmp/split_combined.diff /tmp/split_original.diff
```

- **Match:** `✓ Verification passed: all changes from <source-branch> are present in the split branches.`
- **Mismatch:** List missing/extra files and suggest which layer they belong to. Do NOT proceed to PR creation.

### Step 7: Push & Create Draft PRs

For each layer branch, push and create a draft PR:

```bash
git push -u origin dtoll-<ticket>-<vertical>-<suffix>

az repos pr create \
  --title "[DTOLL-<ticket>] <Vertical> - <description>" \
  --source-branch dtoll-<ticket>-<vertical>-<suffix> \
  --target-branch <target> \
  --repository <repository> \
  --org https://dev.azure.com/<company> \
  --project <project> \
  --draft
```

`<target>` is `master` for layer 1, or the previous layer's branch for layers 2+.

**Fallback (if az unavailable):** Display manual PR creation links:
```
https://dev.azure.com/<company>/<project>/_git/<repository>/pullrequestcreate?sourceRef=<branch>&targetRef=<target>
```

### Step 8: Summary

Display all PRs in one place:

```
─────────────────────────────────────────────
✓ Split complete. PRs created:

1. [DTOLL-<ticket>] <Vertical> - add db migration, models and enums
   PR #42 → https://dev.azure.com/.../pullrequest/42

2. [DTOLL-<ticket>] <Vertical> - add unit tests
   PR #43 → https://dev.azure.com/.../pullrequest/43

...
─────────────────────────────────────────────
```

## Quick Reference

| Layer | Suffix | Base | Description |
|-------|--------|------|-------------|
| 1 | `db-contracts` | `master` | DB, Models, Enums, Contracts |
| 2 | `unit-tests` | layer 1 | Unit test projects |
| 3 | `infrastructure` | layer 2 | Repositories, Adapters |
| 4 | `application` | layer 3 | Handlers, Services + unmatched files |
| 5 | `integration-tests` | layer 4 | Integration test projects |
| 6 | `pipelines` | layer 5 | Dockerfiles, YAML pipelines |

## Common Mistakes

**Forgetting az CLI pre-flight**
- Always check az before any git operations — don't discover it's missing after creating 5 branches

**Wrong branch base**
- Layer 1: always from `master`
- Layers 2+: always from previous layer branch, never from master

**Multiple commits per branch**
- Always ONE commit per branch
- Format: `[DTOLL-<ticket>] <Vertical> - <description>`

**Skipping verification**
- Always run diff comparison before pushing — a missed file means the split is incomplete

## Red Flags

**Never:**
- Skip verification step
- Delete the original source branch
- Force-push any branch
- Create PRs that don't chain correctly (wrong target branch)
- Proceed to PR creation if verification fails

**Always:**
- Show full plan before executing any git operations
- Pause between layers for user confirmation
- Verify combined diff matches original
- Display all PR links together at the end
