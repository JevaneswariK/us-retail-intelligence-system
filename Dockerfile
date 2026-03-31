FROM eclipse-temurin:21-jdk-jammy

WORKDIR /app

# Install curl
RUN apt-get update && apt-get install -y curl

# Download Metabase properly
RUN curl -L https://downloads.metabase.com/v0.59.2.5/metabase.jar -o metabase.jar

CMD ["sh", "-c", "java -Xmx512m -jar metabase.jar"]