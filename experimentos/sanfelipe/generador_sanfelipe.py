"""Generador de instancias sintéticas del caso San Felipe (terminal de Soritor).

Cada instancia representa un turno de operación: servicios de viaje redondo desde
Soritor hacia Moyobamba o Tarapoto, unidades que salen según su turno en la cola,
conductores fijos y reemplazos autorizados. Los parámetros están en PROTOCOLO.md
(secciones 2 a 4).

LAS INSTANCIAS NO SON DATOS DE LA EMPRESA. Son datos sintéticos generados con
semilla fija; los valores de referencia (tiempos de ida, razón de conductores por
unidad activa, asientos) son declarados y están pendientes de validación.

Cada instancia es factible por construcción: primero se genera una programación
oculta sin cruces ni exceso de conducción y luego se añaden alternativas
admisibles, que sí pueden entrar en conflicto entre sí. El resultado usa las mismas
estructuras de datos del prototipo (core.domain), de modo que los cuatro
candidatos del capítulo III se ejecutan sin ningún cambio.
"""
from __future__ import annotations

import random
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from core.domain import AdmissibleTriple, Instance, Service  # noqa: E402

# --- Valores declarados (PROTOCOLO.md, sección 2) ---------------------------
IDA_MIN = {"MOY": 30, "TAR": 150}            # minutos solo ida desde Soritor (R01, R02)
NOMBRE_RUTA = {"MOY": "Soritor–Moyobamba", "TAR": "Soritor–Tarapoto"}
UNIDADES_ACTIVAS_DIA = 37                    # unidades que salen por día (declarado)
CONDUCTORES_LISTA = 44                       # conductores en la lista histórica
ASIENTOS = 16                                # leído en 4 manifiestos

# --- Condiciones conservadas de la Tabla 17 (sección 4) ---------------------
TURNO_MIN = 600
T_MIN = 10.0
PROPORCION_COMPROMETIDA = 0.40
HOLGURA_LIMITE = (20, 120)
ALTERNATIVAS = (2, 5)

# --- Supuestos del generador (sección 3) ------------------------------------
ESTANCIA = (20, 40)                          # minutos en destino antes de volver
P_TARAPOTO = 0.5
INICIO_UNIDAD = (0, 60)
ESPERA_COLA = (0, 30)
P_CONDUCTOR_FIJO = 0.7
REEMPLAZOS = (1, 2)
DEMORAS = (0, 10, 20)
HORA_INICIO_TURNO = 6 * 60                   # solo para presentar horas (06:00)


@dataclass(frozen=True)
class MetaSanFelipe:
    """Información del caso que los candidatos no ven, usada para describir las
    instancias y calcular los indicadores operativos complementarios."""
    n: int
    semilla: int
    t_min: float
    unidades: tuple[str, ...]
    conductores: tuple[str, ...]
    conductor_fijo: dict            # unidad -> conductor fijo (solo unidades con conductor fijo)
    autorizados: dict               # unidad -> tupla de conductores autorizados
    ruta: dict                      # servicio -> "MOY" | "TAR"
    salida_nominal: dict            # servicio -> minuto del turno en que sale según la cola
    unidad_en_cola: dict            # servicio -> unidad que corresponde por la cola
    opcion_oculta: tuple[int, ...]  # índice de la alternativa de la programación oculta, por servicio
    oculta: tuple                   # (servicio, unidad, conductor, inicio, duración)


def hhmm(minuto: float) -> str:
    t = int(round(HORA_INICIO_TURNO + minuto))
    return f"{t // 60:02d}:{t % 60:02d}"


def _duracion(rng: random.Random, ruta: str) -> int:
    return 2 * IDA_MIN[ruta] + rng.randint(*ESTANCIA)


def _libre(intervalos, ini, fin, t_min) -> bool:
    return all(fin + t_min <= a or b + t_min <= ini for a, b in intervalos)


