# Use Eclipse Temurin JDK 21 (LTS)
FROM eclipse-temurin:21-jdk

# Set working directory
WORKDIR /app

# Download Metabase directly (latest stable version 0.50.5 as example)
RUN curl -L -o metabase.jar https://downloads.metabase.com/v0.50.5/metabase.jar

# Copy the start script
COPY start.sh .

# Make start.sh executable
RUN chmod +x start.sh

# Expose Metabase default port
EXPOSE 3000

# Start Metabase
CMD ["./start.sh"]