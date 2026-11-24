"""Utilidades de las pruebas del núcleo.

Contiene constructores de instancias y ORÁCULOS INDEPENDIENTES: cálculos de
referencia escritos de nuevo, por fuerza bruta y sin importar el código bajo
prueba (core/ y experimentos/poc_cap3/). Una prueba compara la salida del núcleo
con el oráculo; si ambos compartieran código, un error común pasaría inadvertido.
"""
from __future__ import annotations

import itertools
import math
import random
import statistics

from core.domain import AdmissibleTriple, Instance, Service

PESOS_TESIS = {"delay": 0.25, "reschedule": 0.25, "idle": 0.25, "workload": 0.25}


def alt(sid, vehiculo, conductor, h, inicio, duracion):
    """Atajo para construir una tripleta admisible a = (v, c, h) de A_s."""
    return AdmissibleTriple(sid, vehiculo, conductor, h, float(inicio), float(duracion))


# ---------------------------------------------------------------------------
# Instancia de control (valores esperados calculados a mano, ver test_m04)
# ---------------------------------------------------------------------------
def instancia_control() -> Instance:
    """Cuatro servicios, tres unidades y tres conductores con t_min = 10 min.

    Se usa como «matriz de entrada preprocesada» de los casos con resultado
    precalculado (diseño de casos de prueba, sesión 9): cada componente de F
    tiene un valor distinto de cero en el cromosoma X = (0, 0, 0, 1).
    """
    servicios = (
        Service("S1", 2, (alt("S1", "V1", "C1", "h0", 0, 100), alt("S1", "V2", "C2", "h1", 10, 100)), 0),
        Service("S2", 1, (alt("S2", "V1", "C1", "h0", 150, 100), alt("S2", "V1", "C2", "h1", 160, 100)), 1),
        Service("S3", 3, (alt("S3", "V1", "C3", "h0", 50, 60), alt("S3", "V2", "C3", "h1", 300, 60)), None),
        Service("S4", 1, (alt("S4", "V2", "C2", "h0", 400, 50), alt("S4", "V3", "C1", "h1", 420, 50)), 0),
    )
    return Instance(
        services=servicios,
        driving_time_prior={"C1": 20.0, "C2": 0.0, "C3": 0.0},
        driving_time_limit={"C1": 110.0, "C2": 260.0, "C3": 60.0},
        weights=dict(PESOS_TESIS),
        norm_refs={"delay": 60.0, "reschedule": 3.0, "idle": 180.0, "workload": 60.0},
    )


# ---------------------------------------------------------------------------
# Generador de instancias aleatorias pequeñas para pruebas de propiedades
# ---------------------------------------------------------------------------
def instancia_aleatoria(semilla: int, n: int = 8, vehiculos: int = 3, conductores: int = 3,
                        k_max: int = 3, horizonte: int = 600, prop_comprometida: float = 0.4,
                        con_vacios: bool = False) -> Instance:
    """Instancia sintética con semilla fija (no son datos de la empresa)."""
    rng = random.Random(semilla)
    servicios = []
    for i in range(n):
        sid = f"S{i + 1:02d}"
        k = 0 if (con_vacios and rng.random() < 0.15) else rng.randint(1, k_max)
        dur = rng.choice([60, 80, 100, 120, 200, 320])
        base = rng.randrange(0, max(1, horizonte - dur), 10)
        alts = []
        for j in range(k):
            inicio = min(base + rng.choice([0, 10, 20, 30]), horizonte - dur)
            alts.append(alt(sid, f"V{rng.randint(1, vehiculos)}", f"C{rng.randint(1, conductores)}",
                            f"h{j}", inicio, dur))
        comp = rng.randrange(k) if (k and rng.random() < prop_comprometida) else None
        servicios.append(Service(sid, rng.randint(1, 3), tuple(alts), comp))
    nb = sum(1 for s in servicios if s.baseline_alt is not None)
    cs = [f"C{j + 1}" for j in range(conductores)]
    return Instance(
        services=tuple(servicios),
        driving_time_prior={c: float(rng.choice([0, 0, 30])) for c in cs},
        driving_time_limit={c: float(rng.choice([240, 360, 480])) for c in cs},
        weights=dict(PESOS_TESIS),
        norm_refs={"delay": 60.0, "reschedule": float(max(1, nb)), "idle": 60.0 * vehiculos, "workload": 60.0},
    )


def cromosoma_aleatorio(servicios, rng: random.Random):
    return tuple(rng.randrange(len(s.admissible)) for s in servicios)


