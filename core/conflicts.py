"""Conjunto Γ de pares de alternativas en conflicto (ecuación 4).

REIMPLEMENTACIÓN (2026-10-17); ver core/README.md.

Dos alternativas de servicios distintos están en conflicto si comparten vehículo
o conductor y sus intervalos se superponen o quedan separados por menos de la
holgura mínima t_mín:

    t_{s,a} < t_{s',a'} + d_{s',a'} + t_mín  y  t_{s',a'} < t_{s,a} + d_{s,a} + t_mín

Cada par se representa como ((i, a), (j, b)) con i < j, donde i y j son las
posiciones de los servicios en S' (el orden de los genes del cromosoma) y a, b
los índices de las alternativas en A_s.
"""
from __future__ import annotations

from collections import defaultdict


def _se_cruzan(x, y, min_transition: float) -> bool:
    return (x.start_time < y.start_time + y.duration + min_transition
            and y.start_time < x.start_time + x.duration + min_transition)


def build_conflict_pairs(services, min_transition: float = 0.0) -> frozenset:
    """Γ para los servicios de S' en el orden dado."""
    por_recurso = defaultdict(list)                  # recurso -> [(i, a, alternativa)]
    for i, s in enumerate(services):
        for a, alt in enumerate(s.admissible):
            por_recurso[("V", alt.vehicle_id)].append((i, a, alt))
            por_recurso[("C", alt.driver_id)].append((i, a, alt))
    pares = set()
    for lista in por_recurso.values():
        for k, (i, a, x) in enumerate(lista):
            for j, b, y in lista[k + 1:]:
                if i != j and _se_cruzan(x, y, min_transition):
                    pares.add(((i, a), (j, b)) if i < j else ((j, b), (i, a)))
    return frozenset(pares)


def conflict_index(conflict_pairs) -> dict:
    """Vecinos en Γ de cada alternativa: (i, a) -> {(j, b), ...}."""
    indice = defaultdict(set)
    for p, q in conflict_pairs:
        indice[p].add(q)
        indice[q].add(p)
    return indice
