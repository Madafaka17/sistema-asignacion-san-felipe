"""Orchestration of the genetic algorithm (Section 2.6, Section 2.8) on top
of PyGAD [4]. This module is the article's own contribution -- chromosome
encoding, fitness, crossover-with-repair, mutation-with-repair -- wired
into PyGAD's generic selection/replacement engine; PyGAD supplies the
population loop and tournament selection, nothing about the transport
scheduling problem itself.

Still part of the "core": takes an Instance and returns a ScheduleResult,
with no database access, no printing, and no UI dependency. The caller
(business logic layer, Figure 4) is responsible for persisting the result
(Figure 5) and for any display (presentation layer, Figure 1-2).
"""
from __future__ import annotations

import random
import time
from dataclasses import dataclass

import numpy as np
import pygad

from .conflicts import build_conflict_pairs
from .domain import Instance, Service
from .fitness import Chromosome, FitnessBreakdown, evaluate
from .repair import build_conflict_index, repair_targeted
from .repair import repair as repair_chromosome


@dataclass(frozen=True)
class GAConfig:
    population_size: int = 30
    num_generations: int = 60
    crossover_probability: float = 1.0      # 1.0 = cross every mated pair (demo default);
                                            # the thesis proposes 0.80 (Tabla 18) for calibration
    mutation_probability: float = 0.10      # thesis proposal, Section 2.9
    tournament_size: int = 3                # thesis proposal, kept in 2.6
    elitism_fraction: float = 0.10          # thesis proposal, Section 2.9
    min_transition: float = 0.0             # tau^min, Table 1
    big_m: float = 1.0e6                    # Eq. (12)
    random_seed: int = 42                   # fixed for reproducibility
    # Operator variants. Defaults reproduce the article's illustrative run;
    # the thesis design (pseudocode and repair mechanism of Chapter 3) uses
    # mutation_scope="chromosome", repair_mode="targeted", repair_initial=True.
    mutation_scope: str = "gene"            # "gene": p_m per gene; "chromosome": p_m per offspring, one gene changed
    repair_mode: str = "random"             # "random": bounded resampling; "targeted": priority-based relocation
    repair_initial: bool = False            # repair the initial population before the first generation
    stop_saturation: int | None = None      # stop after this many generations without fitness change (None = off)
    time_limit: float | None = None         # wall-clock limit in seconds (None = off)


@dataclass(frozen=True)
class ScheduleResult:
    chromosome: Chromosome
    breakdown: FitnessBreakdown
    services: tuple[Service, ...]           # services_with_options(), same order as chromosome
    best_fitness_by_generation: tuple[float, ...]

    def assignments(self) -> dict[str, dict]:
        """Map each scheduled service to its selected admissible triple,
        in the shape the business logic layer persists into the
        SCHEDULES table of Figure 5 (service_id -> vehicle_id, driver_id,
        departure_time / departure_alt_id).
        """
        out = {}
        for s, idx in zip(self.services, self.chromosome):
            a = s.admissible[idx]
            out[s.service_id] = {
                "vehicle_id": a.vehicle_id,
                "driver_id": a.driver_id,
                "departure_alt_id": a.departure_alt_id,
                "start_time": a.start_time,
            }
        return out


