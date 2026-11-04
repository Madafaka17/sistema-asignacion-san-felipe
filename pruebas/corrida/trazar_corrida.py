"""Traza paso a paso una ejecución del AG del núcleo (configuración oficial v1) sobre una instancia oficial.

Reproduce exactamente core.scheduler.run: copia la lógica de _make_operators con el mismo orden de consumo de
números aleatorios, registra los resultados intermedios y al final comprueba que el cromosoma y el historial
coinciden con los de core.scheduler.run y con el registro oficial (resultados_crudos_v1.csv).
Uso: python -I trazar_corrida.py RUTA_REPO n semilla_instancia semilla_ag salida.json
"""
from __future__ import annotations

import csv
import json
import random
import sys
import time
from collections import defaultdict
from pathlib import Path

REPO = Path(sys.argv[1]).resolve()
N, S_INST, S_AG, SALIDA = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), Path(sys.argv[5])
for p in (REPO, REPO / "experimentos" / "poc_cap3", REPO / "experimentos" / "sanfelipe"):
    sys.path.insert(0, str(p))

import numpy as np  # noqa: E402
import pygad  # noqa: E402

from core.conflicts import build_conflict_pairs, build_driving_time_index  # noqa: E402
from core.fitness import evaluate  # noqa: E402
from core.repair import build_conflict_index, repair_targeted  # noqa: E402
from core.scheduler import GAConfig, run  # noqa: E402
from generador_sanfelipe import TURNO_MIN, construir_instancia, hhmm  # noqa: E402
from metodos import resolver_ple, resolver_tabu, resolver_voraz  # noqa: E402
from validador import contar_incumplimientos  # noqa: E402

inst, meta = construir_instancia(N, S_INST)
servs = inst.services_with_options()
T_MIN = meta.t_min
cfg = GAConfig(population_size=50, num_generations=100, crossover_probability=0.80, mutation_probability=0.10,
               tournament_size=3, elitism_fraction=0.10, min_transition=T_MIN, random_seed=S_AG,
               mutation_scope="chromosome", repair_mode="targeted", repair_initial=True)

pares = build_conflict_pairs(servs, min_transition=T_MIN)
indice_conflictos = build_conflict_index(servs, pares)
indice_horas = build_driving_time_index(servs)


def violaciones(c):
    sel = {s.service_id: int(g) for s, g in zip(servs, c)}
    choques = [[a, b] for a, b in pares if sel[a[0]] == a[1] and sel[b[0]] == b[1]]
    carga_c = defaultdict(float)
    for s, g in zip(servs, c):
        carga_c[s.admissible[int(g)].driver_id] += s.admissible[int(g)].duration
    exceso = {k: v - inst.driving_time_limit[k] for k, v in carga_c.items() if v > inst.driving_time_limit[k] + 1e-9}
    return {"choques": choques, "exceso": exceso, "carga": dict(carga_c)}


def desglose(c):
    b = evaluate(tuple(int(g) for g in c), inst, pares, big_m=cfg.big_m)
    return {"F": b.fitness, "J": b.loss, "phi": b.feasibility_violations, "V": b.conflict_violations,
            "excedidos": b.overlimit_drivers, "E": b.driving_time_excess, "retraso": b.delay,
            "reprog": b.reschedule, "muerto": b.idle, "D": b.workload_spread}


def fix(genes):
    return repair_targeted(tuple(int(g) for g in genes), servs, indice_conflictos, inst.driving_time_prior,
                           inst.driving_time_limit)


# ---------------------------------------------------------------- operadores (copia fiel de _make_operators)
rng = random.Random(cfg.random_seed)
mutables = [g for g, s in enumerate(servs) if len(s.admissible) > 1]
generacion = {"g": 0}
TRAZA_GEN = {1}                         # generaciones con detalle completo
traza_cruce, traza_mut = defaultdict(list), defaultdict(list)


