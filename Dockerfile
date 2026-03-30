# Use a stable OpenJDK 11 image compatible with Render
FROM openjdk:11-buster

# Set working directory
WORKDIR /app

# Download Metabase at build time (no large jar in Git)
RUN curl -L https://downloads.metabase.com/latest/metabase.jar -o metabase.jar

# Expose Metabase default port
EXPOSE 3000

# Run Metabase
CMD ["java", "-jar", "metabase.jar"]