# GitOps avec ArgoCD

## Mise en place

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

# Application ArgoCD pointant sur le dépôt
kubectl apply -f argocd/application.yaml
```

L'`Application` (`argocd/application.yaml`) cible la branche `main`, le chemin
`miage-bank/`, avec synchronisation automatique :

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

## Le « problème de l'œuf ou la poule »

ArgoCD synchronise **uniquement le chart applicatif**. Les prérequis (CRD de
l'External Secrets Operator, Vault peuplé) ne peuvent pas être bootstrappés par
cette Application : les `ExternalSecret`/`SecretStore` ne sont validés par l'API
qu'une fois les CRD installées. Ces composants sont donc déployés manuellement
**avant** (voir §3), puis ArgoCD prend le relais sur le chart.

## Exercice de dérive (réconciliation)

Démonstration de la détection de dérive et de l'auto-réparation :

```bash
# 1) On crée une dérive manuelle : on force apigateway à 3 réplicas
kubectl -n miage-bank scale deploy/apigateway --replicas=3

# 2) ArgoCD détecte la divergence : l'Application passe brièvement "OutOfSync"

# 3) selfHeal: true ré-applique l'état du dépôt Git :
#    apigateway revient automatiquement à 1 réplica, statut "Synced"
kubectl -n miage-bank get deploy apigateway
```

*(Captures d'écran : état `Synced/Healthy`, passage `OutOfSync` après le scale,
puis retour automatique à 1 réplica.)*