def cruce(parents, offspring_size, ga):
    g_act = generacion["g"] + 1
    hijos = np.empty(offspring_size, dtype=int)
    n_p = parents.shape[0]
    for i in range(offspring_size[0]):
        p1, p2 = parents[i % n_p], parents[(i + 1) % n_p]
        cruza = not (cfg.crossover_probability < 1.0 and rng.random() >= cfg.crossover_probability)
        if not cruza:
            hijo, mascara = [int(x) for x in p1], None
        else:
            mascara = rng.getrandbits(offspring_size[1])
            hijo = [int(p1[g]) if (mascara >> g) & 1 else int(p2[g]) for g in range(offspring_size[1])]
        reparado = list(fix(hijo))
        if g_act in TRAZA_GEN:
            traza_cruce[g_act].append({"i": i, "p1": [int(x) for x in p1], "p2": [int(x) for x in p2],
                                       "cruza": cruza,
                                       "mascara": None if mascara is None else
                                       "".join("1" if (mascara >> g) & 1 else "2" for g in range(offspring_size[1])),
                                       "hijo": hijo, "reparado": reparado,
                                       "phi_hijo": desglose(hijo)["phi"], "phi_reparado": desglose(reparado)["phi"],
                                       "viol_hijo": violaciones(hijo), "F_reparado": desglose(reparado)["F"]})
        hijos[i] = np.array(reparado, dtype=int)
    return hijos


def mutacion(offspring, ga):
    g_act = generacion["g"] + 1
    for i in range(offspring.shape[0]):
        genes = [int(x) for x in offspring[i]]
        antes = list(genes)
        evento = None
        if mutables and rng.random() < ga.mutation_probability:
            g = rng.choice(mutables)
            otros = [j for j in range(len(servs[g].admissible)) if j != genes[g]]
            nuevo = rng.choice(otros)
            evento = {"gen": g, "de": genes[g], "a": nuevo}
            genes[g] = nuevo
        reparado = list(fix(genes))
        if g_act in TRAZA_GEN and evento is not None:
            mutado = list(antes)
            mutado[evento["gen"]] = evento["a"]
            traza_mut[g_act].append({"i": i, "antes": antes, "evento": evento, "mutado": mutado,
                                     "reparado": reparado, "phi_mutado": desglose(mutado)["phi"], "viol_mutado": violaciones(mutado),
                                     "F_reparado": desglose(reparado)["F"]})
        offspring[i] = np.array(reparado, dtype=int)
    return offspring


# ---------------------------------------------------------------- población inicial reparada
init_rng = random.Random(cfg.random_seed + 7919)
crudos, poblacion0 = [], []
for _ in range(cfg.population_size):
    c = [init_rng.randrange(len(s.admissible)) for s in servs]
    crudos.append(c)
    poblacion0.append(list(fix(c)))

gene_space = [{"low": 0, "high": len(s.admissible)} for s in servs]
historial, padres = [], {}
t0 = time.perf_counter()


def aptitud(ga, sol, idx):
    return evaluate(tuple(int(g) for g in sol), inst, pares, big_m=cfg.big_m).fitness


def on_parents(ga, seleccion):
    g_act = generacion["g"] + 1
    if g_act in TRAZA_GEN:
        padres[g_act] = {"indices": [int(x) for x in ga.last_generation_parents_indices],
                         "padres": [[int(x) for x in fila] for fila in seleccion]}


def estadisticas(pob, g):
    fits = [desglose(c)["F"] for c in pob]
    fac = [f for f in fits if f > -cfg.big_m / 2]
    return {"g": g, "mejor": max(fits), "media": sum(fits) / len(fits),
            "media_factibles": sum(fac) / len(fac) if fac else None, "peor_factible": min(fac) if fac else None,
            "factibles": len(fac), "distintos": len(set(tuple(c) for c in pob)),
            "composicion": sorted([[list(c), sum(1 for x in pob if tuple(x) == tuple(c))]
                                   for c in set(tuple(c) for c in pob)], key=lambda z: -z[1])}


def on_generation(ga):
    generacion["g"] += 1
    historial.append(float(ga.best_solution()[1]))
    por_gen.append(estadisticas([[int(x) for x in fila] for fila in ga.population], generacion["g"]))
    return None


