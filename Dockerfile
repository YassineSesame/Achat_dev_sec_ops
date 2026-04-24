# =============================================================
# Stage 1 — Build the JAR with Maven
# =============================================================
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /app

# Copy pom.xml first and download dependencies (layer cache)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# =============================================================
# Stage 2 — Minimal runtime image (alpine = small + secure)
# =============================================================
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy only the built JAR from stage 1
COPY --from=build /app/target/achat-*.jar app.jar

# Run as non-root user (security best practice — Week 6)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 8089

ENTRYPOINT ["java", "-jar", "app.jar"]
