"""Conexión con el servidor MySQL de pruebas (PyMySQL, protocolo MySQL sobre TCP)."""
from __future__ import annotations

import socket

import pymysql

from .config import ConfigBD, nombre_bd_valido


def puerto_escuchando(cfg: ConfigBD, espera_s: float = 3.0) -> bool:
    """True si hay un proceso aceptando conexiones TCP en host:puerto."""
    try:
        with socket.create_connection((cfg.host, cfg.puerto), timeout=espera_s):
            return True
    except OSError:
        return False


def conectar(cfg: ConfigBD, bd: str | None = None) -> pymysql.connections.Connection:
    """Abre una conexión; si se indica `bd`, solo acepta una base efímera de pruebas.
    La autenticación caching_sha2_password sobre TCP usa el paquete cryptography."""
    if bd is not None:
        nombre_bd_valido(bd, cfg)
    return pymysql.connect(host=cfg.host, port=cfg.puerto, user=cfg.usuario, password=cfg.clave,
                           database=bd, charset="utf8mb4", autocommit=False,
                           connect_timeout=5, read_timeout=60, write_timeout=60)


def version_servidor(con) -> str:
    with con.cursor() as cur:
        cur.execute("SELECT VERSION()")
        return cur.fetchone()[0]
