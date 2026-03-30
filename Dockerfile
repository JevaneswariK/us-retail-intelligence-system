# Use Temurin OpenJDK 17 (Debian-based)
FROM eclipse-temurin:17-jdk

# Set working directory
WORKDIR /app

# Copy start script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Download Metabase latest jar
RUN curl -L https://downloads.metabase.com/latest/metabase.jar -o metabase.jar

# Expose default Metabase port
EXPOSE 3000

# Start Metabase
CMD ["/app/start.sh"]