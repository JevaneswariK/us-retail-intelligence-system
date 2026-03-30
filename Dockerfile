# Use Java 21 (Temurin)
FROM eclipse-temurin:21-jdk

# Set working directory
WORKDIR /app

# Copy Metabase JAR and start script
COPY metabase.jar .
COPY start.sh .

# Make start.sh executable
RUN chmod +x start.sh

# Expose the port (Render will override with $PORT)
EXPOSE 3000

# Start Metabase
CMD ["./start.sh"]