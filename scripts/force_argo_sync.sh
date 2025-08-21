#!/bin/bash
set -e

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfiguration
ARGOCD_NAMESPACE="argocd"
APP_NAME="observability-stack"
TARGET_NAMESPACE="observability-lab"

echo -e "${BLUE}🔄 Force ArgoCD Sync Script${NC}"
echo "=================================="

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

# Steg 1: Kolla att ArgoCD application finns
echo -e "${BLUE}📋 Kollar ArgoCD application status...${NC}"
if ! kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE &>/dev/null; then
    echo -e "${RED}❌ ArgoCD application '$APP_NAME' hittades inte i namespace '$ARGOCD_NAMESPACE'${NC}"
    exit 1
fi

# Visa nuvarande status
echo -e "${BLUE}📊 Nuvarande status:${NC}"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

# Steg 2: Tvinga refresh (hämta senaste från Git)
echo -e "${BLUE}🔄 Tvingar refresh från Git repository...${NC}"
kubectl annotate application $APP_NAME -n $ARGOCD_NAMESPACE argocd.argoproj.io/refresh=hard --overwrite

# Steg 3: Vänta lite så refresh hinner göras
echo -e "${YELLOW}⏳ Väntar på refresh...${NC}"
sleep 5

# Steg 4: Kolla om det finns ändringar som behöver synkas
echo -e "${BLUE}📋 Kollar sync status efter refresh...${NC}"
sync_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}')
echo "Sync status: $sync_status"

if [ "$sync_status" == "OutOfSync" ]; then
    echo -e "${YELLOW}🔄 Application är OutOfSync - tvingar synkronisering...${NC}"
    
    # Steg 5: Tvinga sync
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

# Steg 6: Vänta på att sync ska slutföras
wait_for_sync

# Steg 7: Visa slutresultat
echo -e "${BLUE}📊 Slutstatus:${NC}"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

echo -e "${BLUE}🏗️  Resurser i target namespace:${NC}"
kubectl get pods,svc,configmap -n $TARGET_NAMESPACE -l "app.kubernetes.io/instance=observability-stack" 2>/dev/null || echo "Inga resurser hittades än"

echo -e "${GREEN}🎉 Script slutfört!${NC}"
