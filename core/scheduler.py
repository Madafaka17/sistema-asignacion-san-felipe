"""Algoritmo genético del capítulo III (secciones 3.1.7 y 3.4) sobre PyGAD.

REIMPLEMENTACIÓN (2026-10-17); ver core/README.md. Sigue el pseudocódigo de la
Tabla 22 y los parámetros de la Tabla 23:

- cromosoma: un gen por servicio de S', con el índice de su alternativa (ec. 15);
- población inicial: genes aleatorios uniformes, cada cromosoma reparado;
- aptitud: F(X) de la ecuación (7);
- selección por torneo de tamaño k (PyGAD);
- cruce uniforme con probabilidad p_c; si no, copia del primer progenitor;
- mutación por descendiente con probabilidad p_m: un servicio con más de una
  alternativa cambia a otra alternativa elegida al azar;
- reparación dirigida (sección 3.4.9) de cada descendiente antes de evaluarlo;
- elitismo: redondeo(ε·P) mejores cromosomas sin cambios (PyGAD);
- parada: G_máx generaciones, g_conv generaciones sin cambio de la mejor
  aptitud (solo si se indica) o el límite de tiempo.

El ciclo generacional, el torneo y el elitismo son los de PyGAD; la codificación,
la aptitud, el cruce, la mutación y la reparación son propios. Con la misma
semilla, la ejecución se repite exactamente.
"""
from __future__ import annotations

import math
import time
from dataclasses import dataclass, field

import numpy
import pygad

from .conflicts import build_conflict_pairs, conflict_index
from .fitness import evaluate
from .repair import repair


@dataclass(frozen=True)
class GAConfig:
    population_size: int = 50           # P
    generations: int = 100              # G_máx
    crossover_prob: float = 0.80        # p_c
    mutation_prob: float = 0.10         # p_m, por descendiente
    tournament_k: int = 3               # k
    elitism: float = 0.10               # ε
    stall_generations: int | None = None  # g_conv (None: sin parada por convergencia, como en v1)
    time_limit: float = 300.0           # t_lím, s
    seed: int = 1


@dataclass
class GAResult:
    chromosome: list
    fitness: float
    generations: int
    evaluations: int
    elapsed: float
    history: list = field(default_factory=list)   # mejor F al cierre de cada generación


def run_ga(instance, min_transition: float, config: GAConfig = GAConfig()) -> GAResult:
    services = instance.services_with_options()
    pairs = build_conflict_pairs(services, min_transition=min_transition)
    index = conflict_index(pairs)
    sizes = [len(s.admissible) for s in services]
    mutables = [i for i, k in enumerate(sizes) if k > 1]
    rng = numpy.random.default_rng(config.seed)
    inicio = time.perf_counter()

    def reparar(crom):
        return repair(crom, instance, index=index)

    poblacion = numpy.array([reparar([int(rng.integers(k)) for k in sizes])
                             for _ in range(config.population_size)], dtype=int)

    mejor = {"crom": None, "F": -math.inf, "evaluaciones": 0}
    historia = []

    def aptitud(ga, solucion, _idx):
        mejor["evaluaciones"] += 1
        f = evaluate(solucion, instance, pairs, index=index).fitness
        if f > mejor["F"]:
            mejor["crom"], mejor["F"] = [int(g) for g in solucion], f
        return f

    def cruce(padres, tamano, ga):
        hijos = numpy.empty(tamano, dtype=int)
        for k in range(tamano[0]):
            p1 = padres[k % len(padres)]
            p2 = padres[(k + 1) % len(padres)]
            if rng.random() < config.crossover_prob:
                hijos[k] = numpy.where(rng.random(tamano[1]) < 0.5, p1, p2)
            else:
                hijos[k] = p1
        return hijos

    def mutacion(hijos, ga):
        for k in range(len(hijos)):
            if mutables and rng.random() < config.mutation_prob:
                i = mutables[int(rng.integers(len(mutables)))]
                nuevo = int(rng.integers(sizes[i] - 1))
                hijos[k, i] = nuevo + (nuevo >= int(hijos[k, i]))
            hijos[k] = reparar(hijos[k].tolist())
        return hijos

    def al_cerrar_generacion(ga):
        historia.append(mejor["F"])

    parada = [f"time_{config.time_limit:g}"]
    if config.stall_generations:
        parada.append(f"saturate_{config.stall_generations}")
    ga = pygad.GA(
        num_generations=config.generations,
        num_parents_mating=config.population_size,
        fitness_func=aptitud,
        initial_population=poblacion,
        gene_type=int,
        parent_selection_type="tournament",
        K_tournament=config.tournament_k,
        keep_elitism=max(1, round(config.elitism * config.population_size)),
        crossover_type=cruce,
        mutation_type=mutacion,
        on_generation=al_cerrar_generacion,
        stop_criteria=parada,
        random_seed=config.seed,
        suppress_warnings=True,
    )
    ga.run()
    return GAResult(mejor["crom"], mejor["F"], ga.generations_completed, mejor["evaluaciones"],
                    time.perf_counter() - inicio, historia)
