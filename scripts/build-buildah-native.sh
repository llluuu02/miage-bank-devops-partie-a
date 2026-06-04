#!/usr/bin/env bash
# =============================================================================
#  build-buildah-native.sh — Build layer par layer sans Containerfile
# -----------------------------------------------------------------------------
#  Mode natif Buildah (from / run / copy / config / commit).
#  On reproduit le résultat du Containerfile
#
#  Exemple d'usage :
#     scripts/build-buildah-native.sh src/Banque-APIGateway 10000
#     scripts/build-buildah-native.sh src/Banque-CompteService 10021 monimage:tag
#
#  /!\ non utilisable pour la création d'une image Frontend
#      la CI utilise le build avec Containerfile
# =============================================================================

# le script s'arrête si une commande échoue
set -euo pipefail

# récupération des arguments (nom appli, numéro port, nom tag image, tag)
MODULE="${1:?Usage: $0 <Banque-Module> <app_port> [image_tag]}"
APP_PORT="${2:?Port applicatif requis}"
NAME="$(echo "${MODULE#Banque-}" | tr '[:upper:]' '[:lower:]')"
TAG="${3:-localhost/miage-bank/${NAME}:7.0-native}"

# définition des images de base Maven/JRE
MAVEN_IMG="docker.io/library/maven:3.9-eclipse-temurin-11"
RUNTIME_IMG="docker.io/library/eclipse-temurin:11-jre-jammy"

# déplacement à la racine du projet
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# dossier temporaire (supprimé si le script plante)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# compilation Maven
# -----------------------------------------------------------------------------
echo "==> [1/4] Compilation Maven de ${MODULE} dans un conteneur builder jetable"
# -----------------------------------------------------------------------------
bld="$(buildah from "$MAVEN_IMG")"
buildah run "$bld" -- mkdir -p /workspace/extracted
buildah copy "$bld" "${MODULE}/pom.xml" /workspace/pom.xml
buildah copy "$bld" "${MODULE}/src"     /workspace/src
buildah run --workingdir /workspace "$bld" -- mvn -B -q -DskipTests clean package
buildah run --workingdir /workspace "$bld" -- \
    bash -c 'cp target/*.jar /workspace/application.jar'
buildah run --workingdir /workspace/extracted "$bld" -- \
    java -Djarmode=layertools -jar /workspace/application.jar extract

# récupération des artefacts
# -----------------------------------------------------------------------------
echo "==> [2/4] Extraction des couches du builder vers l'hôte (tar, sans mount)"
# -----------------------------------------------------------------------------
buildah run "$bld" -- tar -C /workspace/extracted -cf - . | tar -C "$WORK" -xf -
buildah rm "$bld" >/dev/null

# runtime / conteneur final
# -----------------------------------------------------------------------------
echo "==> [3/4] Assemblage natif de l'image runtime"
# -----------------------------------------------------------------------------
# création conteneur JRE
ctr="$(buildah from "$RUNTIME_IMG")"

# création utilisateur non-root
buildah run "$ctr" -- groupadd --system --gid 1001 spring
buildah run "$ctr" -- useradd  --system --uid 1001 --gid spring --no-create-home spring

# gestion du cache, copie des 4 couches du JAR, dans l'ordre moins->plus volatile
buildah copy --chown spring:spring "$ctr" "$WORK/dependencies"          /app
buildah copy --chown spring:spring "$ctr" "$WORK/spring-boot-loader"     /app
buildah copy --chown spring:spring "$ctr" "$WORK/snapshot-dependencies"  /app
buildah copy --chown spring:spring "$ctr" "$WORK/application"            /app

# configuration des métadonnées du conteneur
buildah config \
  --workingdir /app \
  --user spring:spring \
  --port "${APP_PORT}" \
  --env "APP_PORT=${APP_PORT}" \
  --env "JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0" \
  --label "org.opencontainers.image.title=miage-bank-${NAME}" \
  --label "org.opencontainers.image.version=7.0" \
  --entrypoint '["java","org.springframework.boot.loader.JarLauncher"]' \
  "$ctr"

# sauvegarde de l'image
# -----------------------------------------------------------------------------
echo "==> [4/4] Commit de l'image -> ${TAG}"
# -----------------------------------------------------------------------------
buildah commit --rm "$ctr" "$TAG"
buildah images "$TAG"
echo "OK : image native ${TAG} construite."
