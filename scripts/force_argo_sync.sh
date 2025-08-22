#!/bin/bash
set -e

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Säkerställ att vi är i rätt katalog (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Konfiguration
ARGOCD_NAMESPACE="argocd"
APP_NAME="observability-stack"
TARGET_NAMESPACE="observability-lab"
ARGOCD_APP_MANIFEST="argocd/observability-stack.yaml"

echo -e "${BLUE}🔄 Force ArgoCD Sync Script${NC}"
echo "=================================="

# Hämta aktuell Git branch (efter att vi säkerställt rätt katalog)
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Varning om vi inte är på main branch
if [ "$current_branch" != "main" ]; then
    echo -e "${YELLOW}⚠️  WARNING: You are on branch '$current_branch', not 'main'${NC}"
    echo -e "${YELLOW}💡 Consider using main branch for production deployments${NC}"
    echo -e "${YELLOW}   To merge properly: ./scripts/merge_feature.sh $current_branch${NC}"
    echo ""
fi

# Steg 1: Kontrollera aktuell Git branch och ArgoCD targetRevision
echo -e "${BLUE}🔍 Kontrollerar Git branch och ArgoCD targetRevision...${NC}"

# Hämta aktuell Git branch
echo -e "Aktuell Git branch: ${YELLOW}$current_branch${NC}"

# Hämta nuvarande targetRevision från ArgoCD application
current_target=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || echo "Unknown")
echo -e "ArgoCD targetRevision: ${YELLOW}$current_target${NC}"

# Kontrollera om targetRevision behöver uppdateras
if [ "$current_branch" != "$current_target" ]; then
    echo -e "${YELLOW}🔄 Uppdaterar ArgoCD targetRevision från '$current_target' till '$current_branch'${NC}"
    
    # Uppdatera targetRevision i YAML-filen
    sed -i.bak "s|targetRevision: .*|targetRevision: $current_branch   # auto-synced with current branch|g" "$ARGOCD_APP_MANIFEST"
    
    # Applicera den uppdaterade manifestet
    echo -e "${BLUE}📄 Applicerar uppdaterat ArgoCD application manifest...${NC}"
    kubectl apply -f "$ARGOCD_APP_MANIFEST" -n $ARGOCD_NAMESPACE
    
    # Vänta lite på att uppdateringen ska registreras
    sleep 3
    
    # Verifiera att targetRevision har uppdaterats
    new_target=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.source.targetRevision}')
    echo -e "Ny targetRevision: ${GREEN}$new_target${NC}"
else
    echo -e "${GREEN}✅ ArgoCD targetRevision matchar redan aktuell branch${NC}"
fi

# Funktion för att vänta på sync
wait_for_sync() {
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}⏳ Väntar på att synkronisering ska slutföras...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        sync_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        health_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        echo -e "Attempt $attempt/$max_attempts - Sync: ${sync_status}, Health: ${health_status}"
        
        if [ "$sync_status" == "Synced" ] && [ "$health_status" == "Healthy" ]; then
            echo -e "${GREEN}✅ Synkronisering slutförd!${NC}"
            return 0
        fi
        
        sleep 5
        ((attempt++))
    done
    
    echo -e "${YELLOW}⚠️  Timeout: Synkroniseringen tog längre tid än förväntat${NC}"
    return 1
}

# Steg 2: Kolla att ArgoCD application finns och visa status
echo -e "${BLUE}📋 Kollar ArgoCD application status...${NC}"
if ! kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE &>/dev/null; then
    echo -e "${RED}❌ ArgoCD application '$APP_NAME' hittades inte i namespace '$ARGOCD_NAMESPACE'${NC}"
    exit 1
fi

# Visa nuvarande status
echo -e "${BLUE}📊 Nuvarande status:${NC}"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

# Steg 3: Tvinga refresh (hämta senaste från Git)
echo -e "${BLUE}🔄 Tvingar refresh från Git repository...${NC}"
kubectl annotate application $APP_NAME -n $ARGOCD_NAMESPACE argocd.argoproj.io/refresh=hard --overwrite

# Steg 4: Vänta lite så refresh hinner göras
echo -e "${YELLOW}⏳ Väntar på refresh...${NC}"
sleep 5

# Steg 5: Kolla om det finns ändringar som behöver synkas
echo -e "${BLUE}📋 Kollar sync status efter refresh...${NC}"
sync_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}')
echo "Sync status: $sync_status"

if [ "$sync_status" == "OutOfSync" ]; then
    echo -e "${YELLOW}🔄 Application är OutOfSync - tvingar synkronisering...${NC}"
    
    # Steg 6: Tvinga sync
    kubectl patch application $APP_NAME -n $ARGOCD_NAMESPACE --type='merge' -p='{
        "operation": {
            "sync": {
                "syncStrategy": {
                    "apply": {
                        "force": true
                    }
                }
            }
        }
    }'
    
    # Aktivera auto-sync om det inte är aktivt
    kubectl patch application $APP_NAME -n $ARGOCD_NAMESPACE --type='merge' -p='{
        "spec": {
            "syncPolicy": {
                "automated": {
                    "prune": true,
                    "selfHeal": true
                }
            }
        }
    }'
    
elif [ "$sync_status" == "Synced" ]; then
    echo -e "${GREEN}✅ Application är redan synkad${NC}"
else
    echo -e "${YELLOW}ℹ️  Sync status: $sync_status${NC}"
fi

# Steg 7: Vänta på att sync ska slutföras
wait_for_sync

# Steg 8: Visa slutresultat
echo -e "${BLUE}📊 Slutstatus:${NC}"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

echo -e "${BLUE}🏗️  Resurser i target namespace:${NC}"
kubectl get pods,svc,configmap -n $TARGET_NAMESPACE -l "app.kubernetes.io/instance=observability-stack" 2>/dev/null || echo "Inga resurser hittades än"

echo -e "${GREEN}🎉 Script slutfört!${NC}"
