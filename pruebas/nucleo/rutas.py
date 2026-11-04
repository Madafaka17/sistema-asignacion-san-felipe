"""Rutas del repositorio usadas por la suite.

El paquete del experimento se llama experimentos/sanfelipe; en la copia registrada el 6/10/2026 se llamaba
experimentos/sintetico_sanfelipe. La suite usa el nombre actual y, si no existe, el anterior. El registro del
protocolo (registro_protocolo.txt) conserva el nombre anterior en sus rutas; clave_registro() hace la
equivalencia para comparar huellas.
"""
from __future__ import annotations

from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
NOMBRE_ACTUAL, NOMBRE_ANTERIOR = "sanfelipe", "sintetico_sanfelipe"


def carpeta_sanfelipe(raiz: Path = RAIZ) -> Path:
    for nombre in (NOMBRE_ACTUAL, NOMBRE_ANTERIOR):
        ruta = raiz / "experimentos" / nombre
        if (ruta / "generador_sanfelipe.py").exists():
            return ruta
    raise FileNotFoundError("no se encontró experimentos/sanfelipe ni experimentos/sintetico_sanfelipe")


SANFELIPE = carpeta_sanfelipe()
SANFELIPE_REL = SANFELIPE.relative_to(RAIZ).as_posix()


def clave_registro(relativa: str) -> str:
    """Ruta con la que el registro del 6/10/2026 identifica un archivo del experimento."""
    return relativa.replace(f"experimentos/{NOMBRE_ACTUAL}/", f"experimentos/{NOMBRE_ANTERIOR}/", 1)
