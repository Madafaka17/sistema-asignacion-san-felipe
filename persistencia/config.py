"""Configuración de conexión desacoplada del código.

El código no contiene rutas de base de datos, usuarios ni contraseñas: todo se lee de
un archivo .env que no se versiona (.gitignore). Este módulo también aplica las
guardas que impiden usar la prueba contra una base de datos que no sea de pruebas.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

VARIABLES_OBLIGATORIAS = (
    "SF_ENTORNO",      # debe valer "pruebas"
    "SF_BD_HOST",      # solo interfaz local (127.0.0.1, localhost o ::1)
    "SF_BD_PUERTO",    # puerto TCP del servidor MySQL de pruebas
    "SF_BD_USUARIO",   # usuario con privilegios solo sobre las bases sf_test_%
    "SF_BD_CLAVE",     # contraseña generada localmente; nunca se versiona ni se registra
    "SF_BD_PREFIJO",   # prefijo obligatorio de las bases efímeras (sf_test_)
)
HOSTS_LOCALES = {"127.0.0.1", "localhost", "::1"}
VALOR_EJEMPLO_CLAVE = "se_genera_al_iniciar_la_bd"
PATRON_BD = re.compile(r"^sf_test_[a-z0-9_]{1,50}$")


class ErrorConfiguracion(RuntimeError):
    """La configuración falta, está incompleta o apunta a algo que no es de pruebas."""


@dataclass(frozen=True)
class ConfigBD:
    entorno: str
    host: str
    puerto: int
    usuario: str
    clave: str
    prefijo: str

    def resumen_seguro(self) -> dict:
        """Datos de conexión para el registro, con la contraseña enmascarada."""
        return {"entorno": self.entorno, "host": self.host, "puerto": self.puerto,
                "usuario": self.usuario, "clave": "********", "prefijo": self.prefijo}


def leer_env(ruta: Path) -> dict[str, str]:
    """Lector mínimo de archivos .env: líneas CLAVE=valor, comentarios con #, sin
    expansión de variables. Se implementa aquí para no añadir dependencias."""
    if not ruta.is_file():
        raise ErrorConfiguracion(f"no existe el archivo de configuración {ruta.name}; "
                                 "créelo con scripts/bd_efimera.sh iniciar o a partir de .env.example")
    valores: dict[str, str] = {}
    for n, linea in enumerate(ruta.read_text(encoding="utf8").splitlines(), start=1):
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        if "=" not in linea:
            raise ErrorConfiguracion(f"{ruta.name}, línea {n}: se esperaba CLAVE=valor")
        clave, valor = linea.split("=", 1)
        valor = valor.strip()
        if len(valor) >= 2 and valor[0] == valor[-1] and valor[0] in "\"'":
            valor = valor[1:-1]
        valores[clave.strip()] = valor
    return valores


def cargar_config(ruta_env: Path) -> ConfigBD:
    v = leer_env(ruta_env)
    faltan = [k for k in VARIABLES_OBLIGATORIAS if not v.get(k)]
    if faltan:
        raise ErrorConfiguracion("faltan variables obligatorias en .env: " + ", ".join(faltan))
    if v["SF_ENTORNO"] != "pruebas":
        raise ErrorConfiguracion("SF_ENTORNO debe ser 'pruebas'; la prueba de humo no se ejecuta en otro entorno")
    if v["SF_BD_HOST"] not in HOSTS_LOCALES:
        raise ErrorConfiguracion("SF_BD_HOST debe ser una interfaz local (servidor de pruebas efímero)")
    if v["SF_BD_CLAVE"] == VALOR_EJEMPLO_CLAVE:
        raise ErrorConfiguracion("SF_BD_CLAVE conserva el valor de ejemplo de .env.example")
    if not v["SF_BD_PREFIJO"].startswith("sf_test_"):
        raise ErrorConfiguracion("SF_BD_PREFIJO debe empezar por 'sf_test_'")
    try:
        puerto = int(v["SF_BD_PUERTO"])
    except ValueError as exc:
        raise ErrorConfiguracion("SF_BD_PUERTO debe ser un entero") from exc
    return ConfigBD(v["SF_ENTORNO"], v["SF_BD_HOST"], puerto, v["SF_BD_USUARIO"], v["SF_BD_CLAVE"],
                    v["SF_BD_PREFIJO"])


def nombre_bd_valido(nombre: str, cfg: ConfigBD) -> str:
    """Devuelve el nombre si es el de una base efímera de pruebas; si no, detiene todo."""
    if not (nombre.startswith(cfg.prefijo) and PATRON_BD.match(nombre)):
        raise ErrorConfiguracion(f"nombre de base de datos no permitido para pruebas: {nombre!r}")
    return nombre


def env_no_versionado(raiz: Path) -> bool:
    """Comprueba que .env figure en el .gitignore de la raíz del repositorio."""
    gi = raiz / ".gitignore"
    if not gi.is_file():
        return False
    lineas = {l.strip() for l in gi.read_text(encoding="utf8").splitlines()}
    return ".env" in lineas or "/.env" in lineas
