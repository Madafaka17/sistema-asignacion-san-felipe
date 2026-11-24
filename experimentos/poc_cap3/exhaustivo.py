"""Óptimo certificado por enumeración exhaustiva con poda (solo instancias pequeñas).

Recorre todas las asignaciones factibles (sin conflictos ni exceso de horas),
podando en cuanto una asignación parcial incumple una restricción dura, y
devuelve la de mayor aptitud F según la misma función de evaluación común.
"""
from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from core.fitness import evaluate  # noqa: E402


def optimo_exhaustivo(instancia, pares, t_min: float):
    servicios = instancia.services_with_options()
    n = len(servicios)
    mejor = {"f": float("-inf"), "c": None, "hojas": 0}
    ocup_v, ocup_c = defaultdict(list), defaultdict(list)
    carga = defaultdict(float)
    crom = [0] * n

    def libre(a):
        for (ini, fin) in ocup_v[a.vehicle_id] + ocup_c[a.driver_id]:
            if not (a.start_time + a.duration + t_min <= ini or fin + t_min <= a.start_time):
                return False
        lim = instancia.driving_time_limit.get(a.driver_id, float("inf"))
        return instancia.driving_time_prior.get(a.driver_id, 0.0) + carga[a.driver_id] + a.duration <= lim

    def rec(i):
        if i == n:
            mejor["hojas"] += 1
            f = evaluate(tuple(crom), instancia, pares).fitness
            if f > mejor["f"]:
                mejor["f"], mejor["c"] = f, tuple(crom)
            return
        s = servicios[i]
        for j, a in enumerate(s.admissible):
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
    return mejor["c"], mejor["f"], mejor["hojas"]
