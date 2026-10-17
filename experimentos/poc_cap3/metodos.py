"""Los cuatro candidatos del capítulo III (secciones 3.1.4 a 3.1.7).

REIMPLEMENTACIÓN (2026-10-17); ver experimentos/poc_cap3/README.md.

Todos reciben la misma instancia y devuelven un cromosoma: un índice de
alternativa por servicio de S', en el orden de Instance.services_with_options().

    resolver_voraz(inst, t_min)                         -> cromosoma
    resolver_ple(inst, pares, H)                        -> (cromosoma | None, estado)
    resolver_tabu(inst, pares, t_min, semilla, ...)     -> (cromosoma, detalle)
    resolver_ag(inst, t_min, semilla, ...)              -> cromosoma
"""
from __future__ import annotations

import math
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import pulp  # noqa: E402

from core.conflicts import conflict_index  # noqa: E402
from core.fitness import evaluate  # noqa: E402
from core.repair import repair  # noqa: E402
from core.scheduler import GAConfig, run_ga  # noqa: E402

T_LIMITE = 300.0
_TOL = 1e-9


def _cruza(x, y, t_min):
    return x.start_time < y.start_time + y.duration + t_min and y.start_time < x.start_time + x.duration + t_min


# --- Algoritmo voraz (sección 3.1.5, ecuación 12) ---------------------------

def resolver_voraz(inst, t_min):
    """Primer ajuste: servicios por su hora de inicio más temprana (en empate, mayor
    prioridad) y, para cada uno, la primera alternativa en orden de hora de salida
    sin choques en la tabla de ocupación de su vehículo y de su conductor y dentro
    del límite de conducción. Si ninguna cumple, la de menos choques —cada
    intervalo ocupado del vehículo o del conductor que se cruza cuenta uno y
    exceder el límite cuenta uno más—, en empate la más temprana; ese servicio
    queda como incidencia."""
    servicios = inst.services_with_options()
    orden = sorted(range(len(servicios)),
                   key=lambda i: (min(a.start_time for a in servicios[i].admissible), -servicios[i].priority, i))
    ocupacion, carga = {}, {}
    crom = [0] * len(servicios)
    for i in orden:
        alternativas = servicios[i].admissible
        elegida, peor = None, {}
        for k in sorted(range(len(alternativas)), key=lambda k: (alternativas[k].start_time, k)):
            a = alternativas[k]
            choques = (sum(_cruza(a, y, t_min) for y in ocupacion.get(("V", a.vehicle_id), ()))
                       + sum(_cruza(a, y, t_min) for y in ocupacion.get(("C", a.driver_id), ())))
            excede = (inst.driving_time_prior.get(a.driver_id, 0.0) + carga.get(a.driver_id, 0.0) + a.duration
                      > inst.driving_time_limit.get(a.driver_id, math.inf) + _TOL)
            if not choques and not excede:
                elegida = k
                break
            peor[k] = (choques + excede, a.start_time, k)
        if elegida is None:
            elegida = min(peor, key=peor.get)
        crom[i] = elegida
        a = alternativas[elegida]
        ocupacion.setdefault(("V", a.vehicle_id), []).append(a)
        ocupacion.setdefault(("C", a.driver_id), []).append(a)
        carga[a.driver_id] = carga.get(a.driver_id, 0.0) + a.duration
    return crom


# --- Programación lineal entera (sección 3.1.4, ecuaciones 9 a 11) ----------

