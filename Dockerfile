FROM openjdk:11

WORKDIR /app

# Download Metabase during build
RUN curl -L https://downloads.metabase.com/latest/metabase.jar -o metabase.jar

EXPOSE 3000

CMD ["java", "-jar", "metabase.jar"]