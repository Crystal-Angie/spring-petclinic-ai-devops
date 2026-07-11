# Multi-stage Dockerfile for Spring PetClinic microservices
#
# Usage:
#   docker build -f docker/Dockerfile \
#     --build-arg SERVICE_NAME=spring-petclinic-customers-service \
#     -t petclinic/customers-service:latest .
#
# Stage 1 (builder): compiles the Java source and produces a fat JAR
# Stage 2 (runtime): copies only the extracted JAR layers — no JDK, no source

# ---- Stage 1: Build ----
FROM maven:3.9-eclipse-temurin-17-alpine AS builder

WORKDIR /workspace

# The parent pom.xml declares all modules without the 'app/' prefix.
# Copying app/ contents directly into /workspace makes the module paths match.
COPY pom.xml .
COPY app/ .

# Build the target service and any modules it depends on (-am = also make).
# Tests are skipped here; they run as a separate CI step before this build.
ARG SERVICE_NAME
RUN mvn package -pl ${SERVICE_NAME} -am -DskipTests --no-transfer-progress

# Extract the Spring Boot layered JAR.
# Layered JARs split content into: dependencies, spring-boot-loader,
# snapshot-dependencies, and application. Each becomes a separate Docker layer,
# so a code-only change only rebuilds the tiny 'application' layer (~1-2 MB)
# instead of the full JAR (~100 MB).
RUN java -Djarmode=tools \
    -jar ${SERVICE_NAME}/target/${SERVICE_NAME}-*.jar \
    extract --layers --launcher --destination /workspace/layers

# ---- Stage 2: Runtime ----
FROM eclipse-temurin:17-jre-alpine

# Non-root user — containers should never run as root in production.
# If the process is compromised, an attacker gets a low-privilege user, not root.
RUN addgroup -S spring && adduser -S spring -G spring

WORKDIR /app

# Copy layers from least-changed to most-changed.
# Docker caches each COPY as its own layer. Since dependencies change rarely,
# that large layer is almost always served from cache, keeping builds fast.
COPY --from=builder --chown=spring:spring /workspace/layers/dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/layers/spring-boot-loader/ ./
COPY --from=builder --chown=spring:spring /workspace/layers/snapshot-dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/layers/application/ ./

USER spring:spring

# MaxRAMPercentage: cap heap at 75% of the container's memory limit.
#   Without this, the JVM sizes the heap based on the host machine's total RAM
#   (e.g., 31 GB on a 32 GB node) — ignoring the container limit and causing OOMKills.
# egd: use /dev/urandom instead of /dev/random for SecureRandom.
#   /dev/random blocks when entropy is low, which can add seconds to startup time
#   inside containers where entropy sources are limited.
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

# EXPOSE is documentation — it does not publish the port.
# Actual port binding is set via SERVER_PORT env var or Kubernetes containerPort.
EXPOSE 8080

# Use JarLauncher from the extracted layers instead of 'java -jar'.
# This is required for the layered JAR approach to work correctly.
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
