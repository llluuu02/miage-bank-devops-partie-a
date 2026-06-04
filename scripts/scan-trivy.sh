#!/usr/bin/env bash
# =============================================================================
#  scan-trivy.sh — Analyse de sécurité d'une image MIAGE-Bank avec Trivy
# -----------------------------------------------------------------------------
#  Produit trois sorties dans build-reports/ :
#    - trivy_<nom>.txt    : table lisible (HIGH + CRITICAL)
#    - trivy_<nom>.json   : rapport COMPLET (toutes sévérités) -> machine
#    - trivy_<nom>.sarif  : SARIF (onglet "Security" de GitHub)
#  Execution via CI Github : pas de build-reports --> artifacts
#
#  Exemple d'usage (après build d'image):
#     scripts/scan-trivy.sh localhost/miage-bank/apigateway:7.0
#     scripts/scan-trivy.sh build-reports/apigateway.tar
# =============================================================================

# le script s'arrête si une commande échoue
set -euo pipefail

# récupération des arguments
IMAGE="${1:?Usage: $0 <image[:tag]|archive.tar> [reports_dir]}"
OUT="${2:-build-reports}"
mkdir -p "$OUT"

# si on reçoit une archive .tar, on scanne via --input, sinon via la référence
if [[ "$IMAGE" == *.tar ]]; then
  SRC=(--input "$IMAGE")
  NAME="$(basename "$IMAGE" .tar)"
else
  SRC=("$IMAGE")
  NAME="$(echo "$IMAGE" | sed 's#.*/##; s#:.*##')"
fi

# export du scan en format TXT et affichage dans le terminal (uniquement HIGH et CRITICAL)
echo "==> [Trivy] Table HIGH/CRITICAL"
trivy image --scanners vuln --severity HIGH,CRITICAL --no-progress \
  --format table "${SRC[@]}" | tee "$OUT/trivy_${NAME}.txt"

# export du scan en format JSON
echo "==> [Trivy] Rapport JSON complet"
trivy image --scanners vuln --no-progress \
  --format json -o "$OUT/trivy_${NAME}.json" "${SRC[@]}"

# export du scan en format SARIF
echo "==> [Trivy] Rapport SARIF (GitHub Security)"
trivy image --scanners vuln --severity HIGH,CRITICAL --no-progress \
  --format sarif -o "$OUT/trivy_${NAME}.sarif" "${SRC[@]}"

echo "OK : rapports Trivy dans $OUT/ (trivy_${NAME}.{txt,json,sarif})"
