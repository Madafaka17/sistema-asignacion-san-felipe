"""Compilación determinista del código del proyecto a bytecode y registro de la construcción.

Compila con invalidación por hash de la fuente (checked-hash): el bytecode no incluye la
fecha de modificación de los archivos, de modo que la misma fuente produce el mismo
bytecode. Se compila con rutas relativas a la raíz para que el resultado no dependa de
la carpeta donde se clonó el repositorio. Escribe .build/construccion.json.

    .venv/bin/python -s scripts/compilar.py      (lo invoca scripts/aprovisionar.sh)
"""
from __future__ import annotations

import compileall
import hashlib
import importlib.util
import json
import os
import platform
import py_compile
import sys
from datetime import datetime, timezone
from importlib import metadata
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
# Adaptación del 2026-11-04: en el repositorio del sistema, pruebas/ también contiene
# pruebas/nucleo y pruebas/corrida; se compila solo lo que compilaba el paquete original.
FUENTES = ["core", "persistencia", "pruebas/__init__.py", "pruebas/humo", "experimentos/poc_cap3/validador.py"]


def sha256(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def main() -> int:
    os.chdir(RAIZ)
    if not sys.pycache_prefix:
        print("PYTHONPYCACHEPREFIX no está definido; cargue scripts/entorno_determinista.sh", file=sys.stderr)
        return 1
    modo = py_compile.PycInvalidationMode.CHECKED_HASH
    ok = True
    archivos = []
    for f in FUENTES:
        p = Path(f)
        if p.is_dir():
            ok &= bool(compileall.compile_dir(f, quiet=1, force=True, invalidation_mode=modo))
            archivos += sorted(x.as_posix() for x in p.rglob("*.py"))
        else:
            ok &= bool(compileall.compile_file(f, quiet=1, force=True, invalidation_mode=modo))
            archivos.append(p.as_posix())
    if not ok:
        print("error de compilación", file=sys.stderr)
        return 1

    agregado = hashlib.sha256()
    for fuente in sorted(archivos):
        pyc = Path(importlib.util.cache_from_source(fuente))
        agregado.update(f"{fuente}\0{sha256(pyc)}\n".encode())
    registro = {
        "fecha_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "python": platform.python_version(),
        "pip": metadata.version("pip"),
        "paquetes": {d.metadata["Name"]: d.version for d in sorted(metadata.distributions(),
                                                                    key=lambda d: d.metadata["Name"].lower())},
        "sha256_requirements_lock": sha256(RAIZ / "requirements.lock"),
        "sha256_sistema_lock": sha256(RAIZ / "sistema.lock"),
        "modulos_compilados": len(archivos),
        "huella_bytecode": agregado.hexdigest(),
    }
    destino = RAIZ / ".build" / "construccion.json"
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(registro, indent=2, ensure_ascii=False) + "\n", encoding="utf8")
    print(f"módulos compilados: {len(archivos)}; huella del bytecode: {registro['huella_bytecode']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
