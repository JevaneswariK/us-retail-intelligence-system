# Use Temurin OpenJDK 17 (LTS)
FROM eclipse-temurin:17-jdk:alpine

# Set working directory
WORKDIR /app

# Download latest Metabase jar (version 0.55.7 recommended for Java 17)
RUN curl -L https://downloads.metabase.com/v0.55.7/metabase.jar -o metabase.jar

# Expose Metabase port
EXPOSE 3000

# Run Metabase
CMD ["java", "-jar", "metabase.jar"]