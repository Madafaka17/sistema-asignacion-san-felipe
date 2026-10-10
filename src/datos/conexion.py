"""Conexión a la base de datos MySQL (capa de datos).

Los parámetros se leen de variables de entorno. Si existe un archivo ``.env``
en la raíz del proyecto (ver ``.env.example``) se carga automáticamente; las
variables ya definidas en el sistema tienen prioridad sobre las del archivo.

Uso::

    from src.datos.conexion import obtener_conexion

    with obtener_conexion() as conexion:
        cursor = conexion.cursor(dictionary=True)
        cursor.execute("SELECT * FROM vehiculo WHERE estado = %s", ("operativo",))
        vehiculos = cursor.fetchall()

Verificación rápida desde la terminal::

    python -m src.datos.conexion
"""

from __future__ import annotations

import os
from collections.abc import Iterator, Mapping
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv
from mysql.connector.abstracts import MySQLConnectionAbstract

RAIZ_PROYECTO = Path(__file__).resolve().parents[2]
ARCHIVO_ENV = RAIZ_PROYECTO / ".env"
VARIABLES_OBLIGATORIAS = ("DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD")
PUERTO_POR_DEFECTO = 3306


@dataclass(frozen=True)
class ConfiguracionBD:
    """Parámetros de conexión. La contraseña no aparece al imprimir el objeto."""

    host: str
    puerto: int
    base_datos: str
    usuario: str
    contrasena: str = field(repr=False)


def cargar_configuracion(entorno: Mapping[str, str] | None = None) -> ConfiguracionBD:
    """Construye la configuración a partir de las variables de entorno.

    Args:
        entorno: variables a usar. Si es ``None`` se carga ``.env`` y se usa
            ``os.environ``. Las pruebas pasan un diccionario propio.

    Raises:
        RuntimeError: si falta una variable obligatoria o el puerto no es válido.
    """
    if entorno is None:
        load_dotenv(ARCHIVO_ENV)
        entorno = os.environ

    faltantes = [nombre for nombre in VARIABLES_OBLIGATORIAS if not entorno.get(nombre)]
    if faltantes:
        raise RuntimeError(
            "Faltan variables de entorno: " + ", ".join(faltantes)
            + ". Copie .env.example como .env y complete los valores."
        )

    puerto_texto = entorno.get("DB_PORT") or str(PUERTO_POR_DEFECTO)
    try:
        puerto = int(puerto_texto)
    except ValueError:
        raise RuntimeError(f"DB_PORT debe ser un número entero, se recibió {puerto_texto!r}.") from None
    if not 1 <= puerto <= 65535:
        raise RuntimeError(f"DB_PORT fuera de rango (1-65535): {puerto}.")

    return ConfiguracionBD(
        host=entorno["DB_HOST"],
        puerto=puerto,
        base_datos=entorno["DB_NAME"],
        usuario=entorno["DB_USER"],
        contrasena=entorno["DB_PASSWORD"],
    )


@contextmanager
def obtener_conexion(config: ConfiguracionBD | None = None) -> Iterator[MySQLConnectionAbstract]:
    """Abre una conexión y la cierra al salir del bloque ``with``.

    Si el bloque termina sin errores se confirma la transacción (``commit``);
    si ocurre una excepción se revierte (``rollback``) y la excepción se propaga.
    """
    config = config or cargar_configuracion()
    conexion = mysql.connector.connect(
        host=config.host,
        port=config.puerto,
        database=config.base_datos,
        user=config.usuario,
        password=config.contrasena,
        charset="utf8mb4",
        collation="utf8mb4_0900_ai_ci",
        autocommit=False,
    )
    try:
        yield conexion
        conexion.commit()
    except Exception:
        conexion.rollback()
        raise
    finally:
        conexion.close()


def verificar_conexion() -> str:
    """Devuelve un resumen del servidor; útil para comprobar la instalación."""
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute("SELECT VERSION(), DATABASE()")
        version, base_datos = cursor.fetchone()
        cursor.execute(
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()"
        )
        (num_tablas,) = cursor.fetchone()
        cursor.close()
    return f"Conexión exitosa: MySQL {version}, base de datos '{base_datos}', {num_tablas} tablas/vistas."


if __name__ == "__main__":
    print(verificar_conexion())
