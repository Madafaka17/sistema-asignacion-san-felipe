"""Declaración del entorno de ejecución de las pruebas (sesión 9, documentación académica).

Registra arquitectura de hardware, sistema operativo, intérprete y sus parámetros, formato de
punto flotante, bibliotecas, variables de entorno que fijan el determinismo y las huellas SHA-256
del código evaluado. Uso:  python pruebas/nucleo/entorno.py salidas/entorno.json
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import sysconfig
from pathlib import Path

from rutas import RAIZ, SANFELIPE, SANFELIPE_REL, clave_registro

ARCHIVOS_EVALUADOS = [
    "core/__init__.py", "core/conflicts.py", "core/domain.py", "core/fitness.py", "core/repair.py",
    "core/scheduler.py", "experimentos/poc_cap3/metodos.py", "experimentos/poc_cap3/exhaustivo.py",
    "experimentos/poc_cap3/validador.py", f"{SANFELIPE_REL}/generador_sanfelipe.py",
]
VARIABLES = ["PYTHONHASHSEED", "PYTHONNOUSERSITE", "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
             "NUMEXPR_NUM_THREADS", "TZ", "LC_ALL", "LANG"]


def _leer(ruta):
    try:
        return Path(ruta).read_text(encoding="utf8", errors="replace")
    except OSError:
        return ""


def _sha256(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def _registradas() -> dict:
    """Huellas del registro del protocolo (6/10/2026) para comprobar que el código no cambió."""
    texto = _leer(SANFELIPE / "registro_protocolo.txt")
    return {m.group(2): m.group(1) for m in re.finditer(r"^([0-9a-f]{64})\s+(\S+)$", texto, re.M)}


def capturar() -> dict:
    import numpy
    import pulp
    import pygad
    import pytest

    cpuinfo = _leer("/proc/cpuinfo")
    meminfo = _leer("/proc/meminfo")
    modelo = re.search(r"model name\s*:\s*(.+)", cpuinfo)
    banderas = re.search(r"flags\s*:\s*(.+)", cpuinfo)
    memoria = re.search(r"MemTotal:\s*(\d+) kB", meminfo)
    so = re.search(r'PRETTY_NAME="([^"]+)"', _leer("/etc/os-release"))

    cbc = ""
    try:
        ruta_cbc = pulp.PULP_CBC_CMD().path
        salida = subprocess.run([ruta_cbc, "-quit"], capture_output=True, text=True, timeout=20).stdout
        version = re.search(r"Version:\s*(\S+)", salida)
        cbc = version.group(1) if version else salida.strip().splitlines()[0]
    except Exception as exc:  # noqa: BLE001 - se informa, no se oculta
        cbc = f"no disponible ({exc})"

    finfo = numpy.finfo(numpy.float64)
    registradas = _registradas()
    huellas = {}
    for rel in ARCHIVOS_EVALUADOS:
        h = _sha256(RAIZ / rel)
        clave = clave_registro(rel)
        huellas[rel] = {"sha256": h, "igual_al_registro_6_10_2026": registradas.get(clave) == h
                        if clave in registradas else None}
    pruebas = {p.name: _sha256(p) for p in sorted((RAIZ / "pruebas" / "nucleo").glob("*.py"))}

    return {
        "fecha_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "hardware": {
            "arquitectura": platform.machine(),
            "procesador": modelo.group(1).strip() if modelo else platform.processor(),
            "cpu_logicas": os.cpu_count(),
            "memoria_GiB": round(int(memoria.group(1)) / 1024 / 1024, 2) if memoria else None,
            "extensiones_vectoriales": [f for f in ("sse4_2", "avx", "avx2", "avx512f", "fma")
                                        if banderas and f in banderas.group(1).split()],
            "orden_de_bytes": sys.byteorder,
        },
        "sistema_operativo": {"distribucion": so.group(1) if so else "", "plataforma": platform.platform(),
                              "nucleo": platform.release()},
        "interprete": {
            "implementacion": platform.python_implementation(),
            "version": platform.python_version(),
            "compilado_con": platform.python_compiler(),
            "fecha_compilacion": " ".join(platform.python_build()),
            "parametros_compilacion_OPT": sysconfig.get_config_var("OPT"),
            "banderas_en_ejecucion": {k: getattr(sys.flags, k) for k in
                                      ("optimize", "hash_randomization", "isolated", "no_user_site",
                                       "dont_write_bytecode", "utf8_mode", "safe_path")},
            "PYTHONHASHSEED": os.environ.get("PYTHONHASHSEED"),
        },
        "punto_flotante": {
            "formato": "IEEE 754 binary64 (doble precisión)",
            "bits_mantisa": sys.float_info.mant_dig, "digitos_decimales": sys.float_info.dig,
            "epsilon_maquina": sys.float_info.epsilon, "numpy_float64_eps": float(finfo.eps),
            "numpy_resolucion": float(finfo.resolution), "tipo_entero_numpy": str(numpy.dtype(int)),
        },
        "bibliotecas": {"numpy": numpy.__version__, "pygad": pygad.__version__, "pulp": pulp.__version__,
                        "cbc": cbc, "pytest": pytest.__version__},
        "variables_de_entorno": {v: os.environ.get(v) for v in VARIABLES},
        "carpeta_experimento": SANFELIPE_REL,
        "huellas_codigo_evaluado": huellas,
        "huellas_pruebas": pruebas,
    }


if __name__ == "__main__":
    datos = capturar()
    destino = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / "salidas" / "entorno.json"
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(datos, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps(datos, ensure_ascii=False, indent=2))
