NOM : GODARD;
Prénom : Lucas

## Architecture déployée

L'application comprend six micro-services Spring Cloud, plus leurs deux bases de
données, le tout dans le namespace `miage-bank` :

| Composant          | Port  | Rôle                                  | Base       |
| ------------------ | ----- | ------------------------------------- | ---------- |
| `annuaire`         | 10001 | Service registry (Eureka)             | —          |
| `configserver`     | 10003 | Config centralisée (Spring Cloud Cfg) | —          |
| `clientservice`    | 10011 | Gestion des clients                   | MySQL      |
| `compteservice`    | 10021 | Gestion des comptes                   | MongoDB    |
| `compositeservice` | 10031 | Agrégation client + compte            | —          |
| `apigateway`       | 10000 | Point d'entrée unique                 | —          |
| `bnkmysql`         | 3306  | Base MySQL (clientservice)            | —          |
| `bnkmongo`         | 27017 | Base MongoDB (compteservice)          | —          |




## 7. Vérifications finales

```bash
kubectl -n miage-bank get pods           # 8 pods Running
kubectl -n miage-bank get externalsecret # SecretSynced / True
kubectl -n miage-bank get ingress        # CLASS=traefik, ADDRESS renseignée
kubectl -n miage-bank get networkpolicy  # 3 policies
kubectl -n argocd get application miage-bank   # Synced / Healthy
```

---

## 8. Points d'amélioration possibles

- **Exposition** : n'exposer que l'API Gateway (ou un frontend dédié) via
  l'Ingress, plutôt qu'une route par micro-service, la gateway assurant déjà le
  routage interne.
- **Vault** : activer la persistance plutôt que le mode dev.
- **Config server** : aligner le label Git (`default-label`) sur la branche réelle
  du dépôt de configuration distant pour supprimer les avertissements
  `RefNotFound` au démarrage.
