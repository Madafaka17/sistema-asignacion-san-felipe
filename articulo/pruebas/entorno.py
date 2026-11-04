"""Declaración del entorno de ejecución de las pruebas del código del artículo.

Registra arquitectura de hardware, sistema operativo, intérprete y sus parámetros, punto flotante, bibliotecas,
variables de entorno que fijan el determinismo y las huellas SHA-256 del código evaluado, comparadas con el
SHA256SUMS del propio código. Uso:  python pruebas/entorno.py pruebas/salidas/entorno.json
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

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent
EVALUADOS = ["modelo.py", "reparacion.py", "genetico.py", "metodos.py", "validador.py", "generador_sintetico.py",
             "generador_gtfs.py", "experimento.py", "analisis.py", "datos/manifiestos_publicables.csv",
             "datos/gtfs/lodz.zip", "datos/gtfs/buzau.zip"]
VARIABLES = ["PYTHONHASHSEED", "PYTHONNOUSERSITE", "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS",
             "NUMEXPR_NUM_THREADS", "TZ", "LC_ALL", "LANG"]


def _leer(ruta):
    try:
        return Path(ruta).read_text(encoding="utf8", errors="replace")
    except OSError:
        return ""


def _sha256(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def _sumas() -> dict:
    texto = _leer(RAIZ / "SHA256SUMS")
    return {m.group(2).removeprefix("./"): m.group(1) for m in re.finditer(r"^([0-9a-f]{64})\s+\*?(\S+)$", texto, re.M)}


def capturar() -> dict:
    import matplotlib
    import networkx
    import numpy
    import pulp
    import pygad
    import pytest
    import scipy

    cpuinfo, meminfo = _leer("/proc/cpuinfo"), _leer("/proc/meminfo")
    modelo = re.search(r"model name\s*:\s*(.+)", cpuinfo)
    banderas = re.search(r"flags\s*:\s*(.+)", cpuinfo)
    memoria = re.search(r"MemTotal:\s*(\d+) kB", meminfo)
    so = re.search(r'PRETTY_NAME="([^"]+)"', _leer("/etc/os-release"))
    try:
        salida = subprocess.run([pulp.PULP_CBC_CMD().path, "-quit"], capture_output=True, text=True, timeout=20).stdout
        version = re.search(r"Version:\s*(\S+)", salida)
        cbc = version.group(1) if version else salida.strip().splitlines()[0]
    except Exception as exc:  # noqa: BLE001 - se informa, no se oculta
        cbc = f"no disponible ({exc})"
    sumas = _sumas()
    finfo = numpy.finfo(numpy.float64)
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
            "implementacion": platform.python_implementation(), "version": platform.python_version(),
            "compilado_con": platform.python_compiler(), "fecha_compilacion": " ".join(platform.python_build()),
            "parametros_compilacion_OPT": sysconfig.get_config_var("OPT"),
            "banderas_en_ejecucion": {k: getattr(sys.flags, k) for k in
                                      ("optimize", "hash_randomization", "isolated", "no_user_site",
                                       "dont_write_bytecode", "utf8_mode", "safe_path")},
            "PYTHONHASHSEED": os.environ.get("PYTHONHASHSEED"),
        },
        "punto_flotante": {"formato": "IEEE 754 binary64 (doble precisión)", "bits_mantisa": sys.float_info.mant_dig,
                           "digitos_decimales": sys.float_info.dig, "epsilon_maquina": sys.float_info.epsilon,
                           "numpy_resolucion": float(finfo.resolution), "tipo_entero_numpy": str(numpy.dtype(int))},
        "bibliotecas": {"numpy": numpy.__version__, "pygad": pygad.__version__, "pulp": pulp.__version__, "cbc": cbc,
                        "scipy": scipy.__version__, "networkx": networkx.__version__,
                        "matplotlib": matplotlib.__version__, "pytest": pytest.__version__},
        "variables_de_entorno": {v: os.environ.get(v) for v in VARIABLES},
        "huellas_codigo_evaluado": {rel: {"sha256": _sha256(RAIZ / rel),
                                          "igual_a_SHA256SUMS": sumas.get(rel) == _sha256(RAIZ / rel)
                                          if rel in sumas else None} for rel in EVALUADOS},
        "huellas_pruebas": {p.name: _sha256(p) for p in sorted(AQUI.glob("*.py"))},
    }


if __name__ == "__main__":
    datos = capturar()
    destino = Path(sys.argv[1]) if len(sys.argv) > 1 else AQUI / "salidas" / "entorno.json"
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(datos, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps(datos, ensure_ascii=False, indent=2))
