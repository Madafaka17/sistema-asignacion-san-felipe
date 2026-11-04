"""Generador de instancias sintéticas para las pruebas de concepto del capítulo 3.

Las instancias NO son datos de la Empresa de Transportes San Felipe: reproducen
su estructura (servicios, vehículos, conductores, alternativas de salida y
límites de conducción) con los parámetros fijados en PROTOCOLO.md.

Cada instancia es factible por construcción: primero se genera una programación
oculta sin conflictos ni exceso de horas y luego se añaden alternativas
admisibles adicionales, que sí pueden entrar en conflicto entre sí.
"""
from __future__ import annotations

import random
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from core.domain import AdmissibleTriple, Instance, Service  # noqa: E402

TURNO_MIN = 600
T_MIN = 10.0


@dataclass(frozen=True)
class MetaInstancia:
    n: int
    semilla: int
    vehiculos: tuple[str, ...]
    conductores: tuple[str, ...]
    t_min: float
    opcion_oculta: tuple[int, ...]   # índice, por servicio, de la alternativa de la programación oculta


def recursos_para(n: int) -> int:
    return max(2, round(n / 3))


def construir_instancia(n: int, semilla: int) -> tuple[Instance, MetaInstancia]:
    rng = random.Random(semilla)
    m = recursos_para(n)
    vehiculos = [f"V{i + 1:02d}" for i in range(m)]
    conductores = [f"C{i + 1:02d}" for i in range(m)]

    # 1) Programación oculta: cada vehículo i recorre una secuencia sin traslapes,
    #    conducida por el conductor i, respetando t_min entre servicios.
    conteos = [n // m + (1 if i < n % m else 0) for i in range(m)]
    ocultos = []  # (vehículo, conductor, inicio, duración)
    for i, cnt in enumerate(conteos):
        if cnt == 0:
            continue
        duraciones = [rng.randint(40, 120) for _ in range(cnt)]
        ocupado = sum(duraciones) + T_MIN * (cnt - 1)
        holgura = max(0.0, TURNO_MIN - ocupado)
        pesos = [rng.random() for _ in range(cnt + 1)]
        tot = sum(pesos)
        huecos = [holgura * p / tot for p in pesos]
        t = huecos[0]
        for j, d in enumerate(duraciones):
            ocultos.append((vehiculos[i], conductores[i], round(t, 1), float(d)))
            t += d + T_MIN + huecos[j + 1]

    ocultos.sort(key=lambda o: (o[2], o[0]))
    carga_oculta = {c: 0.0 for c in conductores}
    for _, c, _, d in ocultos:
        carga_oculta[c] += d

    # 2) Alternativas admisibles: la oculta + (k-1) adicionales.
    servicios = []
    opcion_oculta = []
    n_base = 0
    for idx, (v0, c0, t0, d) in enumerate(ocultos):
        sid = f"S{idx + 1:03d}"
        k = rng.randint(2, 5)
        opciones = [(v0, c0, t0)]
        intentos = 0
        while len(opciones) < k and intentos < 50:
            intentos += 1
            v = rng.choice(vehiculos)
            c = rng.choice(conductores)
            delta = rng.choice([-30, -15, 0, 15, 30])
            t = min(max(0.0, t0 + delta), TURNO_MIN - d)
            if (v, c, t) not in opciones:
                opciones.append((v, c, t))
        rng.shuffle(opciones)
        pos_oculta = opciones.index((v0, c0, t0))
        admisibles = tuple(
            AdmissibleTriple(sid, v, c, f"h{j}", float(t), d)
            for j, (v, c, t) in enumerate(opciones)
        )
        base = None
        if rng.random() < 0.40:
            base = rng.randrange(len(admisibles))
            n_base += 1
        servicios.append(Service(sid, priority=rng.randint(1, 3), admissible=admisibles, baseline_alt=base))
        opcion_oculta.append(pos_oculta)

    limite = {c: carga_oculta[c] + rng.randint(20, 120) for c in conductores}
    instancia = Instance(
        services=tuple(servicios),
        driving_time_prior={c: 0.0 for c in conductores},
        driving_time_limit=limite,
        weights={"delay": 0.25, "reschedule": 0.25, "idle": 0.25, "workload": 0.25},
        norm_refs={"delay": 60.0, "reschedule": float(max(1, n_base)),
                   "idle": 60.0 * m, "workload": 60.0},
    )
    meta = MetaInstancia(n, semilla, tuple(vehiculos), tuple(conductores), T_MIN, tuple(opcion_oculta))
    return instancia, meta
