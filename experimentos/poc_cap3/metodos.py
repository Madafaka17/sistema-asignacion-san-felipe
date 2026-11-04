"""Los cuatro candidatos de la sección 3.1, implementados para las pruebas de
concepto sobre las mismas estructuras de datos del prototipo (core/).

Todos devuelven un cromosoma: una tupla con el índice de la alternativa
admisible elegida para cada servicio de instance.services_with_options().
"""
from __future__ import annotations

import random
import sys
import time
from collections import defaultdict
from pathlib import Path

import pulp

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from core.fitness import evaluate  # noqa: E402
from core.repair import build_conflict_index, repair_targeted  # noqa: E402
from core.scheduler import GAConfig, run  # noqa: E402

T_LIMITE = 300.0


# --------------------------------------------------------------------------
# Programación lineal entera (PuLP + CBC)
# --------------------------------------------------------------------------
def resolver_ple(instancia, pares, horizonte: float, t_limite: float = T_LIMITE):
    servicios = instancia.services_with_options()
    w, b = instancia.weights, instancia.norm_refs
    prob = pulp.LpProblem("asignacion_recursos", pulp.LpMinimize)

    x = {}
    for si, s in enumerate(servicios):
        for ai in range(len(s.admissible)):
            x[(s.service_id, ai)] = pulp.LpVariable(f"x_{si}_{ai}", cat="Binary")

    # (2) cada servicio se asigna exactamente una vez
    for s in servicios:
        prob += pulp.lpSum(x[(s.service_id, ai)] for ai in range(len(s.admissible))) == 1

    # (3) pares en conflicto (vehículo o conductor, incluida la holgura t_min)
    for (s1, a1), (s2, a2) in pares:
        prob += x[(s1, a1)] + x[(s2, a2)] <= 1

    # (5) horas de conducción acumuladas por conductor
    por_conductor = defaultdict(list)
    por_vehiculo = defaultdict(list)
    for s in servicios:
        for ai, a in enumerate(s.admissible):
            por_conductor[a.driver_id].append((x[(s.service_id, ai)], a))
            por_vehiculo[a.vehicle_id].append((x[(s.service_id, ai)], a))
    carga = {}
    for c, lista in por_conductor.items():
        carga[c] = pulp.lpSum(a.duration * var for var, a in lista)
        prob += instancia.driving_time_prior.get(c, 0.0) + carga[c] <= instancia.driving_time_limit.get(c, 1e9)

    # Términos de J
    retraso = []
    reprog = []
    for s in servicios:
        if s.baseline_alt is not None:
            base = s.admissible[s.baseline_alt]
            for ai, a in enumerate(s.admissible):
                d = max(0.0, a.start_time - base.start_time)
                if d > 0:
                    retraso.append(d * x[(s.service_id, ai)])
                if ai != s.baseline_alt:
                    reprog.append(x[(s.service_id, ai)])

    # Tiempo muerto linealizado: inactivo_v >= fin_v - inicio_v - ocupado_v
    inactivo = []
    for v, lista in por_vehiculo.items():
        ini = pulp.LpVariable(f"ini_{v}", 0, horizonte)
        fin = pulp.LpVariable(f"fin_{v}", 0, horizonte)
        idle = pulp.LpVariable(f"idle_{v}", 0)
        ocupado = pulp.lpSum(a.duration * var for var, a in lista)
        for var, a in lista:
            prob += ini <= a.start_time + horizonte * (1 - var)
            prob += fin >= a.start_time + a.duration - horizonte * (1 - var)
        prob += idle >= fin - ini - ocupado
        inactivo.append(idle)

    # Desequilibrio: la desviación estándar no es lineal; se aproxima con la carga máxima
    cmax = pulp.LpVariable("carga_max", 0)
    for c in carga:
        prob += cmax >= carga[c]

    prob += (w["delay"] * pulp.lpSum(retraso) / b["delay"]
             + w["reschedule"] * pulp.lpSum(reprog) / b["reschedule"]
             + w["idle"] * pulp.lpSum(inactivo) / b["idle"]
             + w["workload"] * cmax / b["workload"])

    solver = pulp.PULP_CBC_CMD(msg=False, timeLimit=t_limite, threads=1)
    prob.solve(solver)
    estado = pulp.LpStatus[prob.status]
    try:
        crom = []
        for s in servicios:
            vals = [x[(s.service_id, ai)].value() or 0.0 for ai in range(len(s.admissible))]
            crom.append(max(range(len(vals)), key=lambda i: vals[i]))
        if any(all((x[(s.service_id, ai)].value() or 0.0) < 0.5 for ai in range(len(s.admissible))) for s in servicios):
            return None, estado
        return tuple(crom), estado
    except Exception:
        return None, estado


