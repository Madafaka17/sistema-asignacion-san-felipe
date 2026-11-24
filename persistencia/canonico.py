"""Representación canónica (JSON ordenado) de instancias y salidas, y su huella SHA-256.

Dos ejecuciones producen el mismo estado final si y solo si sus representaciones
canónicas son idénticas byte a byte; por eso la huella se usa para verificar el
determinismo y la paridad con el entorno de referencia.
"""
from __future__ import annotations

import hashlib
import json

FORMATO_SALIDA = "salida_humo_v1"


def a_json(obj) -> bytes:
    return (json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"),
                       allow_nan=False) + "\n").encode("utf8")


def sha256(datos: bytes) -> str:
    return hashlib.sha256(datos).hexdigest()


def instancia_a_dict(inst) -> dict:
    """Instancia del núcleo (core.domain.Instance) como diccionario ordenado."""
    return {
        "servicios": [
            {"id": s.service_id, "prioridad": s.priority, "comprometida": s.baseline_alt,
             "alternativas": [[a.vehicle_id, a.driver_id, a.departure_alt_id, a.start_time, a.duration]
                              for a in s.admissible]}
            for s in inst.services
        ],
        "conduccion_previa": dict(sorted(inst.driving_time_prior.items())),
        "limite_conduccion": dict(sorted(inst.driving_time_limit.items())),
        "pesos": dict(sorted(inst.weights.items())),
        "referencias": dict(sorted(inst.norm_refs.items())),
    }


def huella_instancia(inst) -> str:
    return sha256(a_json(instancia_a_dict(inst)))


def salida_a_dict(id_turno: int, semilla: int, resultado, validador: int) -> dict:
    """Programación devuelta por el núcleo (core.scheduler.ScheduleResult)."""
    b = resultado.breakdown
    asignaciones = []
    for s, g in zip(resultado.services, resultado.chromosome):
        a = s.admissible[g]
        asignaciones.append({"servicio": s.service_id, "alternativa": int(g), "unidad": a.vehicle_id,
                             "conductor": a.driver_id, "salida": a.departure_alt_id,
                             "inicio_min": a.start_time, "duracion_min": a.duration})
    return {
        "formato": FORMATO_SALIDA,
        "turno": id_turno,
        "semilla_ag": semilla,
        "cromosoma": [int(g) for g in resultado.chromosome],
        "asignaciones": asignaciones,
        "evaluacion": {"aptitud": b.fitness, "J": b.loss, "phi": b.feasibility_violations,
                       "conflictos": b.conflict_violations, "conductores_excedidos": b.overlimit_drivers,
                       "exceso_conduccion_min": b.driving_time_excess, "retraso_min": b.delay,
                       "reprogramaciones": b.reschedule, "tiempo_muerto_min": b.idle,
                       "desequilibrio": b.workload_spread},
        "validador_independiente": int(validador),
        "aptitud_por_generacion": [float(x) for x in resultado.best_fitness_by_generation],
    }
