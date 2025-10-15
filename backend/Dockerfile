# -------- Build stage (Java 21) --------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -DskipTests package

# -------- Run stage (Java 21 JRE) --------
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENV SERVER_PORT=8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
