"""Repetición del experimento con la reimplementación de core/ y poc_cap3/
(2026-10-17).

Agregado después del registro del protocolo (ver DESVIACIONES.md). Ejecuta el mismo
experimento.py —mismas instancias, semillas, configuraciones, criterios, anclajes
y pesos—, pero escribe sus archivos en reimplementacion/ para no reemplazar nunca
los resultados registrados de esta carpeta (`experimento.py ejecutar` los
sobrescribiría).

    python3 repetir_reimplementacion.py ejecutar v1   # -> reimplementacion/resultados_crudos_v1.csv ...
    python3 repetir_reimplementacion.py analizar v1   # -> reimplementacion/resumen_v1.json
    python3 repetir_reimplementacion.py comparar      # registrado frente a la repetición

Variantes: v1, v2, v1D y v2D (estas dos con la D de sensibilidad_D.py).

Los resultados de esta carpeta se obtuvieron con los archivos originales de core/
y poc_cap3/, que no se conservan. La reimplementación evalúa F(X) y Φ igual que el
original (reevaluar_cromosomas.py) y reproduce el voraz, la enumeración exhaustiva
y, salvo empates entre óptimos alternativos, la PLE; la búsqueda tabú y el AG
consumen los números aleatorios de otra forma, de modo que sus ejecuciones no son
idénticas a las registradas. Por eso esta repetición se informa aparte y no
reemplaza a la ejecución oficial.
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))

import experimento  # noqa: E402
import sensibilidad_D  # noqa: E402
from core import fitness  # noqa: E402

DESTINO = AQUI / "reimplementacion"
VARIANTES = ["v1", "v2", "v1D", "v2D"]


def _archivos(var):
    return (DESTINO / f"resultados_crudos_{var}.csv", DESTINO / f"optimos_n7_{var}.csv",
            DESTINO / f"soluciones_{var}.jsonl", DESTINO / f"resumen_{var}.json")


def preparar(var):
    DESTINO.mkdir(exist_ok=True)
    experimento._archivos = _archivos
    if var.endswith("D"):
        base = var[:-1]
        fitness._loss_components = sensibilidad_D._loss_components_todos
        experimento.PARAM_AG[var] = experimento.PARAM_AG[base]
        experimento.PARAM_TABU[var] = experimento.PARAM_TABU[base]


def _resumen(ruta):
    return json.load(open(ruta, encoding="utf8"))


def comparar():
    """Totales, criterios y orden de cada variante; y, en los métodos deterministas,
    cuántas ejecuciones repiten la F registrada."""
    for var in VARIANTES:
        ruta = DESTINO / f"resumen_{var}.json"
        if not ruta.exists():
            print(f"{var}: sin repetición ({ruta.name} no existe)")
            continue
        reg, rep = _resumen(AQUI / f"resumen_{var}.json"), _resumen(ruta)
        print(f"\n{var}: orden registrado {reg['orden_por_total']} | repetición {rep['orden_por_total']}")
        encabezado = ("método", "total reg", "total rep", "C1 reg", "C1 rep", "C3 reg", "C3 rep")
        print("{:<6} {:>9} {:>9} {:>8} {:>8} {:>7} {:>7}".format(*encabezado))
        for m in experimento.METODOS:
            a, b = reg["resultados"][m], rep["resultados"][m]
            print(f"{m:<6} {a['total']:>9.2f} {b['total']:>9.2f} {a['medido']['C1_brecha_pct']:>8.2f} "
                  f"{b['medido']['C1_brecha_pct']:>8.2f} {a['medido']['C3_incumplimientos']:>7.3f} "
                  f"{b['medido']['C3_incumplimientos']:>7.3f}")
        filas_reg = list(csv.DictReader(open(AQUI / f"resultados_crudos_{var}.csv", encoding="utf8")))
        filas_rep = list(csv.DictReader(open(DESTINO / f"resultados_crudos_{var}.csv", encoding="utf8")))
        for m in ("Voraz", "PLE"):
            pares = [(x, y) for x, y in zip(filas_reg, filas_rep) if x["metodo"] == m]
            iguales = sum(1 for x, y in pares if x["F"] != "" and y["F"] != ""
                          and abs(float(x["F"]) - float(y["F"])) <= 1e-9 * max(1.0, abs(float(x["F"]))))
            print(f"{m}: {iguales} de {len(pares)} ejecuciones con la misma F que la registrada")


if __name__ == "__main__":
    accion = sys.argv[1]
    if accion == "comparar":
        comparar()
    else:
        variante = sys.argv[2] if len(sys.argv) > 2 else "v1"
        assert variante in VARIANTES, f"variantes válidas: {VARIANTES}"
        preparar(variante)
        {"ejecutar": experimento.ejecutar, "analizar": experimento.analizar}[accion](variante)
