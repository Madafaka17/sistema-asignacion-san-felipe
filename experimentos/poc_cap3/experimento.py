"""Ejecuta las pruebas de concepto según PROTOCOLO.md y calcula la matriz de decisión.

    python3 experimento.py ejecutar   # corre todas las pruebas -> resultados_crudos.csv
    python3 experimento.py analizar   # calcula C1..C5, puntajes 1-5 y totales
"""
from __future__ import annotations

import csv
import json
import math
import platform
import sys
import time
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
sys.path.insert(0, str(AQUI.parents[1]))

import numpy  # noqa: E402
import pulp  # noqa: E402
import pygad  # noqa: E402

from core.conflicts import build_conflict_pairs  # noqa: E402
from core.fitness import evaluate  # noqa: E402
from exhaustivo import optimo_exhaustivo  # noqa: E402
from generador import TURNO_MIN, construir_instancia  # noqa: E402
from metodos import resolver_ag, resolver_ple, resolver_tabu, resolver_voraz  # noqa: E402
from validador import contar_incumplimientos  # noqa: E402

TAMANOS = [7, 14, 28, 56, 112]
SEMILLAS_INSTANCIA = [101, 102, 103]
SEMILLAS_METODO = list(range(1, 11))
VARIANTE = sys.argv[2] if len(sys.argv) > 2 else "v1"
SUFIJO = "" if VARIANTE == "v1" else f"_{VARIANTE}"
CRUDOS = AQUI / f"resultados_crudos{SUFIJO}.csv"
OPTIMOS = AQUI / "optimos_n7.csv"
# v1: presupuesto fijo (PROTOCOLO, secciones 2-7). v2: análisis de sensibilidad con
# presupuesto máximo común de 300 s y criterio de parada propio de cada método (sección 9).
PARAM_AG = {"v1": {}, "v2": {"poblacion": 100, "generaciones": 200, "saturacion": 20, "t_limite": 300.0}}
PARAM_TABU = {"v1": {}, "v2": {"presupuesto": 20000, "sin_mejora": 2000}}
CAMPOS = ["metodo", "n", "instancia", "semilla", "tiempo_s", "F", "J", "phi", "validador",
          "exceso_min", "retraso", "reprog", "tiempo_muerto", "desequilibrio", "estado"]

PESOS = {"C1": 0.30, "C2": 0.20, "C3": 0.25, "C4": 0.15, "C5": 0.10}
# Términos de F(X) evaluados de forma exacta por el mecanismo de búsqueda (ver PROTOCOLO.md, C5):
# Sc, Cv, Cc, R, Tm, D
TERMINOS_EXACTOS = {"PLE": 4, "Voraz": 3, "Tabu": 6, "AG": 6}


def _fila(metodo, n, inst_seed, semilla, t, crom, inst, meta):
    servs = inst.services_with_options()
    pares = build_conflict_pairs(servs, min_transition=meta.t_min)
    if crom is None:
        return {"metodo": metodo, "n": n, "instancia": inst_seed, "semilla": semilla, "tiempo_s": t,
                "F": "", "J": "", "phi": n, "validador": n, "exceso_min": "", "retraso": "", "reprog": "",
                "tiempo_muerto": "", "desequilibrio": "", "estado": "sin_solucion"}
    b = evaluate(crom, inst, pares)
    val = contar_incumplimientos(crom, servs, inst, meta.t_min)
    return {"metodo": metodo, "n": n, "instancia": inst_seed, "semilla": semilla, "tiempo_s": round(t, 6),
            "F": b.fitness, "J": b.loss, "phi": b.conflict_violations + b.overlimit_drivers,
            "validador": val, "exceso_min": b.driving_time_excess, "retraso": b.delay,
            "reprog": b.reschedule, "tiempo_muerto": b.idle, "desequilibrio": b.workload_spread,
            "estado": "ok"}


def ejecutar():
    optimos_path = OPTIMOS if VARIANTE == "v1" else AQUI / f"optimos_n7{SUFIJO}.csv"
    with open(CRUDOS, "w", newline="", encoding="utf8") as fh, open(optimos_path, "w", newline="", encoding="utf8") as fo:
        w = csv.DictWriter(fh, fieldnames=CAMPOS)
        w.writeheader()
        wo = csv.writer(fo)
        wo.writerow(["n", "instancia", "F_optimo", "hojas_factibles"])
        for n in TAMANOS:
            for s_inst in SEMILLAS_INSTANCIA:
                inst, meta = construir_instancia(n, s_inst)
                if n == 7:
                    pares = build_conflict_pairs(inst.services_with_options(), min_transition=meta.t_min)
                    _, f_opt, hojas = optimo_exhaustivo(inst, pares, meta.t_min)
                    wo.writerow([n, s_inst, f_opt, hojas])
                    fo.flush()

                t0 = time.perf_counter()
                crom = resolver_voraz(inst, meta.t_min)
                w.writerow(_fila("Voraz", n, s_inst, 0, time.perf_counter() - t0, crom, inst, meta))

                t0 = time.perf_counter()
                pares = build_conflict_pairs(inst.services_with_options(), min_transition=meta.t_min)
                crom, estado = resolver_ple(inst, pares, TURNO_MIN)
                fila = _fila("PLE", n, s_inst, 0, time.perf_counter() - t0, crom, inst, meta)
                fila["estado"] = estado if crom is not None else "sin_solucion"
                w.writerow(fila)
                fh.flush()

                for sem in SEMILLAS_METODO:
                    t0 = time.perf_counter()
                    pares = build_conflict_pairs(inst.services_with_options(), min_transition=meta.t_min)
                    crom, _ = resolver_tabu(inst, pares, meta.t_min, sem, **PARAM_TABU[VARIANTE])
                    w.writerow(_fila("Tabu", n, s_inst, sem, time.perf_counter() - t0, crom, inst, meta))

                    t0 = time.perf_counter()
                    crom = resolver_ag(inst, meta.t_min, sem, **PARAM_AG[VARIANTE])
                    w.writerow(_fila("AG", n, s_inst, sem, time.perf_counter() - t0, crom, inst, meta))
                    fh.flush()
                print(f"listo n={n} instancia={s_inst}", flush=True)


