# syntax=docker/dockerfile:1
# =====================================================================
# Servidor: compilación AOT de Dart y una imagen final mínima (scratch)
# Contexto de construcción: la raíz del repositorio (docker-compose.yml).
# =====================================================================
FROM dart:3.13.5 AS compilacion

# Certificados opcionales de un proxy corporativo (ver README); la
# carpeta solo trae .gitkeep en el repositorio.
COPY docker/certificados/ /usr/local/share/ca-certificates/extra/
RUN update-ca-certificates

WORKDIR /app
# Primero solo los pubspec: la capa de dependencias se reutiliza mientras
# no cambien las versiones.
COPY paquetes/dominio/pubspec.yaml paquetes/dominio/pubspec.lock paquetes/dominio/
COPY servidor/pubspec.yaml servidor/pubspec.lock servidor/
RUN cd servidor && dart pub get

COPY paquetes/dominio/ paquetes/dominio/
COPY servidor/ servidor/
RUN mkdir -p /app/bin && cd servidor \
 && dart pub get --offline \
 && dart compile exe bin/servidor.dart -o /app/bin/servidor

# ---------------------------------------------------------------------
FROM scratch
# /runtime/ contiene las bibliotecas mínimas que necesita un ejecutable AOT.
COPY --from=compilacion /runtime/ /
COPY --from=compilacion /app/bin/servidor /app/bin/servidor
COPY config/parametros.yaml /app/config/parametros.yaml
WORKDIR /app
ENV PUERTO=8080 \
    PARAMETROS_ARCHIVO=/app/config/parametros.yaml
# Usuario sin privilegios (nobody).
USER 65534:65534
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=5 CMD ["/app/bin/servidor", "--salud"]
CMD ["/app/bin/servidor"]
