"""Validador independiente de restricciones duras.

Recalcula, a partir de los intervalos crudos de cada asignación (y no del
conjunto de pares en conflicto precalculado por el núcleo), cuántos pares de
servicios comparten vehículo o conductor sin respetar t_min y cuántos
conductores exceden su límite de conducción. Sirve para comprobar que la
función de evaluación común no oculta incumplimientos.
"""
from __future__ import annotations

from collections import defaultdict
from itertools import combinations


def contar_incumplimientos(cromosoma, servicios, instancia, t_min: float) -> int:
    asignadas = [(s.service_id, s.admissible[g]) for s, g in zip(servicios, cromosoma)]
    por_recurso = defaultdict(list)
    for sid, a in asignadas:
        por_recurso[("V", a.vehicle_id)].append((sid, a))
        por_recurso[("C", a.driver_id)].append((sid, a))

    pares = set()
    for _, lista in por_recurso.items():
        for (s1, a1), (s2, a2) in combinations(lista, 2):
            fin1 = a1.start_time + a1.duration
            fin2 = a2.start_time + a2.duration
            separados = fin1 + t_min <= a2.start_time or fin2 + t_min <= a1.start_time
            if not separados:
                pares.add(tuple(sorted((s1, s2))))

    carga = defaultdict(float)
    for _, a in asignadas:
        carga[a.driver_id] += a.duration
    excedidos = 0
    for c, total in carga.items():
        previo = instancia.driving_time_prior.get(c, 0.0)
        limite = instancia.driving_time_limit.get(c, float("inf"))
        if previo + total > limite + 1e-9:
            excedidos += 1
    return len(pares) + excedidos
