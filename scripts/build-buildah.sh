#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

declare -A SERVICES=(
  [Banque-Annuaire]=10001
  [Banque-ConfigServer]=10003
  [Banque-ClientService]=10011
  [Banque-CompteService]=10021
  [Banque-CompositeService]=10031
  [Banque-APIGateway]=10000
  [Banque-Frontend]=80
)

TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("${!SERVICES[@]}")
fi

for MODULE in "${TARGETS[@]}"; do
  PORT="${SERVICES[$MODULE]:?Service inconnu : $MODULE}"
  NAME="$(echo "${MODULE#Banque-}" | tr '[:upper:]' '[:lower:]')"
  TAG="localhost/miage-bank/${NAME}:7.0"

  DOCKERFILE="Containerfile"
  if [[ "$MODULE" == "Banque-Frontend" ]]; then
    DOCKERFILE="Banque-Frontend/Containerfile"
  fi

  echo "==> Build de ${MODULE} -> ${TAG} (port ${PORT} avec ${DOCKERFILE})"
  buildah bud \
    --build-arg MODULE="${MODULE}" \
    --build-arg APP_PORT="${PORT}" \
    --layers \
    -f "${DOCKERFILE}" \
    -t "${TAG}" \
    .
done

echo
echo "==> Images construites :"
buildah images --filter 'reference=localhost/miage-bank/*'