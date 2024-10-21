ARG APP_VERSION=latest

FROM maven:3.8-eclipse-temurin-17-alpine AS dependency-builder
COPY pom.xml pom.xml
RUN mvn dependency:copy-dependencies -DoutputDirectory=/tmp/dependencies

FROM quay.io/keycloak/keycloak:${APP_VERSION} AS builder
COPY --from=dependency-builder /tmp/dependencies/* /opt/keycloak/providers/

WORKDIR /opt/keycloak

ENV KC_DB=mssql

RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:${APP_VERSION}
COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]