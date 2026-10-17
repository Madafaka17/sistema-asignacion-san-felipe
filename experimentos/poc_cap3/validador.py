"""Validador independiente de las restricciones duras (sección 3.2.3).

REIMPLEMENTACIÓN (2026-10-17); ver experimentos/poc_cap3/README.md.

No usa Γ ni la función de aptitud: recorre las asignaciones de cada vehículo y de
cada conductor y suma (i) los pares de asignaciones que comparten recurso y se
superponen o no respetan t_mín —un par que comparte vehículo y conductor cuenta
una vez— y (ii) los conductores que superan su límite de conducción. El
resultado debe coincidir con Φ(X).
"""
from __future__ import annotations

import math
from collections import defaultdict
from itertools import combinations

_TOL = 1e-9


def contar_incumplimientos(cromosoma, servicios, instancia, t_min) -> int:
    asig = [(i, s.admissible[int(g)]) for i, (s, g) in enumerate(zip(servicios, cromosoma))]
    por_recurso = defaultdict(list)
    for i, a in asig:
        por_recurso[("V", a.vehicle_id)].append((i, a))
        por_recurso[("C", a.driver_id)].append((i, a))
    cruces = set()
    for lista in por_recurso.values():
        for (i, x), (j, y) in combinations(lista, 2):
            if not (x.start_time + x.duration + t_min <= y.start_time
                    or y.start_time + y.duration + t_min <= x.start_time):
                cruces.add((min(i, j), max(i, j)))
    carga = defaultdict(float)
    for _, a in asig:
        carga[a.driver_id] += a.duration
    excedidos = sum(1 for c, x in carga.items()
                    if instancia.driving_time_prior.get(c, 0.0) + x
                    > instancia.driving_time_limit.get(c, math.inf) + _TOL)
    return len(cruces) + excedidos