def construir_instancia(n: int, semilla: int) -> tuple[Instance, MetaSanFelipe]:
    rng = random.Random(semilla)

    # 1) Programación oculta: cadenas de viajes redondos por unidad activa.
    cadenas = []                                        # por unidad: [(ruta, inicio, duración)]
    total = 0
    while total < n:
        cadena = []
        t = float(rng.randint(*INICIO_UNIDAD))
        while True:
            primera = "TAR" if rng.random() < P_TARAPOTO else "MOY"
            elegido = None
            for ruta in (primera, "MOY" if primera == "TAR" else "TAR"):
                d = _duracion(rng, ruta)
                if t + d <= TURNO_MIN:
                    elegido = (ruta, t, float(d))
                    break
            if elegido is None:
                break
            cadena.append(elegido)
            t = elegido[1] + elegido[2] + T_MIN + rng.randint(*ESPERA_COLA)
        if not cadena:
            continue
        cadena = cadena[: n - total]
        cadenas.append(cadena)
        total += len(cadena)

    m = len(cadenas)
    unidades = [f"US{i + 1:02d}" for i in range(m)]
    c_total = max(m, round(m * CONDUCTORES_LISTA / UNIDADES_ACTIVAS_DIA))
    conductores = [f"CS{i + 1:02d}" for i in range(c_total)]

    # 2) Conductores en la programación oculta: fijos y del resto de la plantilla.
    fijo = {}
    libres = list(conductores)
    for u in unidades:
        if rng.random() < P_CONDUCTOR_FIJO:
            fijo[u] = libres.pop(0)
    pool = libres                                        # conductores sin unidad fija
    ocupacion = {c: [] for c in conductores}
    viajes = []                                          # (inicio, unidad, ruta, duración)
    for u, cadena in zip(unidades, cadenas):
        for ruta, ini, d in cadena:
            viajes.append((ini, u, ruta, d))
    viajes.sort(key=lambda v: (v[0], v[1]))
    oculta = []                                          # (unidad, conductor, ruta, inicio, duración)
    for ini, u, ruta, d in viajes:
        if u in fijo:
            c = fijo[u]
        else:
            candidatos = [c for c in pool if _libre(ocupacion[c], ini, ini + d, T_MIN)]
            if not candidatos:                           # no ocurre (ver docstring de PROTOCOLO)
                raise RuntimeError("sin conductor libre en la programación oculta")
            c = rng.choice(candidatos)
        ocupacion[c].append((ini, ini + d))
        oculta.append((u, c, ruta, ini, d))

    # 3) Pares autorizados: conductor fijo o conductores de la programación oculta, más reemplazos.
    autorizados = {}
    for u in unidades:
        base = [fijo[u]] if u in fijo else sorted({c for (uu, c, *_r) in oculta if uu == u})
        otros = [c for c in conductores if c not in base]
        extra = rng.sample(otros, min(len(otros), rng.randint(*REEMPLAZOS)))
        autorizados[u] = tuple(base + sorted(extra))

    # 4) Alternativas admisibles por servicio.
    ocupacion_unidad = {u: [] for u in unidades}
    for u, c, ruta, ini, d in oculta:
        ocupacion_unidad[u].append((ini, ini + d))

    servicios, opcion_oculta = [], []
    ruta_de, nominal, en_cola, oculta_meta = {}, {}, {}, []
    carga_oculta = {c: 0.0 for c in conductores}
    n_comprometidos = 0
    for idx, (u0, c0, ruta, t0, d) in enumerate(oculta):
        sid = f"S{idx + 1:03d}"
        carga_oculta[c0] += d
        en_terminal = [u for u in unidades if u != u0
                       and all(not (a <= t0 < b) for a, b in ocupacion_unidad[u])]
        siguiente = rng.choice(en_terminal) if en_terminal else None
        unidades_alt = [u0] + ([siguiente] if siguiente else [])
        producto = [(u, c, t0 + dm) for u in unidades_alt for c in autorizados[u]
                    for dm in DEMORAS if t0 + dm + d <= TURNO_MIN]
        resto = [p for p in producto if p != (u0, c0, t0)]
        k = rng.randint(*ALTERNATIVAS)
        opciones = [(u0, c0, t0)] + rng.sample(resto, min(len(resto), k - 1))
        rng.shuffle(opciones)
        pos = opciones.index((u0, c0, t0))
        admisibles = tuple(AdmissibleTriple(sid, u, c, f"h{j}", float(t), float(d))
                           for j, (u, c, t) in enumerate(opciones))
        base = None
        if rng.random() < PROPORCION_COMPROMETIDA:
            base = rng.randrange(len(admisibles))
            n_comprometidos += 1
        servicios.append(Service(sid, priority=rng.randint(1, 3), admissible=admisibles, baseline_alt=base))
        opcion_oculta.append(pos)
        ruta_de[sid], nominal[sid], en_cola[sid] = ruta, t0, u0
        oculta_meta.append((sid, u0, c0, t0, d))

    limite = {c: carga_oculta[c] + rng.randint(*HOLGURA_LIMITE) for c in conductores}
    instancia = Instance(
        services=tuple(servicios),
        driving_time_prior={c: 0.0 for c in conductores},
        driving_time_limit=limite,
        weights={"delay": 0.25, "reschedule": 0.25, "idle": 0.25, "workload": 0.25},
        norm_refs={"delay": 60.0, "reschedule": float(max(1, n_comprometidos)),
                   "idle": 60.0 * m, "workload": 60.0},
    )
    meta = MetaSanFelipe(n, semilla, T_MIN, tuple(unidades), tuple(conductores), fijo, autorizados,
                         ruta_de, nominal, en_cola, tuple(opcion_oculta), tuple(oculta_meta))
    return instancia, meta
