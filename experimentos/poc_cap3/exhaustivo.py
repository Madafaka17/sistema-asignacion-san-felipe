"""Óptimo certificado por enumeración exhaustiva (referencia de C1 en n = 7).

REIMPLEMENTACIÓN (2026-10-17); ver experimentos/poc_cap3/README.md.

Recorre en profundidad todas las asignaciones, un servicio por nivel y sus
alternativas en el orden de A_s. Poda una rama en cuanto la asignación parcial
elige un par de Γ o deja a un conductor por encima de su límite (la carga solo
crece), de modo que cada hoja alcanzada es una programación factible (Φ = 0).
Devuelve el cromosoma de mayor F(X) —el primero encontrado en caso de empate—,
su aptitud y el número de hojas factibles.
"""
from __future__ import annotations

import math

from core.conflicts import conflict_index
from core.fitness import evaluate

_TOL = 1e-9


def optimo_exhaustivo(inst, pares, t_min):
    servicios = inst.services_with_options()
    indice = conflict_index(pares)
    n = len(servicios)
    crom = [0] * n
    carga = {}
    mejor = {"crom": None, "F": -math.inf, "hojas": 0}

    def admisible(i, a):
        for j, b in indice.get((i, a), ()):
            if j < i and crom[j] == b:
                return False
        alt = servicios[i].admissible[a]
        c = alt.driver_id
        total = inst.driving_time_prior.get(c, 0.0) + carga.get(c, 0.0) + alt.duration
        return total <= inst.driving_time_limit.get(c, math.inf) + _TOL

    def recorrer(i):
        if i == n:
            mejor["hojas"] += 1
            f = evaluate(crom, inst, pares, index=indice).fitness
            if f > mejor["F"]:
                mejor["crom"], mejor["F"] = list(crom), f
            return
        for a, alt in enumerate(servicios[i].admissible):
            if not admisible(i, a):
                continue
            crom[i] = a
            carga[alt.driver_id] = carga.get(alt.driver_id, 0.0) + alt.duration
            recorrer(i + 1)
            carga[alt.driver_id] -= alt.duration
        crom[i] = 0

    recorrer(0)
    return mejor["crom"], mejor["F"], mejor["hojas"]
