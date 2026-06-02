#!/usr/bin/env bash
# =============================================================================
#  scan-trivy.sh — Analyse de sécurité d'une image MIAGE-Bank avec Trivy
# -----------------------------------------------------------------------------
#  Produit trois sorties dans build-reports/ :
#    - trivy_<nom>.txt    : table lisible (HIGH + CRITICAL)
#    - trivy_<nom>.json   : rapport COMPLET (toutes sévérités) -> machine
#    - trivy_<nom>.sarif  : SARIF (onglet "Security" de GitHub)
#
#  Usage :
#     scripts/scan-trivy.sh localhost/miage-bank/apigateway:7.0
#     scripts/scan-trivy.sh build-reports/apigateway.tar     # archive OCI/docker
# =============================================================================
set -euo pipefail

IMAGE="${1:?Usage: $0 <image[:tag]|archive.tar> [reports_dir]}"
OUT="${2:-build-reports}"
mkdir -p "$OUT"

# Si on reçoit une archive .tar, on scanne via --input, sinon via la référence.
if [[ "$IMAGE" == *.tar ]]; then
  SRC=(--input "$IMAGE")
  NAME="$(basename "$IMAGE" .tar)"
else
  SRC=("$IMAGE")
  NAME="$(echo "$IMAGE" | sed 's#.*/##; s#:.*##')"
fi

echo "==> [Trivy] Table HIGH/CRITICAL"
trivy image --scanners vuln --severity HIGH,CRITICAL --no-progress \
  --format table "${SRC[@]}" | tee "$OUT/trivy_${NAME}.txt"

echo "==> [Trivy] Rapport JSON complet"
trivy image --scanners vuln --no-progress \
  --format json -o "$OUT/trivy_${NAME}.json" "${SRC[@]}"

echo "==> [Trivy] Rapport SARIF (GitHub Security)"
trivy image --scanners vuln --severity HIGH,CRITICAL --no-progress \
  --format sarif -o "$OUT/trivy_${NAME}.sarif" "${SRC[@]}"

echo "OK : rapports Trivy dans $OUT/ (trivy_${NAME}.{txt,json,sarif})"