def todos_los_cromosomas(servicios):
    return itertools.product(*[range(len(s.admissible)) for s in servicios])


# ---------------------------------------------------------------------------
# Oráculos independientes
# ---------------------------------------------------------------------------
def se_cruzan(a, b, t_min: float) -> bool:
    """Dos intervalos del MISMO recurso incumplen t_min (ecuación 4)."""
    return not (a.start_time + a.duration + t_min <= b.start_time
                or b.start_time + b.duration + t_min <= a.start_time)


def pares_fuerza_bruta(servicios, t_min: float = 0.0):
    """Conjunto de pares en conflicto por comparación de TODAS las tripletas: O((nk)^2)."""
    tripletas = [(s.service_id, i, a) for s in servicios for i, a in enumerate(s.admissible)]
    pares = set()
    for (s1, i1, a1), (s2, i2, a2) in itertools.combinations(tripletas, 2):
        if s1 == s2:
            continue
        comparten = a1.vehicle_id == a2.vehicle_id or a1.driver_id == a2.driver_id
        if comparten and se_cruzan(a1, a2, t_min):
            pares.add(tuple(sorted(((s1, i1), (s2, i2)))))
    return pares


def oraculo_componentes(cromosoma, instancia: Instance, t_min: float = 0.0):
    """Recalcula Φ, E y los cuatro términos de J directamente desde las asignaciones."""
    servicios = instancia.services_with_options()
    elegidas = [(s, s.admissible[g], g) for s, g in zip(servicios, cromosoma)]

    conflictos = 0
    for (s1, a1, _), (s2, a2, _) in itertools.combinations(elegidas, 2):
        if (a1.vehicle_id == a2.vehicle_id or a1.driver_id == a2.driver_id) and se_cruzan(a1, a2, t_min):
            conflictos += 1

    carga = {}
    for _, a, _ in elegidas:
        carga[a.driver_id] = carga.get(a.driver_id, 0.0) + a.duration
    conductores_en_A = {a.driver_id for s in servicios for a in s.admissible}
    excesos = []
    for c in conductores_en_A:
        total = instancia.driving_time_prior.get(c, 0.0) + carga.get(c, 0.0)
        excesos.append(max(0.0, total - instancia.driving_time_limit.get(c, math.inf)))
    E = sum(excesos)
    sobre_limite = sum(1 for e in excesos if e > 0)

    retraso = sum(max(0.0, a.start_time - s.admissible[s.baseline_alt].start_time)
                  for s, a, _ in elegidas if s.baseline_alt is not None)
    reprog = sum(1 for s, _, g in elegidas if s.baseline_alt is not None and g != s.baseline_alt)

    muerto = 0.0
    por_unidad = {}
    for _, a, _ in elegidas:
        por_unidad.setdefault(a.vehicle_id, []).append((a.start_time, a.start_time + a.duration))
    for intervalos in por_unidad.values():
        intervalos.sort()
        for (_, fin), (ini, _) in zip(intervalos, intervalos[1:]):
            muerto += max(0.0, ini - fin)

    desequilibrio = statistics.pstdev(list(carga.values())) if carga else 0.0

    z = {"delay": retraso, "reschedule": reprog, "idle": muerto, "workload": desequilibrio}
    w, b = instancia.weights, instancia.norm_refs
    J = sum(w[j] * z[j] / b.get(j, 1.0) for j in z if w.get(j, 0.0) > 0.0)
    phi = conflictos + sobre_limite
    return {"V": conflictos, "sobre_limite": sobre_limite, "phi": phi, "E": E, "J": J, **z}


def cota_U(instancia: Instance, horizonte: float) -> float:
    """Cota U de E + J de la sección 3.1.2 de la tesis (requiere H_c0 <= H_cmax)."""
    S = instancia.services_with_options()
    w, b = instancia.weights, instancia.norm_refs
    n = len(S)
    comprometidos = [s for s in S if s.baseline_alt is not None]
    nb = len(comprometidos)
    d_max = max(a.duration for s in S for a in s.admissible)
    delta_max = max([max(a.start_time for a in s.admissible) - s.admissible[s.baseline_alt].start_time
                     for s in comprometidos] or [0.0])
    n_v = len({a.vehicle_id for s in S for a in s.admissible})
    return (n * d_max
            + w["delay"] * nb * delta_max / b["delay"]
            + w["reschedule"] * nb / b["reschedule"]
            + w["idle"] * n_v * horizonte / b["idle"]
            + w["workload"] * n * d_max / (2.0 * b["workload"]))
