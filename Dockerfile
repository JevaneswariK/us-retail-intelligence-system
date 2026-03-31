FROM eclipse-temurin:21-jdk-jammy

WORKDIR /app

ADD https://downloads.metabase.com/v0.59.2.5/metabase.jar /app/metabase.jar

EXPOSE 3000

CMD ["java", "-jar", "metabase.jar"]