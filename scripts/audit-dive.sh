#!/usr/bin/env bash
# =============================================================================
#  audit-dive.sh — Audit de l'image MIAGE-Bank avec Dive en mode CI
# -----------------------------------------------------------------------------
#  Vérifie que l'image respecte les seuils d'efficacité :
#    - Efficacité minimale : 95%
#    - Espace gaspillé maximum : 20 Mo
#    - Pourcentage d'espace gaspillé : 10%
#
#  Usage :
#     scripts/audit-dive.sh build-reports/apigateway.tar
# =============================================================================
set -euo pipefail

ARCHIVE="${1:?Usage: $0 <archive.tar> [reports_dir]}"
OUT="${2:-build-reports}"
mkdir -p "$OUT"

NAME="$(basename "$ARCHIVE" .tar)"
REPORT_FILE="$OUT/dive_${NAME}.txt"

echo "==> [Dive] Démarrage de l'audit CI sur l'archive : $ARCHIVE"
echo "==> [Dive] Seuils : Eff >= 95% | Wasted <= 20MB | Wasted % <= 10%"
echo "----------------------------------------------------------------------"

# Exécution de Dive en ciblant l'archive OCI/Docker locale.
# L'utilisation de 'tee' permet de voir le résultat dans le terminal tout
# en sauvegardant la sortie dans un fichier texte pour les livrables.
dive "docker-archive://${ARCHIVE}" \
  --ci \
  --lowestEfficiency=0.95 \
  --highestWastedBytes=20MB \
  --highestUserWastedPercent=0.10 | tee "$REPORT_FILE"

echo "----------------------------------------------------------------------"
echo "OK : Rapport Dive sauvegardé dans $REPORT_FILE"