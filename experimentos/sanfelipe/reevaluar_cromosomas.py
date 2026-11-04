"""Reevaluación de las soluciones registradas (material suplementario, 2026-10-17).

Agregado después del registro del protocolo (ver DESVIACIONES.md). No ejecuta
ningún candidato: reconstruye cada instancia con el generador registrado, toma el
cromosoma de cada ejecución en soluciones_<variante>.jsonl, lo vuelve a evaluar con
core.fitness y con el validador independiente, y compara el resultado con la fila
correspondiente de resultados_crudos_<variante>.csv: F, J, Φ, validador, exceso,
Ret, R, Tm, D y los indicadores operativos de la sección 7 del protocolo. En n = 7
vuelve a certificar el óptimo por enumeración exhaustiva y compara F y el número de
hojas factibles con optimos_n7_<variante>.csv.

    python3 reevaluar_cromosomas.py            # v1, v2, v1D y v2D
    python3 reevaluar_cromosomas.py v1         # una variante

Las variantes v1D y v2D se reevalúan con la definición de D de sensibilidad_D.py.
Sale con código 1 si alguna fila no coincide.

Usa core/ y experimentos/poc_cap3/ del repositorio, que desde el 2026-11-04 son los
archivos originales (huellas de registro_protocolo.txt): que todas las filas
coincidan acredita que las soluciones registradas son coherentes con sus resultados.
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
# Esta carpeta va primero: experimentos/poc_cap3/ tiene otro experimento.py (el de la
# prueba técnica inicial) y aquí se importa el de esta carpeta.
sys.path.insert(0, str(AQUI.parents[1]))
sys.path.insert(0, str(AQUI.parent / "poc_cap3"))
sys.path.insert(0, str(AQUI))

import experimento  # noqa: E402
import sensibilidad_D  # noqa: E402
from core import fitness  # noqa: E402
from core.conflicts import build_conflict_pairs  # noqa: E402
from exhaustivo import optimo_exhaustivo  # noqa: E402
from generador_sanfelipe import construir_instancia  # noqa: E402
from validador import contar_incumplimientos  # noqa: E402

VARIANTES = ["v1", "v2", "v1D", "v2D"]
NUMERICOS = ["F", "J", "phi", "validador", "exceso_min", "retraso", "reprog", "tiempo_muerto", "desequilibrio",
             "validas_pct", "reemplazos", "saltos_cola", "salidas_demoradas", "minutos_demora",
             "unidades_usadas", "conductores_usados"]
TOL_REL = 1e-9


def _coinciden(registrado: str, calculado) -> bool:
    if registrado == "":
        return calculado in ("", None)
    a, b = float(registrado), float(calculado)
    return abs(a - b) <= TOL_REL * max(1.0, abs(a))


def reevaluar(var: str) -> int:
    perdida_original = fitness._loss_components
    if var.endswith("D"):
        fitness._loss_components = sensibilidad_D._loss_components_todos
    try:
        instancias = {}

        def instancia(n, semilla):
            if (n, semilla) not in instancias:
                inst, meta = construir_instancia(n, semilla)
                servs = inst.services_with_options()
                instancias[(n, semilla)] = (inst, meta, servs,
                                            build_conflict_pairs(servs, min_transition=meta.t_min))
            return instancias[(n, semilla)]

        filas = list(csv.DictReader(open(AQUI / f"resultados_crudos_{var}.csv", encoding="utf8")))
        soluciones = [json.loads(linea) for linea in open(AQUI / f"soluciones_{var}.jsonl", encoding="utf8")]
        if len(filas) != len(soluciones):
            print(f"{var}: {len(filas)} filas y {len(soluciones)} soluciones")
            return 1
        distintas, sin_solucion = [], 0
        for fila, sol in zip(filas, soluciones):
            clave = (fila["metodo"], int(fila["n"]), int(fila["instancia"]), int(fila["semilla"]))
            if clave != (sol["metodo"], sol["n"], sol["instancia"], sol["semilla"]):
                print(f"{var}: la solución {sol} no corresponde a la fila {clave}")
                return 1
            if sol["cromosoma"] is None:
                sin_solucion += 1
                continue
            inst, meta, servs, pares = instancia(sol["n"], sol["instancia"])
            crom = sol["cromosoma"]
            b = fitness.evaluate(crom, inst, pares)
            calculado = {"F": b.fitness, "J": b.loss, "phi": b.feasibility_violations,
                         "validador": contar_incumplimientos(crom, servs, inst, meta.t_min),
                         "exceso_min": b.driving_time_excess, "retraso": b.delay, "reprog": b.reschedule,
                         "tiempo_muerto": b.idle, "desequilibrio": b.workload_spread}
            calculado.update(experimento.indicadores(crom, servs, inst, meta))
            campos = [c for c in NUMERICOS if not _coinciden(fila[c], calculado[c])]
            if campos:
                distintas.append((clave, {c: (fila[c], calculado[c]) for c in campos}))

        optimos_distintos = []
        for r in csv.DictReader(open(AQUI / f"optimos_n7_{var}.csv", encoding="utf8")):
            inst, meta, _, pares = instancia(int(r["n"]), int(r["instancia"]))
            _, f_opt, hojas = optimo_exhaustivo(inst, pares, meta.t_min)
            if not (_coinciden(r["F_optimo"], f_opt) and int(r["hojas_factibles"]) == hojas):
                optimos_distintos.append((r["instancia"], r["F_optimo"], f_opt, r["hojas_factibles"], hojas))
    finally:
        fitness._loss_components = perdida_original

    evaluadas = len(filas) - sin_solucion
    print(f"{var}: {evaluadas - len(distintas)} de {evaluadas} soluciones coinciden en los {len(NUMERICOS)} campos; "
          f"{3 - len(optimos_distintos)} de 3 óptimos de n = 7 coinciden (F y hojas factibles)")
    for clave, dif in distintas[:10]:
        print("   distinta:", clave, dif)
    for o in optimos_distintos:
        print("   óptimo distinto:", o)
    return int(bool(distintas or optimos_distintos))


if __name__ == "__main__":
    variantes = sys.argv[1:] or VARIANTES
    assert all(v in VARIANTES for v in variantes), f"variantes válidas: {VARIANTES}"
    sys.exit(max(reevaluar(v) for v in variantes))