def resolver_ple(inst, pares, H, t_limite=T_LIMITE):
    """Minimiza Z (ec. 9) sujeto a (3), (5), (6), (10) y (11) con CBC (PuLP), un
    hilo y límite de tiempo. H es la constante de linealización (duración del
    turno). Devuelve el cromosoma y el estado de PuLP ("Optimal", "Not Solved"...)."""
    servicios = inst.services_with_options()
    w, b = inst.weights, inst.norm_refs
    prob = pulp.LpProblem("programacion", pulp.LpMinimize)
    x = {(i, k): pulp.LpVariable(f"x_{i}_{k}", cat="Binary")
         for i, s in enumerate(servicios) for k in range(len(s.admissible))}
    vehiculos = sorted({a.vehicle_id for s in servicios for a in s.admissible})
    conductores = sorted({a.driver_id for s in servicios for a in s.admissible})
    ini = {v: pulp.LpVariable(f"ini_{v}", 0, H) for v in vehiculos}
    fin = {v: pulp.LpVariable(f"fin_{v}", 0, H) for v in vehiculos}
    tm = {v: pulp.LpVariable(f"tm_{v}", 0) for v in vehiculos}
    lmax = pulp.LpVariable("lmax", 0)

    retraso, cambios = [], []
    for i, s in enumerate(servicios):
        if s.baseline_alt is None:
            continue
        t_base = s.admissible[s.baseline_alt].start_time
        for k, a in enumerate(s.admissible):
            delta = max(0.0, a.start_time - t_base)          # δ_{s,a}
            if delta:
                retraso.append(delta * x[i, k])
            if k != s.baseline_alt:
                cambios.append(x[i, k])
    prob += (w["delay"] / b["delay"] * pulp.lpSum(retraso) + w["reschedule"] / b["reschedule"] * pulp.lpSum(cambios)
             + w["idle"] / b["idle"] * pulp.lpSum(tm.values()) + w["workload"] / b["workload"] * lmax)

    # El orden de las restricciones solo decide cuál de los óptimos alternativos
    # devuelve CBC; este reproduce la F registrada de la PLE en las 15 instancias
    # (README.md).
    carga = {c: pulp.lpSum(a.duration * x[i, k] for i, s in enumerate(servicios)
                           for k, a in enumerate(s.admissible) if a.driver_id == c) for c in conductores}
    for i, s in enumerate(servicios):                                     # (3)
        prob += pulp.lpSum(x[i, k] for k in range(len(s.admissible))) == 1
    for v in vehiculos:                                                   # (10)
        usos = [(i, k, a) for i, s in enumerate(servicios) for k, a in enumerate(s.admissible) if a.vehicle_id == v]
        for i, k, a in usos:
            prob += ini[v] <= a.start_time + H * (1 - x[i, k])
            prob += fin[v] >= a.start_time + a.duration - H * (1 - x[i, k])
        prob += tm[v] >= fin[v] - ini[v] - pulp.lpSum(a.duration * x[i, k] for i, k, a in usos)
    for p, q in sorted(pares):                                            # (5)
        prob += x[p] + x[q] <= 1
    for c in conductores:                                                 # (11)
        prob += lmax >= carga[c]
    for c in conductores:                                                 # (6)
        prob += carga[c] <= inst.driving_time_limit[c] - inst.driving_time_prior.get(c, 0.0)

    prob.solve(pulp.PULP_CBC_CMD(msg=False, timeLimit=t_limite, threads=1))
    estado = pulp.LpStatus[prob.status]
    if any(x[i, k].value() is None for i, k in x):
        return None, estado
    crom = [max(range(len(s.admissible)), key=lambda k: x[i, k].value()) for i, s in enumerate(servicios)]
    return crom, estado


# --- Búsqueda tabú (sección 3.1.6, ecuaciones 13 y 14) ----------------------

def resolver_tabu(inst, pares, t_min, semilla, presupuesto=5050, sin_mejora=None,
                  vecinos=30, permanencia=7, t_limite=T_LIMITE):
    """Parte del voraz reparado; en cada iteración evalúa una muestra de `vecinos`
    movimientos de un servicio (ec. 13) y se mueve al mejor no tabú o al que mejore
    la mejor programación conocida (aspiración, ec. 14). El movimiento de regreso
    queda prohibido `permanencia` iteraciones. Se detiene al agotar `presupuesto`
    evaluaciones de F, tras `sin_mejora` evaluaciones sin mejorar (si se indica) o
    al alcanzar el límite de tiempo."""
    inicio = time.perf_counter()
    rng = random.Random(semilla)
    servicios = inst.services_with_options()
    indice = conflict_index(pares)
    movibles = [i for i, s in enumerate(servicios) if len(s.admissible) > 1]

    def aptitud(c):
        return evaluate(c, inst, pares, index=indice).fitness

    actual = repair(resolver_voraz(inst, t_min), inst, index=indice)
    f_actual = aptitud(actual)
    mejor, f_mejor = list(actual), f_actual
    evaluaciones, ultima_mejora, iteracion = 1, 1, 0
    expira = {}                                          # (servicio, alternativa) -> iteración en que deja de ser tabú
    while movibles and evaluaciones < presupuesto and time.perf_counter() - inicio < t_limite:
        if sin_mejora is not None and evaluaciones - ultima_mejora >= sin_mejora:
            break
        iteracion += 1
        candidato = None
        for _ in range(min(vecinos, presupuesto - evaluaciones)):
            i = rng.choice(movibles)
            k = rng.randrange(len(servicios[i].admissible) - 1)
            k += k >= actual[i]
            vecino = list(actual)
            vecino[i] = k
            f = aptitud(vecino)
            evaluaciones += 1
            tabu = expira.get((i, k), 0) > iteracion
            if (not tabu or f > f_mejor) and (candidato is None or f > candidato[0]):
                candidato = (f, i, k, vecino)
        if candidato is None:
            continue
        f, i, k, vecino = candidato
        expira[(i, actual[i])] = iteracion + permanencia
        actual, f_actual = vecino, f
        if f_actual > f_mejor:
            mejor, f_mejor, ultima_mejora = list(actual), f_actual, evaluaciones
    return mejor, {"F": f_mejor, "evaluaciones": evaluaciones, "iteraciones": iteracion,
                   "tiempo_s": time.perf_counter() - inicio}


# --- Algoritmo genético (secciones 3.1.7 y 3.4) -----------------------------

def resolver_ag(inst, t_min, semilla, poblacion=50, generaciones=100, saturacion=None, t_limite=T_LIMITE):
    """Núcleo core.scheduler con los parámetros de la Tabla 18 (v1) o de la Tabla 20 (v2)."""
    config = GAConfig(population_size=poblacion, generations=generaciones, stall_generations=saturacion,
                      time_limit=t_limite, seed=semilla)
    return run_ga(inst, t_min, config).chromosome
