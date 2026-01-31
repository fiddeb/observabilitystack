# Git Workflow and ArgoCD Branch Management

How to make sure `targetRevision` points to `main` before merging.

## The Problem

When working with feature branches, `targetRevision` in the ArgoCD manifest gets updated to point to your feature branch. You need to reset it to `main` before merging, otherwise production breaks.

## Solutions

### 1. Automatic Merge Script

Use `scripts/merge_feature.sh` to automatically handle the entire merge process:

```bash
# Example: Merge feat/loki-s3-storage to main
./scripts/merge_feature.sh feat/loki-s3-storage
```

The script automatically:
1. Commits any changes on the feature branch
2. Resets `targetRevision` to `main`
3. Switches to main branch and updates from remote
4. Merges the feature branch
5. Offers to delete the feature branch

### 2. Git Pre-Merge Hook

A Git hook in `.git/hooks/pre-merge-commit` automatically checks that `targetRevision` is `main` before merge:

```bash
# The hook activates automatically during merge
git merge feat/my-feature
# If targetRevision is not 'main', merge is aborted with error message
```

### 3. Manual Check

If you merge manually, always check `targetRevision` first:

```bash
# Check current targetRevision
grep "targetRevision:" argocd/observability-stack.yaml

# Reset to main if necessary
sed -i 's|targetRevision: .*|targetRevision: main   # auto-synced with current branch|g' argocd/observability-stack.yaml
git add argocd/observability-stack.yaml
git commit -m "fix: reset targetRevision to main before merge"
```

### 4. Force ArgoCD Sync Warnings

`scripts/force_argo_sync.sh` now shows warnings when you're not on the main branch:

```bash
./scripts/force_argo_sync.sh
# ⚠️  WARNING: You are on branch 'feat/my-feature', not 'main'
# 💡 Consider using main branch for production deployments
```

## How to Work with Feature Branches

1. **Create feature branch:**
   ```bash
   git checkout -b feat/my-new-feature
   ```

2. **Develop and test:**
   ```bash
   # Make changes
   git add .
   git commit -m "feat: implement new feature"
   
   # Test with ArgoCD
   ./scripts/force_argo_sync.sh
   ```

3. **Merge to main:**
   ```bash
   # Use automatic merge script
   ./scripts/merge_feature.sh feat/my-new-feature
   
   # Or manually (with Git hook protection)
   git checkout main
   git merge feat/my-new-feature
   ```

4. **Deploy from main:**
   ```bash
   git push origin main
   ./scripts/force_argo_sync.sh
   ```

## Safety Features

- **Git Hook**: Blocks merge if `targetRevision` isn't `main`
- **Merge Script**: Auto-resets before merge
- **Sync Script**: Warns when you're not on main
- **Backup**: `.bak` files created during auto-changes

## Troubleshooting

If merge is aborted by Git hook:
```bash
# Reset targetRevision manually
sed -i 's|targetRevision: .*|targetRevision: main   # auto-synced with current branch|g' argocd/observability-stack.yaml
git add argocd/observability-stack.yaml
git commit -m "fix: reset targetRevision to main before merge"

# Try merge again
git merge feat/my-feature
```
