"""Constraint repair (Section 2.6: "a uniform or service-block crossover
... followed by constraint repair"). Applied after crossover and after
mutation, to steer offspring back toward the conflict-free region of the
search space rather than relying on the fitness penalty (Eq. 12) alone.

This is a bounded, greedy heuristic, not a completeness proof: it resolves
the conflicts it can within `max_passes` re-samplings and leaves the rest
to the fitness penalty. That trade-off -- and not overstating what the
repair operator guarantees -- is itself part of the specification.
"""
from __future__ import annotations

import random

from .domain import Service

Chromosome = tuple[int, ...]


def repair(
    chromosome: Chromosome,
    services: tuple[Service, ...],
    conflict_pairs,
    rng: random.Random,
    max_passes: int = 5,
) -> Chromosome:
    genes = list(chromosome)
    service_index = {s.service_id: i for i, s in enumerate(services)}
    by_id = {s.service_id: s for s in services}

    for _ in range(max_passes):
        violated = [
            (sid1, sid2)
            for (sid1, i1), (sid2, i2) in conflict_pairs
            if genes[service_index[sid1]] == i1 and genes[service_index[sid2]] == i2
        ]
        if not violated:
            break
        touched: set[str] = set()
        for sid1, sid2 in violated:
            target = sid2 if sid2 not in touched else sid1
            svc = by_id[target]
            if len(svc.admissible) > 1:
                genes[service_index[target]] = rng.randrange(len(svc.admissible))
            touched.add(target)

    return tuple(genes)


def build_conflict_index(services: tuple[Service, ...], conflict_pairs) -> dict:
    """(service_id, option) -> list of (service_id, option) it conflicts with."""
    index: dict = {}
    for (s1, i1), (s2, i2) in conflict_pairs:
        index.setdefault((s1, i1), []).append((s2, i2))
        index.setdefault((s2, i2), []).append((s1, i1))
    return index


def repair_targeted(
    chromosome: Chromosome,
    services: tuple[Service, ...],
    conflict_index: dict,
    driving_time_prior: dict,
    driving_time_limit: dict,
    max_passes: int = 5,
) -> Chromosome:
    """Repair as specified in the thesis (mecanismo de reparación): for every
    realized conflict, keep the service with higher priority (ties: earlier
    start) and move the other one to the first admissible alternative, in
    order of start time, that creates no new conflict and keeps its driver
    within the driving-time limit; if none exists, try moving the kept service
    instead; if still none, the conflict is left in place (an incidence for
    human review, penalized by the fitness) rather than forcing an invalid
    assignment. Drivers over their limit are relieved the same way.
    Deterministic: it uses no random numbers.
    """
    genes = list(chromosome)
    pos = {s.service_id: i for i, s in enumerate(services)}

    def selected(sid):
        return genes[pos[sid]]

    def loads():
        out: dict = {}
        for s, g in zip(services, genes):
            a = s.admissible[g]
            out[a.driver_id] = out.get(a.driver_id, 0.0) + a.duration
        return out

    def fits(i, j, load):
        s = services[i]
        a = s.admissible[j]
        for (t, b) in conflict_index.get((s.service_id, j), ()):
            if t != s.service_id and selected(t) == b:
                return False
        current = s.admissible[genes[i]]
        extra = a.duration - (current.duration if current.driver_id == a.driver_id else 0.0)
        total = driving_time_prior.get(a.driver_id, 0.0) + load.get(a.driver_id, 0.0) + extra
        return total <= driving_time_limit.get(a.driver_id, float("inf")) + 1e-9

    def relocate(i, load):
        s = services[i]
        order = sorted(range(len(s.admissible)), key=lambda j: (s.admissible[j].start_time, j))
        for j in order:
            if j != genes[i] and fits(i, j, load):
                genes[i] = j
                return True
        return False

    for _ in range(max_passes):
        changed = False
        for i, s in enumerate(services):
            for (t, b) in conflict_index.get((s.service_id, genes[i]), ()):
                k = pos[t]
                if genes[k] != b or k == i:
                    continue
                si, sk = services[i], services[k]
                ai, ak = si.admissible[genes[i]], sk.admissible[genes[k]]
                keep_i = (si.priority, -ai.start_time) >= (sk.priority, -ak.start_time)
                move, stay = (k, i) if keep_i else (i, k)
                load = loads()
                if relocate(move, load) or relocate(stay, load):
                    changed = True
                break
        load = loads()
        for i, s in enumerate(services):
            a = s.admissible[genes[i]]
            limit = driving_time_limit.get(a.driver_id, float("inf"))
            if driving_time_prior.get(a.driver_id, 0.0) + load.get(a.driver_id, 0.0) > limit + 1e-9:
                if relocate(i, load):
                    changed = True
                    load = loads()
        if not changed:
            break
    return tuple(genes)
