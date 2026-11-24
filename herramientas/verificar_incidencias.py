"""Verificación de la prueba de reasignación ante incidencias (experimentos/incidencias).

    python herramientas/verificar_incidencias.py huellas
        Cada archivo de registro_protocolo.txt tiene la ÚLTIMA huella registrada para él
        (protocolo, scripts y módulos importados de core/, sanfelipe/ y poc_cap3/).

    python herramientas/verificar_incidencias.py comparar <registrado> <nuevo>
        Compara los resultados regenerados en <nuevo> con los registrados en <registrado>:
        escenarios y mínimos exactos byte a byte; resultados crudos campo por campo, salvo
        el tiempo de cómputo y F, que admite diferencias de redondeo (≤ 1e-12 relativo);
        resúmenes sin el entorno ni los tiempos.
"""
from __future__ import annotations

import csv
import hashlib
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
CARPETA = RAIZ / "experimentos" / "incidencias"


def huellas() -> bool:
    ultima: dict[str, str] = {}
    for linea in (CARPETA / "registro_protocolo.txt").read_text(encoding="utf8").splitlines():
        m = re.fullmatch(r"([0-9a-f]{64})  (\S+)", linea.strip())
        if m:
            ultima[m.group(2)] = m.group(1)
    mal = [r for r, h in ultima.items() if hashlib.sha256((RAIZ / r).read_bytes()).hexdigest() != h]
    for r in mal:
        print(f"HUELLA DISTINTA: {r}")
    print(f"{len(ultima) - len(mal)} de {len(ultima)} archivos con la última huella registrada")
    return not mal


def _filas(ruta: Path) -> list[dict[str, str]]:
    with open(ruta, encoding="utf8", newline="") as fh:
        return list(csv.DictReader(fh))


def _igual(campo: str, a: str, b: str) -> bool:
    if campo == "tiempo_s":
        return True
    if campo == "F" and a and b:
        return abs(float(a) - float(b)) <= 1e-12 * max(1.0, abs(float(a)))
    return a == b


def _sin_tiempos(o):
    if isinstance(o, dict):
        return {k: _sin_tiempos(v) for k, v in o.items() if k not in ("entorno", "tiempo_s_media", "tiempo_s_max")}
    return o


def comparar(registrado: Path, nuevo: Path) -> bool:
    ok = True
    for nombre in ("escenarios.csv", "escenarios_v2.csv", "minimos.csv", "minimos_v2.csv"):
        igual = (registrado / nombre).read_bytes() == (nuevo / nombre).read_bytes()
        print(f"{nombre}: {'idéntico' if igual else 'DISTINTO'}")
        ok &= igual
    for nombre in ("resultados_crudos.csv", "resultados_crudos_v2.csv"):
        a, b = _filas(registrado / nombre), _filas(nuevo / nombre)
        dif = [(i, k) for i, (x, y) in enumerate(zip(a, b)) for k in x if not _igual(k, x[k], y.get(k, ""))]
        redondeo = sum(1 for x, y in zip(a, b) if x["F"] != y["F"])
        bien = len(a) == len(b) and not dif
        print(f"{nombre}: {len(b)} filas; {'iguales' if bien else f'DISTINTAS {dif[:5]}'}"
              f" (F con diferencia de redondeo en {redondeo})")
        ok &= bien
    for nombre in ("resumen.json", "resumen_v2.json"):
        a = json.loads((registrado / nombre).read_text(encoding="utf8"))
        b = json.loads((nuevo / nombre).read_text(encoding="utf8"))
        igual = _sin_tiempos(a) == _sin_tiempos(b)
        print(f"{nombre} (sin entorno ni tiempos): {'idéntico' if igual else 'DISTINTO'}")
        ok &= igual
    print("Resultado:", "REPRODUCIDO" if ok else "NO REPRODUCIDO")
    return ok


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "huellas":
        sys.exit(0 if huellas() else 1)
    if len(sys.argv) == 4 and sys.argv[1] == "comparar":
        sys.exit(0 if comparar(Path(sys.argv[2]), Path(sys.argv[3])) else 1)
    sys.exit(__doc__)
