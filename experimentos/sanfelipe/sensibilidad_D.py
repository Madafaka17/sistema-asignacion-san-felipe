"""Análisis exploratorio definido DESPUÉS de conocer los resultados de v1 y v2
(ver DESVIACIONES.md). No reemplaza a la ejecución oficial.

Motivo: en el capítulo III, D(X) es la desviación estándar de la carga de los
conductores CON AL MENOS UN SERVICIO. Con esa definición, dejar sin servicios a un
conductor disponible reduce D, de modo que una programación que concentra el
trabajo en menos conductores puede resultar «más equilibrada». Este análisis repite
las configuraciones v1 y v2 con una definición alternativa: D sobre TODOS los conductores
que figuran en alguna alternativa admisible de la instancia (los que no reciben
servicios cuentan con carga 0). Todo lo demás —instancias, semillas,
configuraciones, criterios, anclajes y pesos— es idéntico a v1 (variante v1D) o a
v2 (variante v2D).

    python3 sensibilidad_D.py ejecutar v1   # -> resultados_crudos_v1D.csv
    python3 sensibilidad_D.py analizar v1   # -> resumen_v1D.json
    python3 sensibilidad_D.py ejecutar v2   # -> resultados_crudos_v2D.csv
    python3 sensibilidad_D.py analizar v2   # -> resumen_v2D.json
"""
from __future__ import annotations

import math
import sys

import experimento
from core import fitness


def _loss_components_todos(chromosome, services):
    """Igual que core.fitness._loss_components, salvo que D incluye a todos los
    conductores que aparecen en alguna alternativa admisible (carga 0 si no reciben
    servicios)."""
    by_vehicle = {}
    driver_load = {a.driver_id: 0.0 for s in services for a in s.admissible}
    delay = 0.0
    reschedule = 0
    for s, idx in zip(services, chromosome):
        a = s.admissible[idx]
        by_vehicle.setdefault(a.vehicle_id, []).append((a.start_time, a.start_time + a.duration))
        driver_load[a.driver_id] += a.duration
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


if __name__ == "__main__":
    base = sys.argv[2] if len(sys.argv) > 2 else "v1"
    assert base in ("v1", "v2")
    variante = base + "D"
    fitness._loss_components = _loss_components_todos
    experimento.PARAM_AG[variante] = experimento.PARAM_AG[base]
    experimento.PARAM_TABU[variante] = experimento.PARAM_TABU[base]
    {"ejecutar": experimento.ejecutar, "analizar": experimento.analizar}[sys.argv[1]](variante)