# --------------------------------------------------------------------------
# Algoritmo voraz: primer ajuste en orden de hora de inicio
# --------------------------------------------------------------------------
def _cabe(a, ocup_v, ocup_c, carga, instancia, t_min):
    for (ini, fin) in ocup_v[a.vehicle_id] + ocup_c[a.driver_id]:
        if not (a.start_time + a.duration + t_min <= ini or fin + t_min <= a.start_time):
            return False
    lim = instancia.driving_time_limit.get(a.driver_id, float("inf"))
    previo = instancia.driving_time_prior.get(a.driver_id, 0.0)
    return previo + carga[a.driver_id] + a.duration <= lim


def _choques(a, ocup_v, ocup_c, carga, instancia, t_min):
    n = 0
    for (ini, fin) in ocup_v[a.vehicle_id] + ocup_c[a.driver_id]:
        if not (a.start_time + a.duration + t_min <= ini or fin + t_min <= a.start_time):
            n += 1
    lim = instancia.driving_time_limit.get(a.driver_id, float("inf"))
    previo = instancia.driving_time_prior.get(a.driver_id, 0.0)
    if previo + carga[a.driver_id] + a.duration > lim:
        n += 1
    return n


def resolver_voraz(instancia, t_min: float):
    servicios = instancia.services_with_options()
    orden = sorted(range(len(servicios)),
                   key=lambda i: (min(a.start_time for a in servicios[i].admissible), -servicios[i].priority))
    ocup_v, ocup_c = defaultdict(list), defaultdict(list)
    carga = defaultdict(float)
    crom = [0] * len(servicios)
    for i in orden:
        s = servicios[i]
        opciones = sorted(range(len(s.admissible)), key=lambda j: (s.admissible[j].start_time, j))
        elegido = next((j for j in opciones
                        if _cabe(s.admissible[j], ocup_v, ocup_c, carga, instancia, t_min)), None)
        if elegido is None:  # sin opción factible: la de menor número de choques
            elegido = min(opciones, key=lambda j: _choques(s.admissible[j], ocup_v, ocup_c, carga, instancia, t_min))
        a = s.admissible[elegido]
        crom[i] = elegido
        ocup_v[a.vehicle_id].append((a.start_time, a.start_time + a.duration))
        ocup_c[a.driver_id].append((a.start_time, a.start_time + a.duration))
        carga[a.driver_id] += a.duration
    return tuple(crom)


# --------------------------------------------------------------------------
# Búsqueda tabú
# --------------------------------------------------------------------------
def resolver_tabu(instancia, pares, t_min: float, semilla: int, presupuesto: int = 5050,
                  muestra: int = 30, permanencia: int = 7, t_limite: float = T_LIMITE,
                  sin_mejora: int | None = None):
    rng = random.Random(semilla)
    servicios = instancia.services_with_options()
    t0 = time.perf_counter()

    def aptitud(c):
        return evaluate(tuple(c), instancia, pares).fitness

    # Solución inicial factible (sección de búsqueda tabú): voraz + reparación dirigida
    indice = build_conflict_index(servicios, pares)
    actual = list(repair_targeted(resolver_voraz(instancia, t_min), servicios, indice,
                                  instancia.driving_time_prior, instancia.driving_time_limit))
    f_actual = aptitud(actual)
    evals = 1
    mejor, f_mejor = actual[:], f_actual
    tabu = {}
    movimientos = [(g, v) for g, s in enumerate(servicios) for v in range(len(s.admissible))]
    it = 0
    ultima_mejora = evals
    while evals < presupuesto and time.perf_counter() - t0 < t_limite:
        if sin_mejora is not None and evals - ultima_mejora >= sin_mejora:
            break
        it += 1
        validos = [(g, v) for (g, v) in movimientos if v != actual[g]]
        if not validos:
            break
        candidatos = validos if len(validos) <= muestra else rng.sample(validos, muestra)
        mov, f_mov = None, float("-inf")
        for g, v in candidatos:
            viejo = actual[g]
            actual[g] = v
            f = aptitud(actual)
            evals += 1
            actual[g] = viejo
            es_tabu = tabu.get((g, v), 0) > it
            if (not es_tabu or f > f_mejor) and f > f_mov:  # aspiración
                mov, f_mov = (g, v), f
            if evals >= presupuesto:
                break
        if mov is None:
            continue
        g, v = mov
        tabu[(g, actual[g])] = it + permanencia
        actual[g] = v
        f_actual = f_mov
        if f_actual > f_mejor:
            mejor, f_mejor = actual[:], f_actual
            ultima_mejora = evals
    return tuple(mejor), evals


# --------------------------------------------------------------------------
# Algoritmo genético: núcleo del prototipo
# --------------------------------------------------------------------------
def resolver_ag(instancia, t_min: float, semilla: int, poblacion: int = 50, generaciones: int = 100,
                saturacion: int | None = None, t_limite: float | None = None):
    cfg = GAConfig(population_size=poblacion, num_generations=generaciones, crossover_probability=0.80,
                   mutation_probability=0.10, tournament_size=3, elitism_fraction=0.10,
                   min_transition=t_min, random_seed=semilla,
                   mutation_scope="chromosome", repair_mode="targeted", repair_initial=True,
                   stop_saturation=saturacion, time_limit=t_limite)
    res = run(instancia, cfg)
    return res.chromosome
