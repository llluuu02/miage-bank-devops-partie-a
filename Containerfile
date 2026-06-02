# ==========================================
# Étape 1 : Builder
# ==========================================
FROM docker.io/library/maven:3.9-eclipse-temurin-11 AS builder

# Récupération des arguments passés par le script build-buildah.sh
ARG MODULE

WORKDIR /workspace

# Optimisation du cache Maven en copiant d'abord le pom.xml
COPY ${MODULE}/pom.xml .
COPY ${MODULE}/src ./src

# Compilation sans lancer les tests
RUN mvn -B -q -DskipTests clean package && \
    cp target/*.jar application.jar && \
    java -Djarmode=layertools -jar application.jar extract

# ==========================================
# Étape 2 : Runtime (Image finale)
# ==========================================
FROM docker.io/library/eclipse-temurin:11-jre-jammy

ARG APP_PORT

# Création d'un utilisateur non-root pour la sécurité
RUN groupadd --system --gid 1001 spring && \
    useradd --system --uid 1001 --gid spring --no-create-home spring

WORKDIR /app

# Copie des layers extraits depuis l'étape builder (du moins volatile au plus volatile)
COPY --from=builder --chown=spring:spring /workspace/dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/spring-boot-loader/ ./
COPY --from=builder --chown=spring:spring /workspace/snapshot-dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/application/ ./

USER spring:spring

# Variables d'environnement et port
ENV APP_PORT=${APP_PORT}
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"

EXPOSE ${APP_PORT}

# Lancement via le JarLauncher optimisé
ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]