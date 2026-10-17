"""Experimento comparativo con datos sintéticos del caso San Felipe (PROTOCOLO.md).

    python3 experimento.py ejecutar v1   # 330 ejecuciones -> resultados_crudos_v1.csv
    python3 experimento.py analizar v1   # criterios C1-C5, puntajes 1-5, totales -> resumen_v1.json
    python3 experimento.py ejecutar v2   # análisis de sensibilidad (Tabla 20 del capítulo III)
    python3 experimento.py analizar v2   # -> resumen_v2.json

Los candidatos, el óptimo exhaustivo y el validador se importan sin cambios de
experimentos/poc_cap3 (los mismos del capítulo III); solo cambia el generador.
"""
from __future__ import annotations

import csv
import json
import math
import platform
import sys
import time
from collections import defaultdict
from itertools import combinations
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
sys.path.insert(0, str(AQUI.parent / "poc_cap3"))
sys.path.insert(0, str(AQUI.parents[1]))

import numpy  # noqa: E402
import pulp  # noqa: E402
import pygad  # noqa: E402

from core.conflicts import build_conflict_pairs  # noqa: E402
from core.fitness import evaluate  # noqa: E402
from exhaustivo import optimo_exhaustivo  # noqa: E402
from generador_sanfelipe import TURNO_MIN, construir_instancia  # noqa: E402
from metodos import resolver_ag, resolver_ple, resolver_tabu, resolver_voraz  # noqa: E402
from validador import contar_incumplimientos  # noqa: E402

TAMANOS = [7, 14, 28, 56, 112]
SEMILLAS_INSTANCIA = [101, 102, 103]
SEMILLAS_METODO = list(range(1, 11))
METODOS = ["PLE", "Voraz", "Tabu", "AG"]
# v1: configuración de la Tabla 18. v2: análisis de sensibilidad de la Tabla 20.
PARAM_AG = {"v1": {}, "v2": {"poblacion": 100, "generaciones": 200, "saturacion": 20, "t_limite": 300.0}}
PARAM_TABU = {"v1": {}, "v2": {"presupuesto": 20000, "sin_mejora": 2000}}
PESOS = {"C1": 0.30, "C2": 0.20, "C3": 0.25, "C4": 0.15, "C5": 0.10}
TERMINOS_EXACTOS = {"PLE": 4, "Voraz": 3, "Tabu": 6, "AG": 6}   # C5, igual que en el capítulo III
CAMPOS = ["metodo", "n", "instancia", "semilla", "tiempo_s", "F", "J", "phi", "validador",
          "exceso_min", "retraso", "reprog", "tiempo_muerto", "desequilibrio", "estado",
          "validas_pct", "reemplazos", "saltos_cola", "salidas_demoradas", "minutos_demora",
          "unidades_usadas", "conductores_usados"]


def _archivos(var):
    return (AQUI / f"resultados_crudos_{var}.csv", AQUI / f"optimos_n7_{var}.csv",
            AQUI / f"soluciones_{var}.jsonl", AQUI / f"resumen_{var}.json")


def indicadores(crom, servs, inst, meta):
    """Indicadores operativos complementarios (PROTOCOLO.md, sección 7)."""
    asig = [(s.service_id, s.admissible[g]) for s, g in zip(servs, crom)]
    por_recurso = defaultdict(list)
    for sid, a in asig:
        por_recurso[("V", a.vehicle_id)].append((sid, a))
        por_recurso[("C", a.driver_id)].append((sid, a))
    invalidos = set()
    for lista in por_recurso.values():
        for (s1, a1), (s2, a2) in combinations(lista, 2):
            if not (a1.start_time + a1.duration + meta.t_min <= a2.start_time
                    or a2.start_time + a2.duration + meta.t_min <= a1.start_time):
                invalidos.update((s1, s2))
    carga = defaultdict(float)
    for _, a in asig:
        carga[a.driver_id] += a.duration
    excedidos = {c for c, x in carga.items()
                 if inst.driving_time_prior.get(c, 0.0) + x > inst.driving_time_limit.get(c, math.inf) + 1e-9}
    invalidos.update(sid for sid, a in asig if a.driver_id in excedidos)
    reemplazos = sum(1 for _, a in asig
                     if a.vehicle_id in meta.conductor_fijo and a.driver_id != meta.conductor_fijo[a.vehicle_id])
    saltos = sum(1 for sid, a in asig if a.vehicle_id != meta.unidad_en_cola[sid])
    demoras = [a.start_time - meta.salida_nominal[sid] for sid, a in asig]
    return {
        "validas_pct": round(100.0 * (len(asig) - len(invalidos)) / len(asig), 4),
        "reemplazos": reemplazos,
        "saltos_cola": saltos,
        "salidas_demoradas": sum(1 for d in demoras if d > 0),
        "minutos_demora": round(sum(d for d in demoras if d > 0), 1),
        "unidades_usadas": len({a.vehicle_id for _, a in asig}),
        "conductores_usados": len({a.driver_id for _, a in asig}),
    }