def _make_operators(services: tuple[Service, ...], conflict_pairs, seed: int,
                   crossover_probability: float = 1.0, mutation_scope: str = "gene",
                   repair_mode: str = "random", instance: Instance | None = None):
    rng = random.Random(seed)
    conflict_index = build_conflict_index(services, conflict_pairs) if repair_mode == "targeted" else None

    def fix(genes):
        if repair_mode == "targeted":
            return repair_targeted(tuple(genes), services, conflict_index,
                                   instance.driving_time_prior, instance.driving_time_limit)
        return repair_chromosome(tuple(genes), services, conflict_pairs, rng)

    def crossover_with_repair(parents: np.ndarray, offspring_size, ga_instance) -> np.ndarray:
        # Uniform crossover (Section 2.6: "A uniform ... crossover can
        # inherit assignment alternatives at the same service positions"),
        # each offspring gene inherited independently from either parent.
        offspring = np.empty(offspring_size, dtype=int)
        n_parents = parents.shape[0]
        for i in range(offspring_size[0]):
            p1 = parents[i % n_parents]
            p2 = parents[(i + 1) % n_parents]
            # Crossover probability p_c: with probability 1 - p_c the child is a
            # copy of the first parent. No random draw is consumed when p_c = 1.0,
            # so runs with the default configuration are bit-for-bit unchanged.
            if crossover_probability < 1.0 and rng.random() >= crossover_probability:
                child = [int(g) for g in p1]
            else:
                mask = rng.getrandbits(offspring_size[1])
                child = [
                    int(p1[g]) if (mask >> g) & 1 else int(p2[g])
                    for g in range(offspring_size[1])
                ]
            child = fix(child)
            offspring[i] = np.array(child, dtype=int)
        return offspring

    mutable = [g for g, svc in enumerate(services) if len(svc.admissible) > 1]

    def mutation_with_repair(offspring: np.ndarray, ga_instance) -> np.ndarray:
        for i in range(offspring.shape[0]):
            genes = list(offspring[i])
            if mutation_scope == "chromosome":
                # Thesis pseudocode: with probability p_m the offspring is mutated by
                # reassigning one service to another admissible alternative.
                if mutable and rng.random() < ga_instance.mutation_probability:
                    g = rng.choice(mutable)
                    others = [j for j in range(len(services[g].admissible)) if j != genes[g]]
                    genes[g] = rng.choice(others)
            else:
                for g, svc in enumerate(services):
                    if rng.random() < ga_instance.mutation_probability and len(svc.admissible) > 1:
                        genes[g] = rng.randrange(len(svc.admissible))
            genes = fix(genes)
            offspring[i] = np.array(genes, dtype=int)
        return offspring

    return crossover_with_repair, mutation_with_repair, fix


def run(instance: Instance, config: GAConfig = GAConfig()) -> ScheduleResult:
    services = instance.services_with_options()
    if not services:
        empty_breakdown = evaluate((), instance, frozenset(), big_m=config.big_m)
        return ScheduleResult((), empty_breakdown, services, ())

    conflict_pairs = build_conflict_pairs(services, min_transition=config.min_transition)
    crossover_with_repair, mutation_with_repair, fix = _make_operators(
        services, conflict_pairs, config.random_seed, config.crossover_probability,
        config.mutation_scope, config.repair_mode, instance)

    initial_population = None
    if config.repair_initial:
        # Thesis pseudocode: random initial population, then repair of every
        # chromosome that violates a hard constraint (own RNG stream, seeded).
        init_rng = random.Random(config.random_seed + 7919)
        initial_population = [
            list(fix([init_rng.randrange(len(s.admissible)) for s in services]))
            for _ in range(config.population_size)
        ]

    gene_space = [{"low": 0, "high": len(s.admissible)} for s in services]  # Eq. (9): alpha(s) in {0,...,|A_s|-1}

    def fitness_func(ga_instance, solution, solution_idx) -> float:
        chromosome = tuple(int(g) for g in solution)
        return evaluate(chromosome, instance, conflict_pairs, big_m=config.big_m).fitness

    history: list[float] = []

    started = time.perf_counter()

    def on_generation(ga_instance):
        history.append(float(ga_instance.best_solution()[1]))
        if config.time_limit is not None and time.perf_counter() - started >= config.time_limit:
            return "stop"
        return None

    ga = pygad.GA(
        num_generations=config.num_generations,
        num_parents_mating=max(2, config.population_size // 2),
        fitness_func=fitness_func,
        sol_per_pop=config.population_size,
        num_genes=len(services),
        initial_population=initial_population,
        gene_type=int,
        gene_space=gene_space,
        parent_selection_type="tournament",       # thesis proposal, Section 2.6
        K_tournament=config.tournament_size,
        keep_elitism=max(1, round(config.elitism_fraction * config.population_size)),
        crossover_type=crossover_with_repair,      # Section 2.6 / 2.8
        mutation_type=mutation_with_repair,        # Section 2.6 / 2.8
        mutation_probability=config.mutation_probability,
        on_generation=on_generation,
        random_seed=config.random_seed,            # reproducibility
        suppress_warnings=True,
        stop_criteria=(f"saturate_{config.stop_saturation}" if config.stop_saturation else None),
    )
    ga.run()

    best_solution, best_fitness, _ = ga.best_solution()
    best_chromosome = tuple(int(g) for g in best_solution)
    breakdown = evaluate(best_chromosome, instance, conflict_pairs, big_m=config.big_m)

    return ScheduleResult(
        chromosome=best_chromosome,
        breakdown=breakdown,
        services=services,
        best_fitness_by_generation=tuple(history),
    )
