# Use Eclipse Temurin OpenJDK 11 (widely mirrored, always available)
FROM eclipse-temurin:11-jdk

# Set working directory
WORKDIR /app

# Download Metabase during build
RUN curl -L https://downloads.metabase.com/latest/metabase.jar -o metabase.jar

# Expose Metabase port
EXPOSE 3000

# Run Metabase
CMD ["java", "-jar", "metabase.jar"]