def _fila(metodo, n, inst_seed, semilla, t, crom, inst, meta):
    servs = inst.services_with_options()
    pares = build_conflict_pairs(servs, min_transition=meta.t_min)
    if crom is None:
        fila = {k: "" for k in CAMPOS}
        fila.update({"metodo": metodo, "n": n, "instancia": inst_seed, "semilla": semilla,
                     "tiempo_s": t, "phi": n, "validador": n, "estado": "sin_solucion"})
        return fila
    b = evaluate(crom, inst, pares)
    val = contar_incumplimientos(crom, servs, inst, meta.t_min)
    fila = {"metodo": metodo, "n": n, "instancia": inst_seed, "semilla": semilla, "tiempo_s": round(t, 6),
            "F": b.fitness, "J": b.loss, "phi": b.conflict_violations + b.overlimit_drivers,
            "validador": val, "exceso_min": b.driving_time_excess, "retraso": b.delay,
            "reprog": b.reschedule, "tiempo_muerto": b.idle, "desequilibrio": b.workload_spread,
            "estado": "ok"}
    fila.update(indicadores(crom, servs, inst, meta))
    return fila


def ejecutar(var):
    crudos, optimos, soluciones, _ = _archivos(var)
    with open(crudos, "w", newline="", encoding="utf8") as fh, \
            open(optimos, "w", newline="", encoding="utf8") as fo, \
            open(soluciones, "w", encoding="utf8") as fs:
        w = csv.DictWriter(fh, fieldnames=CAMPOS)
        w.writeheader()
        wo = csv.writer(fo)
        wo.writerow(["n", "instancia", "F_optimo", "hojas_factibles"])

        def guardar(fila, crom):
            w.writerow(fila)
            fs.write(json.dumps({k: fila[k] for k in ("metodo", "n", "instancia", "semilla")}
                                | {"cromosoma": list(crom) if crom is not None else None}) + "\n")
            fh.flush()
            fs.flush()

        for n in TAMANOS:
            for s_inst in SEMILLAS_INSTANCIA:
                inst, meta = construir_instancia(n, s_inst)
                if n == 7:
                    pares = build_conflict_pairs(inst.services_with_options(), min_transition=meta.t_min)
                    c_opt, f_opt, hojas = optimo_exhaustivo(inst, pares, meta.t_min)
                    wo.writerow([n, s_inst, f_opt, hojas])
                    fo.flush()

                t0 = time.perf_counter()
                crom = resolver_voraz(inst, meta.t_min)
                guardar(_fila("Voraz", n, s_inst, 0, time.perf_counter() - t0, crom, inst, meta), crom)

                t0 = time.perf_counter()
                pares = build_conflict_pairs(inst.services_with_options(), min_transition=meta.t_min)
                crom, estado = resolver_ple(inst, pares, TURNO_MIN)
                fila = _fila("PLE", n, s_inst, 0, time.perf_counter() - t0, crom, inst, meta)
                fila["estado"] = estado if crom is not None else "sin_solucion"
                guardar(fila, crom)

                for sem in SEMILLAS_METODO:
                    t0 = time.perf_counter()
                    pares = build_conflict_pairs(inst.services_with_options(), min_transition=meta.t_min)
                    crom, _ = resolver_tabu(inst, pares, meta.t_min, sem, **PARAM_TABU[var])
                    guardar(_fila("Tabu", n, s_inst, sem, time.perf_counter() - t0, crom, inst, meta), crom)

                    t0 = time.perf_counter()
                    crom = resolver_ag(inst, meta.t_min, sem, **PARAM_AG[var])
                    guardar(_fila("AG", n, s_inst, sem, time.perf_counter() - t0, crom, inst, meta), crom)
                print(f"listo {var} n={n} instancia={s_inst}", flush=True)


def _puntaje(valor, cortes, mayor_es_mejor=False):
    """cortes: umbrales para 5, 4, 3 y 2 (en ese orden); lo demás vale 1."""
    for p, u in zip((5, 4, 3, 2), cortes):
        if (valor >= u) if mayor_es_mejor else (valor <= u):
            return p
    return 1


def _media(xs):
    xs = list(xs)
    return sum(xs) / len(xs) if xs else float("nan")


