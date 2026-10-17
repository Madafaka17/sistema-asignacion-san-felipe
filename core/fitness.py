"""Función de aptitud F(X) de las ecuaciones (7) y (8).

REIMPLEMENTACIÓN (2026-10-17); ver core/README.md. `_loss_components` sigue la
estructura que conserva experimentos/sanfelipe/sensibilidad_D.py, que lo
reemplaza para el análisis exploratorio de D.

    F(X) = −[M·Φ(X) + E(X) + J(X)]
    J(X) = w_Ret·Ret/b_Ret + w_R·R/b_R + w_Tm·Tm/b_Tm + w_D·D/b_D

Φ = pares de Γ elegidos a la vez (cada par una vez) + conductores que superan su
límite; E = minutos de exceso de conducción; M = 10^6.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

from .conflicts import conflict_index

BIG_M = 1e6
_TOL = 1e-9


@dataclass(frozen=True)
class FitnessBreakdown:
    fitness: float               # F(X)
    loss: float                  # J(X)
    conflict_violations: int     # Cv + Cc
    overlimit_drivers: int       # N_exc
    driving_time_excess: float   # E(X), min
    delay: float                 # Ret(X), min
    reschedule: int              # R(X)
    idle: float                  # Tm(X), min
    workload_spread: float       # D(X), min

    @property
    def phi(self) -> int:
        return self.conflict_violations + self.overlimit_drivers


def _loss_components(chromosome, services):
    """Ret, R, Tm y D de la programación. D es la desviación estándar
    poblacional de la carga de los conductores con al menos un servicio."""
    by_vehicle = {}
    driver_load = {}
    delay = 0.0
    reschedule = 0
    for s, idx in zip(services, chromosome):
        a = s.admissible[idx]
        by_vehicle.setdefault(a.vehicle_id, []).append((a.start_time, a.start_time + a.duration))
        driver_load[a.driver_id] = driver_load.get(a.driver_id, 0.0) + a.duration
        if s.baseline_alt is not None:
            baseline = s.admissible[s.baseline_alt]
            delay += max(0.0, a.start_time - baseline.start_time)
            if idx != s.baseline_alt:
                reschedule += 1
    idle = 0.0
    for intervals in by_vehicle.values():
        intervals.sort()
        for (_, end1), (start2, _) in zip(intervals, intervals[1:]):
            idle += max(0.0, start2 - end1)
    loads = list(driver_load.values())
    if loads:
        mean = sum(loads) / len(loads)
        workload_spread = math.sqrt(sum((x - mean) ** 2 for x in loads) / len(loads))
    else:
        workload_spread = 0.0
    return delay, reschedule, idle, workload_spread


def driver_loads(chromosome, services) -> dict:
    """ℓ_c(X): minutos asignados a cada conductor."""
    carga = {}
    for s, idx in zip(services, chromosome):
        a = s.admissible[idx]
        carga[a.driver_id] = carga.get(a.driver_id, 0.0) + a.duration
    return carga


def count_conflicts(chromosome, conflict_pairs, index=None) -> int:
    """Pares de Γ elegidos a la vez."""
    if index is None:
        index = conflict_index(conflict_pairs)
    total = 0
    for i, a in enumerate(chromosome):
        for j, b in index.get((i, a), ()):
            if j > i and chromosome[j] == b:
                total += 1
    return total


def evaluate(chromosome, instance, conflict_pairs, big_m: float = BIG_M, index=None) -> FitnessBreakdown:
    """F(X) del cromosoma (un índice de alternativa por servicio de S')."""
    services = instance.services_with_options()
    chromosome = [int(g) for g in chromosome]
    conflicts = count_conflicts(chromosome, conflict_pairs, index)
    excess = 0.0
    overlimit = 0
    for c, carga in driver_loads(chromosome, services).items():
        total = instance.driving_time_prior.get(c, 0.0) + carga
        limite = instance.driving_time_limit.get(c, math.inf)
        if total > limite + _TOL:
            overlimit += 1
            excess += total - limite
    delay, reschedule, idle, spread = _loss_components(chromosome, services)
    w, b = instance.weights, instance.norm_refs
    loss = (w["delay"] * delay / b["delay"] + w["reschedule"] * reschedule / b["reschedule"]
            + w["idle"] * idle / b["idle"] + w["workload"] * spread / b["workload"])
    phi = conflicts + overlimit
    fitness = -(big_m * phi + excess + loss)
    return FitnessBreakdown(fitness, loss, conflicts, overlimit, excess, delay, reschedule, idle, spread)