def _puntaje(valor, cortes, mayor_es_mejor=False):
    """cortes: umbrales para 5,4,3,2 (en ese orden); lo demás vale 1."""
    for p, u in zip((5, 4, 3, 2), cortes):
        if (valor >= u) if mayor_es_mejor else (valor <= u):
            return p
    return 1


def analizar():
    filas = list(csv.DictReader(open(CRUDOS, encoding="utf8")))
    optimos = {(int(r["n"]), int(r["instancia"])): float(r["F_optimo"])
               for r in csv.DictReader(open(OPTIMOS, encoding="utf8"))}
    metodos = ["PLE", "Voraz", "Tabu", "AG"]

    # Mejor F conocido por instancia
    mejor = {}
    for r in filas:
        if r["F"] == "":
            continue
        k = (int(r["n"]), int(r["instancia"]))
        mejor[k] = max(mejor.get(k, float("-inf")), float(r["F"]))
    for k, f in optimos.items():
        if mejor.get(k, float("-inf")) > f + 1e-9:
            print("AVISO: un método superó el óptimo certificado en", k)
        mejor[k] = f  # en n = 7 la referencia es el óptimo certificado

    def brecha(r):
        if r["F"] == "":
            return 100.0
        k = (int(r["n"]), int(r["instancia"]))
        fb = mejor[k]
        g = (fb - float(r["F"])) / max(abs(fb), 1e-9) * 100.0
        return min(100.0, max(0.0, g))

    res = {}
    for m in metodos:
        fm = [r for r in filas if r["metodo"] == m]
        c1 = sum(brecha(r) for r in fm) / len(fm)
        t7 = [float(r["tiempo_s"]) for r in fm if int(r["n"]) == 7]
        c2 = sum(t7) / len(t7)
        c3 = sum(float(r["validador"]) for r in fm) / len(fm)
        tmed = {n: sum(float(r["tiempo_s"]) for r in fm if int(r["n"]) == n) /
                max(1, len([r for r in fm if int(r["n"]) == n])) for n in TAMANOS}
        r1, r2 = tmed[56] / tmed[28], tmed[112] / tmed[56]
        c4 = math.sqrt(r1 * r2)
        limite = any(float(r["tiempo_s"]) >= 299.0 or r["estado"] in ("sin_solucion", "Not Solved")
                     for r in fm)
        c5 = TERMINOS_EXACTOS[m]
        p = {
            "C1": _puntaje(c1, (1, 5, 10, 20)),
            "C2": _puntaje(c2, (3, 30, 150, 300)),
            "C3": _puntaje(c3, (0, 0.1, 0.5, 1)),
            "C4": 1 if limite else _puntaje(c4, (2.2, 3.0, 4.5, 8.5)),
            "C5": _puntaje(c5, (6, 5, 4, 3), mayor_es_mejor=True),
        }
        total = sum(PESOS[c] * p[c] for c in PESOS)
        brechas_por_n = {n: sum(brecha(r) for r in fm if int(r["n"]) == n) /
                         max(1, len([r for r in fm if int(r["n"]) == n])) for n in TAMANOS}
        viol_por_n = {n: sum(float(r["validador"]) for r in fm if int(r["n"]) == n) /
                      max(1, len([r for r in fm if int(r["n"]) == n])) for n in TAMANOS}
        res[m] = {"medido": {"C1_brecha_pct": c1, "C2_tiempo_s_n7": c2, "C3_incumplimientos": c3,
                             "C4_razon": c4, "C4_r1_56_28": r1, "C4_r2_112_56": r2, "C5_terminos": c5,
                             "limite_alcanzado": limite},
                  "puntaje": p, "total": round(total, 4),
                  "tiempo_medio_por_n": tmed, "brecha_por_n": brechas_por_n,
                  "incumplimientos_por_n": viol_por_n}

    discrepancias = sum(1 for r in filas if r["estado"] != "sin_solucion" and r["phi"] != r["validador"])
    entorno = {
        "python": platform.python_version(), "sistema": platform.platform(),
        "procesador": platform.processor() or "", "numpy": numpy.__version__,
        "pygad": pygad.__version__, "pulp": pulp.__version__,
    }
    salida = {"resultados": res, "discrepancias_validador": discrepancias, "entorno": entorno,
              "ejecuciones": len(filas)}
    json.dump(salida, open(AQUI / f"resumen{SUFIJO}.json", "w", encoding="utf8"), indent=2, ensure_ascii=False)
    for m in metodos:
        print(m, json.dumps(res[m]["medido"], ensure_ascii=False), res[m]["puntaje"], "TOTAL", res[m]["total"])
    print("discrepancias validador:", discrepancias, "| ejecuciones:", len(filas))


if __name__ == "__main__":
    {"ejecutar": ejecutar, "analizar": analizar}[sys.argv[1]]()