def analizar(var):
    crudos, optimos, _, resumen = _archivos(var)
    filas = list(csv.DictReader(open(crudos, encoding="utf8")))
    opt = {(int(r["n"]), int(r["instancia"])): float(r["F_optimo"])
           for r in csv.DictReader(open(optimos, encoding="utf8"))}

    mejor = {}
    for r in filas:
        if r["F"] == "":
            continue
        k = (int(r["n"]), int(r["instancia"]))
        mejor[k] = max(mejor.get(k, float("-inf")), float(r["F"]))
    avisos = []
    for k, f in opt.items():
        if mejor.get(k, float("-inf")) > f + 1e-9:
            avisos.append(f"un método superó el óptimo certificado en {k}")
        mejor[k] = f                                   # en n = 7 la referencia es el óptimo certificado

    def brecha(r):
        if r["F"] == "":
            return 100.0
        fb = mejor[(int(r["n"]), int(r["instancia"]))]
        return min(100.0, max(0.0, (fb - float(r["F"])) / max(abs(fb), 1e-9) * 100.0))

    res = {}
    for m in METODOS:
        fm = [r for r in filas if r["metodo"] == m]
        por_n = {n: [r for r in fm if int(r["n"]) == n] for n in TAMANOS}
        c1 = _media(brecha(r) for r in fm)
        c2 = _media(float(r["tiempo_s"]) for r in por_n[7])
        c3 = _media(float(r["validador"]) for r in fm)
        tmed = {n: _media(float(r["tiempo_s"]) for r in por_n[n]) for n in TAMANOS}
        r1, r2 = tmed[56] / tmed[28], tmed[112] / tmed[56]
        c4 = math.sqrt(r1 * r2)
        limite = any(float(r["tiempo_s"]) >= 299.0 or r["estado"] in ("sin_solucion", "Not Solved") for r in fm)
        c5 = TERMINOS_EXACTOS[m]
        p = {"C1": _puntaje(c1, (1, 5, 10, 20)),
             "C2": _puntaje(c2, (3, 30, 150, 300)),
             "C3": _puntaje(c3, (0, 0.1, 0.5, 1)),
             "C4": 1 if limite else _puntaje(c4, (2.2, 3.0, 4.5, 8.5)),
             "C5": _puntaje(c5, (6, 5, 4, 3), mayor_es_mejor=True)}
        total = sum(PESOS[c] * p[c] for c in PESOS)
        ok = [r for r in fm if r["estado"] != "sin_solucion"]
        ind = {}
        for n in TAMANOS:
            okn = [r for r in ok if int(r["n"]) == n]
            ind[n] = {k: _media(float(r[k]) for r in okn) for k in
                      ("validas_pct", "reemplazos", "saltos_cola", "salidas_demoradas", "minutos_demora",
                       "reprog", "retraso", "tiempo_muerto", "desequilibrio", "unidades_usadas",
                       "conductores_usados")}
            ind[n]["factibles_pct"] = 100.0 * sum(1 for r in okn if float(r["validador"]) == 0) / max(1, len(por_n[n]))
        res[m] = {"medido": {"C1_brecha_pct": c1, "C2_tiempo_s_n7": c2, "C3_incumplimientos": c3,
                             "C4_razon": c4, "C4_r1_56_28": r1, "C4_r2_112_56": r2, "C5_terminos": c5,
                             "limite_alcanzado": limite, "tiempo_max_s": max(float(r["tiempo_s"]) for r in fm)},
                  "puntaje": p, "total": round(total, 4),
                  "tiempo_medio_por_n": tmed,
                  "brecha_por_n": {n: _media(brecha(r) for r in por_n[n]) for n in TAMANOS},
                  "incumplimientos_por_n": {n: _media(float(r["validador"]) for r in por_n[n]) for n in TAMANOS},
                  "indicadores_por_n": ind}

    orden = sorted(METODOS, key=lambda m: (-res[m]["total"], res[m]["medido"]["C1_brecha_pct"],
                                           res[m]["medido"]["C3_incumplimientos"]))
    discrepancias = sum(1 for r in filas if r["estado"] != "sin_solucion" and r["phi"] != r["validador"])
    entorno = {"python": platform.python_version(), "sistema": platform.platform(),
               "procesador": platform.processor() or "", "numpy": numpy.__version__,
               "pygad": pygad.__version__, "pulp": pulp.__version__}
    salida = {"variante": var, "resultados": res, "orden_por_total": orden,
              "discrepancias_validador": discrepancias, "avisos": avisos,
              "optimos_n7": {f"{k[0]}-{k[1]}": v for k, v in opt.items()},
              "entorno": entorno, "ejecuciones": len(filas)}
    json.dump(salida, open(resumen, "w", encoding="utf8"), indent=2, ensure_ascii=False)
    for m in METODOS:
        print(m, json.dumps(res[m]["medido"], ensure_ascii=False), res[m]["puntaje"], "TOTAL", res[m]["total"])
    print("orden:", orden, "| discrepancias validador:", discrepancias, "| ejecuciones:", len(filas), avisos)


if __name__ == "__main__":
    accion = sys.argv[1]
    variante = sys.argv[2] if len(sys.argv) > 2 else "v1"
    assert variante in ("v1", "v2")
    {"ejecutar": ejecutar, "analizar": analizar}[accion](variante)