por_gen = [estadisticas(poblacion0, 0)]
poblacion_gen1 = {}


def on_start(ga):
    fits = [aptitud(ga, s, i) for i, s in enumerate(ga.population)]
    poblacion_gen1["fit0"] = fits


ga = pygad.GA(num_generations=cfg.num_generations, num_parents_mating=max(2, cfg.population_size // 2),
              fitness_func=aptitud, sol_per_pop=cfg.population_size, num_genes=len(servs),
              initial_population=poblacion0, gene_type=int, gene_space=gene_space,
              parent_selection_type="tournament", K_tournament=cfg.tournament_size,
              keep_elitism=max(1, round(cfg.elitism_fraction * cfg.population_size)),
              crossover_type=cruce, mutation_type=mutacion, mutation_probability=cfg.mutation_probability,
              on_start=on_start, on_parents=on_parents, on_generation=on_generation,
              random_seed=cfg.random_seed, suppress_warnings=True, stop_criteria=None)
ga.run()
t_total = time.perf_counter() - t0
mejor_sol, mejor_fit, _ = ga.best_solution()
mejor = [int(x) for x in mejor_sol]

# ---------------------------------------------------------------- comprobaciones de identidad
ref = run(inst, cfg)
assert tuple(mejor) == ref.chromosome, (mejor, ref.chromosome)
assert tuple(historial) == ref.best_fitness_by_generation
registro = REPO / "experimentos" / "sanfelipe" / "resultados_crudos_v1.csv"
fila_reg = next(r for r in csv.DictReader(open(registro, encoding="utf8"))
                if r["metodo"] == "AG" and int(r["n"]) == N and int(r["instancia"]) == S_INST
                and int(r["semilla"]) == S_AG)
assert abs(float(fila_reg["F"]) - ref.breakdown.fitness) <= 1e-9

# ---------------------------------------------------------------- líneas base y óptimo por enumeración
voraz = list(resolver_voraz(inst, T_MIN))
c_ple, est_ple = resolver_ple(inst, pares, TURNO_MIN)
c_tabu, _ = resolver_tabu(inst, pares, T_MIN, S_AG)
hojas = []
ocup_v, ocup_c, carga = defaultdict(list), defaultdict(list), defaultdict(float)
crom = [0] * len(servs)


def libre(a):
    for (ini, fin) in ocup_v[a.vehicle_id] + ocup_c[a.driver_id]:
        if not (a.start_time + a.duration + T_MIN <= ini or fin + T_MIN <= a.start_time):
            return False
    lim = inst.driving_time_limit.get(a.driver_id, float("inf"))
    return inst.driving_time_prior.get(a.driver_id, 0.0) + carga[a.driver_id] + a.duration <= lim


def rec(i):
    if i == len(servs):
        hojas.append((list(crom), desglose(crom)))
        return
    for j, a in enumerate(servs[i].admissible):
        if libre(a):
            crom[i] = j
            ocup_v[a.vehicle_id].append((a.start_time, a.start_time + a.duration))
            ocup_c[a.driver_id].append((a.start_time, a.start_time + a.duration))
            carga[a.driver_id] += a.duration
            rec(i + 1)
            carga[a.driver_id] -= a.duration
            ocup_c[a.driver_id].pop()
            ocup_v[a.vehicle_id].pop()


rec(0)
hojas.sort(key=lambda h: -h[1]["F"])
total_combinaciones = 1
for s in servs:
    total_combinaciones *= len(s.admissible)

# ---------------------------------------------------------------- salida
salida = {
    "n": N, "instancia": S_INST, "semilla_ag": S_AG, "t_min": T_MIN, "turno_min": TURNO_MIN,
    "config": {"poblacion": 50, "generaciones": 100, "pc": 0.80, "pm": 0.10, "torneo": 3, "elitismo": 5,
               "padres": 25, "M": cfg.big_m, "semilla_inicial": S_AG + 7919},
    "pesos": inst.weights, "referencias": inst.norm_refs,
    "unidades": list(meta.unidades), "conductores": list(meta.conductores),
    "conductor_fijo": meta.conductor_fijo, "autorizados": {k: list(v) for k, v in meta.autorizados.items()},
    "limite": inst.driving_time_limit, "previo": inst.driving_time_prior,
    "servicios": [{"id": s.service_id, "ruta": meta.ruta[s.service_id], "nominal": meta.salida_nominal[s.service_id],
                   "nominal_hhmm": hhmm(meta.salida_nominal[s.service_id]), "cola": meta.unidad_en_cola[s.service_id],
                   "prioridad": s.priority, "comprometida": s.baseline_alt,
                   "oculta": meta.opcion_oculta[k],
                   "alternativas": [{"k": j, "unidad": a.vehicle_id, "conductor": a.driver_id, "h": a.departure_alt_id,
                                     "inicio": a.start_time, "inicio_hhmm": hhmm(a.start_time),
                                     "fin_hhmm": hhmm(a.start_time + a.duration), "duracion": a.duration}
                                    for j, a in enumerate(s.admissible)]}
                  for k, s in enumerate(servs)],
    "pares": [[list(a), list(b)] for a, b in pares],
    "indice_horas": {c: [[sid, k, d] for sid, k, d in v] for c, v in indice_horas.items()},
    "poblacion_inicial": [{"crudo": c, "reparado": r, "phi_crudo": desglose(c)["phi"], "F": desglose(r)["F"]}
                          for c, r in zip(crudos, poblacion0)],
    "fit_inicial": poblacion_gen1["fit0"],
    "violaciones_crudos": [violaciones(c) for c in crudos],
    "padres_g1": padres.get(1), "cruce_g1": traza_cruce.get(1, []), "mutacion_g1": traza_mut.get(1, []),
    "por_generacion": por_gen, "historial": historial,
    "mejor": mejor, "desglose_mejor": desglose(mejor),
    "asignacion": [{"servicio": s.service_id, "k": g, "unidad": s.admissible[g].vehicle_id,
                    "conductor": s.admissible[g].driver_id, "inicio_hhmm": hhmm(s.admissible[g].start_time),
                    "fin_hhmm": hhmm(s.admissible[g].start_time + s.admissible[g].duration),
                    "inicio": s.admissible[g].start_time, "duracion": s.admissible[g].duration}
                   for s, g in zip(servs, mejor)],
    "validador_mejor": contar_incumplimientos(mejor, servs, inst, T_MIN),
    "voraz": {"c": voraz, "d": desglose(voraz), "validador": contar_incumplimientos(voraz, servs, inst, T_MIN),
              "violaciones": violaciones(voraz)},
    "violaciones_mejor": violaciones(mejor),
    "violaciones_inicial": [violaciones(c) for c in crudos[:6]],
    "ple": {"c": list(c_ple) if c_ple is not None else None, "estado": est_ple,
            "d": desglose(c_ple) if c_ple is not None else None},
    "tabu": {"c": list(c_tabu), "d": desglose(c_tabu)},
    "hojas_factibles": [{"c": c, "d": d} for c, d in hojas], "combinaciones": total_combinaciones,
    "registro_oficial": {k: fila_reg[k] for k in ("F", "J", "phi", "validador", "tiempo_s")},
    "tiempo_traza_s": t_total,
    "entorno": {"python": sys.version.split()[0], "pygad": pygad.__version__, "numpy": np.__version__},
}
SALIDA.write_text(json.dumps(salida, ensure_ascii=False, indent=1), encoding="utf8")
print("mejor", mejor, desglose(mejor))
print("voraz", voraz, desglose(voraz)["phi"], "ple", est_ple, "hojas", len(hojas), "combinaciones", total_combinaciones)
print("pares", len(pares), "padres g1", padres.get(1, {}).get("indices"))
print("cruces registrados", len(traza_cruce.get(1, [])), "mutaciones", len(traza_mut.get(1, [])))
print("primeras generaciones", por_gen[:3], por_gen[-1])
