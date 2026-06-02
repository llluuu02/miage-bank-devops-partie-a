#!/usr/bin/env bash
# =============================================================================
#  build-buildah-native.sh — Build "layer par layer" SANS Containerfile
# -----------------------------------------------------------------------------
#  Approche 2 du sujet : mode natif Buildah (from / run / copy / config /
#  commit). On reproduit EXACTEMENT le résultat du Containerfile, mais de façon
#  impérative et scriptée — utile quand le build est dynamique.
#
#  Usage :
#     scripts/build-buildah-native.sh Banque-APIGateway 10000
#     scripts/build-buildah-native.sh Banque-CompteService 10021 monimage:tag
#
#  Aucune dépendance Maven/JDK sur l'hôte : le build Maven s'exécute lui-même
#  dans un conteneur Buildah jetable.
# =============================================================================
set -euo pipefail

MODULE="${1:?Usage: $0 <Banque-Module> <app_port> [image_tag]}"
APP_PORT="${2:?Port applicatif requis}"
NAME="$(echo "${MODULE#Banque-}" | tr '[:upper:]' '[:lower:]')"
TAG="${3:-localhost/miage-bank/${NAME}:7.0-native}"

MAVEN_IMG="docker.io/library/maven:3.9-eclipse-temurin-11"
RUNTIME_IMG="docker.io/library/eclipse-temurin:11-jre-jammy"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

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

# -----------------------------------------------------------------------------
echo "==> [2/4] Extraction des couches du builder vers l'hôte (tar, sans mount)"
# -----------------------------------------------------------------------------
buildah run "$bld" -- tar -C /workspace/extracted -cf - . | tar -C "$WORK" -xf -
buildah rm "$bld" >/dev/null

# -----------------------------------------------------------------------------
echo "==> [3/4] Assemblage natif de l'image runtime"
# -----------------------------------------------------------------------------
ctr="$(buildah from "$RUNTIME_IMG")"

# Utilisateur non-root (équivalent du RUN groupadd/useradd du Containerfile)
buildah run "$ctr" -- groupadd --system --gid 1001 spring
buildah run "$ctr" -- useradd  --system --uid 1001 --gid spring --no-create-home spring

# Copie des 4 couches du JAR, dans l'ordre moins->plus volatile
buildah copy --chown spring:spring "$ctr" "$WORK/dependencies"          /app
buildah copy --chown spring:spring "$ctr" "$WORK/spring-boot-loader"     /app
buildah copy --chown spring:spring "$ctr" "$WORK/snapshot-dependencies"  /app
buildah copy --chown spring:spring "$ctr" "$WORK/application"            /app

# Métadonnées (équivalent ENV / USER / EXPOSE / ENTRYPOINT du Containerfile)
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

# -----------------------------------------------------------------------------
echo "==> [4/4] Commit de l'image -> ${TAG}"
# -----------------------------------------------------------------------------
buildah commit --rm "$ctr" "$TAG"
buildah images "$TAG"
echo "OK : image native ${TAG} construite."
