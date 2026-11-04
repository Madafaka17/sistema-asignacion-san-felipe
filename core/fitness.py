"""Chromosome representation and fitness evaluation.

Implements, in code, the article's Eq. (9)-(12) (Section 2.8):

  Eq. (9)  chromosome    alpha(s) in A_s for every service s with A_s != {}
  Eq. (10) conflict count V(alpha) = |{((s,a),(t,b)) in conflict_pairs :
                                        alpha(s)=a, alpha(t)=b}|
  Eq. (11) driving-time excess  e_c(alpha) = max(0, H_c0
                                  + sum_{s: c(alpha(s))=c} d_s,alpha(s)
                                  - H_cmax),  for each driver c
  Eq. (12) scalarized fitness   fit(alpha) = -( M * Phi(alpha)
                                  + sum_c e_c(alpha) + J(alpha) )
           where Phi(alpha) = V(alpha) + |{c : e_c(alpha) > 0}|

Eq. (12) is a static-penalty scalarization of the lexicographic objective
of Eq. (7)-(8): it is the article's explicit, stated way of reducing a
two-level (feasibility, then loss) objective to the single real-valued
fitness a genetic algorithm requires, following the constraint-handling
methodology surveyed in [8]. It is a modeling decision made for this
implementation, not a re-derivation of Eq. (7)-(8) -- with M large enough,
any reduction in Phi dominates any change in the secondary terms, which
approximates, but does not exactly reproduce, true lexicographic ordering.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

from .conflicts import build_driving_time_index
from .domain import Instance, Service

Chromosome = tuple[int, ...]  # one entry per service in services_with_options(), each an index into that service's `admissible`


@dataclass(frozen=True)
class FitnessBreakdown:
    conflict_violations: int          # V(alpha), Eq. (10)
    overlimit_drivers: int            # |{c : e_c(alpha) > 0}|
    driving_time_excess: float        # sum_c e_c(alpha), Eq. (11)
    delay: float                      # z_delay
    reschedule: int                   # z_reschedule
    idle: float                       # z_idle
    workload_spread: float            # z_workload
    loss: float                       # J(alpha), Eq. (8)
    fitness: float                    # fit(alpha), Eq. (12)

    @property
    def feasibility_violations(self) -> int:
        return self.conflict_violations + self.overlimit_drivers

    @property
    def is_feasible(self) -> bool:
        return self.feasibility_violations == 0


def _conflict_violations(chromosome: Chromosome, services: tuple[Service, ...], conflict_pairs) -> int:
    selected = {s.service_id: idx for s, idx in zip(services, chromosome)}
    count = 0
    for (sid1, i1), (sid2, i2) in conflict_pairs:
        if selected.get(sid1) == i1 and selected.get(sid2) == i2:
            count += 1
    return count


def _driving_time_excess(
    chromosome: Chromosome,
    services: tuple[Service, ...],
    driving_time_index: dict,
    driving_time_prior: dict,
    driving_time_limit: dict,
) -> dict[str, float]:
    selected = {s.service_id: idx for s, idx in zip(services, chromosome)}
    load: dict[str, float] = {c: 0.0 for c in driving_time_index}
    for driver_id, entries in driving_time_index.items():
        total = driving_time_prior.get(driver_id, 0.0)
        for sid, opt_i, duration in entries:
            if selected.get(sid) == opt_i:
                total += duration
        limit = driving_time_limit.get(driver_id, math.inf)
        load[driver_id] = max(0.0, total - limit)
    return load


def _loss_components(
    chromosome: Chromosome,
    services: tuple[Service, ...],
) -> tuple[float, int, float, float]:
    """z_delay, z_reschedule, z_idle, z_workload -- see module docstring
    and Section 2.5's prose for what each is meant to measure; the exact
    formulas below are this implementation's explicit, documented choice,
    not a value taken from the thesis or already fixed by the article.
    """
    by_vehicle: dict[str, list[tuple[float, float]]] = {}
    driver_load: dict[str, float] = {}
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

    if driver_load:
        loads = list(driver_load.values())
        mean = sum(loads) / len(loads)
        workload_spread = math.sqrt(sum((x - mean) ** 2 for x in loads) / len(loads))
    else:
        workload_spread = 0.0

    return delay, reschedule, idle, workload_spread


def evaluate(
    chromosome: Chromosome,
    instance: Instance,
    conflict_pairs,
    big_m: float = 1.0e6,
) -> FitnessBreakdown:
    """Full evaluation of a chromosome: Eq. (10)-(12). Pure function --
    no side effects, safe to call from any context (unit tests, the GA
    loop, a one-off diagnostic script).
    """
    services = instance.services_with_options()
    driving_time_index = build_driving_time_index(services)

    conflict_violations = _conflict_violations(chromosome, services, conflict_pairs)
    excess_by_driver = _driving_time_excess(
        chromosome, services, driving_time_index,
        instance.driving_time_prior, instance.driving_time_limit,
    )
    overlimit_drivers = sum(1 for e in excess_by_driver.values() if e > 0)
    driving_time_excess = sum(excess_by_driver.values())

    delay, reschedule, idle, workload_spread = _loss_components(chromosome, services)

    w = instance.weights
    b = instance.norm_refs
    z = {"delay": delay, "reschedule": reschedule, "idle": idle, "workload": workload_spread}
    active = [j for j in z if w.get(j, 0.0) > 0.0]
    loss = sum(w[j] * z[j] / b.get(j, 1.0) for j in active) if active else 0.0

    phi = conflict_violations + overlimit_drivers
    fitness = -(big_m * phi + driving_time_excess + loss)

    return FitnessBreakdown(
        conflict_violations=conflict_violations,
        overlimit_drivers=overlimit_drivers,
        driving_time_excess=driving_time_excess,
        delay=delay,
        reschedule=reschedule,
        idle=idle,
        workload_spread=workload_spread,
        loss=loss,
        fitness=fitness,
    )
