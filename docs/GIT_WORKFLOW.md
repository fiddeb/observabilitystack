# Git Workflow och ArgoCD Branch Management

Detta dokument beskriver hur vi säkerställer att `targetRevision` alltid är korrekt innan merge till main.

## Problem

När vi arbetar med feature branches uppdateras `targetRevision` i ArgoCD-manifestet för att peka på feature branch. Man måste komma ihåg att återställa den till `main` innan merge.

## Lösningar

### 1. Automatiskt Merge Script

Använd `scripts/merge_feature.sh` för att automatiskt hantera hela merge-processen:

```bash
# Exempel: Merga feat/loki-s3-storage till main
./scripts/merge_feature.sh feat/loki-s3-storage
```

Scriptet gör följande automatiskt:
1. Committar eventuella ändringar på feature branch
2. Återställer `targetRevision` till `main`
3. Byter till main branch och uppdaterar från remote
4. Mergar feature branch
5. Erbjuder att ta bort feature branch

### 2. Git Pre-Merge Hook

En Git hook i `.git/hooks/pre-merge-commit` kontrollerar automatiskt att `targetRevision` är `main` innan merge:

```bash
# Hooken aktiveras automatiskt vid merge
git merge feat/my-feature
# Om targetRevision inte är 'main' så avbryts merge med felmeddelande
```

### 3. Manuell Kontroll

Om du mergar manuellt, kontrollera alltid `targetRevision` först:

```bash
# Kontrollera nuvarande targetRevision
grep "targetRevision:" argocd/observability-stack.yaml

# Återställ till main om nödvändigt
sed -i 's|targetRevision: .*|targetRevision: main   # auto-synced with current branch|g' argocd/observability-stack.yaml
git add argocd/observability-stack.yaml
git commit -m "fix: reset targetRevision to main before merge"
```

### 4. Force ArgoCD Sync Varningar

`scripts/force_argo_sync.sh` visar nu varningar när du inte är på main branch:

```bash
./scripts/force_argo_sync.sh
# ⚠️  WARNING: You are on branch 'feat/my-feature', not 'main'
# 💡 Consider using main branch for production deployments
```

## Rekommenderat Workflow

1. **Skapa feature branch:**
   ```bash
   git checkout -b feat/my-new-feature
   ```

2. **Utveckla och testa:**
   ```bash
   # Gör ändringar
   git add .
   git commit -m "feat: implement new feature"
   
   # Testa med ArgoCD
   ./scripts/force_argo_sync.sh
   ```

3. **Merga till main:**
   ```bash
   # Använd automatiska merge-scriptet
   ./scripts/merge_feature.sh feat/my-new-feature
   
   # Eller manuellt (med Git hook-skydd)
   git checkout main
   git merge feat/my-new-feature
   ```

4. **Deploy från main:**
   ```bash
   git push origin main
   ./scripts/force_argo_sync.sh
   ```

## Säkerhetsåtgärder

- **Git Hook**: Förhindrar merge om `targetRevision` inte är `main`
- **Merge Script**: Automatisk återställning innan merge
- **Sync Script**: Varnar när du inte är på main branch
- **Backup**: `.bak` filer skapas vid automatiska ändringar

## Felsökning

Om merge avbryts av Git hook:
```bash
# Återställ targetRevision manuellt
sed -i 's|targetRevision: .*|targetRevision: main   # auto-synced with current branch|g' argocd/observability-stack.yaml
git add argocd/observability-stack.yaml
git commit -m "fix: reset targetRevision to main before merge"

# Försök merge igen
git merge feat/my-feature
```
