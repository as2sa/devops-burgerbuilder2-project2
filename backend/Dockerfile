FROM maven:3.9.6-eclipse-temurin-21 AS build
FROM openjdk:21-jdk-slim 
WORKDIR /app
COPY . /app
RUN mvn clean package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
COPY target/burger-builder-backend-1.0.0.jar app.jar

#-------------------------------------------------------------------------------
