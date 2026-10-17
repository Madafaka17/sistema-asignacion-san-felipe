# syntax=docker/dockerfile:1
# =====================================================================
# Cliente web: compila Flutter 3.47.6 para la web y lo sirve con nginx,
# que además hace de proxy inverso de /api hacia el servidor.
# Contexto de construcción: la raíz del repositorio (docker-compose.yml).
# =====================================================================
# Misma imagen base (Debian) que el servidor: ya trae git, curl, unzip y
# los certificados raíz que necesita Flutter. Flutter usa su propio SDK de
# Dart, descargado en `flutter precache`.
FROM dart:3.13.5 AS compilacion
ARG FLUTTER_VERSION=3.47.6
# Certificados opcionales de un proxy corporativo (ver README).
COPY docker/certificados/ /usr/local/share/ca-certificates/extra/
RUN update-ca-certificates

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter
ENV PATH=/opt/flutter/bin:$PATH \
    FLUTTER_SUPPRESS_ANALYTICS=true
RUN flutter --disable-analytics && flutter config --no-cli-animations && flutter precache --web

WORKDIR /app
COPY paquetes/dominio/pubspec.yaml paquetes/dominio/pubspec.lock paquetes/dominio/
COPY cliente/pubspec.yaml cliente/pubspec.lock cliente/
RUN cd cliente && flutter pub get

COPY paquetes/dominio/ paquetes/dominio/
COPY cliente/ cliente/
# Sin CDN: CanvasKit y las fuentes se sirven desde nginx, de modo que el
# cliente funciona en la red local de la empresa sin acceso a internet.
RUN cd cliente && flutter build web --release --no-web-resources-cdn --dart-define=API_URL=/api

# ---------------------------------------------------------------------
FROM nginx:1.28.0-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=compilacion /app/cliente/build/web /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --retries=5 CMD wget -q -O /dev/null http://127.0.0.1/index.html || exit 1
