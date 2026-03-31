
FROM eclipse-temurin:21-jdk-jammy

WORKDIR /app

ADD https://downloads.metabase.com/v0.59.2.5/metabase.jar /app/metabase.jar

CMD ["sh", "-c", "java -Xmx400m -jar metabase.jar --server.port=$PORT"]