"""Utilidades de las pruebas del código del artículo.

Contiene constructores de instancias y ORÁCULOS INDEPENDIENTES: cálculos de referencia escritos de nuevo,
por fuerza bruta, que solo importan las clases de datos de modelo.py (Alternativa, Servicio, Instancia) y
nunca las funciones bajo prueba. Si oráculo y código compartieran lógica, un error común pasaría inadvertido.
"""
from __future__ import annotations

import itertools
import math
import random

from modelo import Alternativa, Instancia, Servicio

PESOS = {"retraso": 0.25, "reprogramacion": 0.25, "tiempo_muerto": 0.25, "desequilibrio": 0.25}
M = 1e6
TOL = 1e-9


def alt(sid, vehiculo, conductor, inicio, duracion, franja="h0"):
    """Atajo para una alternativa admisible (vehículo, conductor, salida) del servicio sid."""
    return Alternativa(sid, vehiculo, conductor, franja, float(inicio), float(duracion))


# ---------------------------------------------------------------------------------------------------------
# Instancia de control (valores esperados calculados a mano, ver test_a02_evaluacion.py)
# ---------------------------------------------------------------------------------------------------------
def instancia_control() -> Instancia:
    """Cuatro servicios, tres unidades y tres conductores; transición de 10 min.

    Es la misma instancia de control de la suite del núcleo de la tesis, escrita con las clases del artículo.
    """
    servicios = (
        Servicio("S1", 2, (alt("S1", "V1", "C1", 0, 100), alt("S1", "V2", "C2", 10, 100, "h1")), 0),
        Servicio("S2", 1, (alt("S2", "V1", "C1", 150, 100), alt("S2", "V1", "C2", 160, 100, "h1")), 1),
        Servicio("S3", 3, (alt("S3", "V1", "C3", 50, 60), alt("S3", "V2", "C3", 300, 60, "h1")), None),
        Servicio("S4", 1, (alt("S4", "V2", "C2", 400, 50), alt("S4", "V3", "C1", 420, 50, "h1")), 0),
    )
    return Instancia(servicios=servicios,
                     conduccion_previa={"C1": 20.0, "C2": 0.0, "C3": 0.0},
                     limite_conduccion={"C1": 110.0, "C2": 260.0, "C3": 60.0},
                     pesos=dict(PESOS),
                     referencias={"retraso": 60.0, "reprogramacion": 3.0, "tiempo_muerto": 180.0,
                                  "desequilibrio": 60.0})


# ---------------------------------------------------------------------------------------------------------
# Generador de instancias aleatorias pequeñas (pruebas de propiedades y fuerza bruta)
# ---------------------------------------------------------------------------------------------------------
def instancia_aleatoria(semilla: int, n: int = 6, vehiculos: int = 3, conductores: int = 3, k_max: int = 3,
                        horizonte: int = 600, prop_comprometida: float = 0.4, con_previa: bool = True,
                        limites=(240, 360, 480)) -> Instancia:
    """Instancia sintética con semilla fija (no son datos de la empresa)."""
    rng = random.Random(semilla)
    servicios = []
    for i in range(n):
        sid = f"S{i + 1:02d}"
        k = rng.randint(1, k_max)
        dur = rng.choice([60, 80, 100, 120, 200])
        base = rng.randrange(0, max(1, horizonte - dur), 10)
        alts = []
        for j in range(k):
            inicio = min(base + rng.choice([0, 10, 20, 30]), horizonte - dur)
            alts.append(alt(sid, f"V{rng.randint(1, vehiculos)}", f"C{rng.randint(1, conductores)}", inicio, dur,
                            f"h{j}"))
        comp = rng.randrange(k) if rng.random() < prop_comprometida else None
        servicios.append(Servicio(sid, rng.randint(1, 3), tuple(alts), comp))
    nb = sum(1 for s in servicios if s.comprometida is not None)
    cs = [f"C{j + 1}" for j in range(conductores)]
    return Instancia(
        servicios=tuple(servicios),
        conduccion_previa={c: float(rng.choice([0, 0, 30])) if con_previa else 0.0 for c in cs},
        limite_conduccion={c: float(rng.choice(limites)) for c in cs},
        pesos=dict(PESOS),
        referencias={"retraso": 60.0, "reprogramacion": float(max(1, nb)), "tiempo_muerto": 60.0 * vehiculos,
                     "desequilibrio": 60.0},
    )


def programa_aleatorio(servicios, rng: random.Random):
    return [rng.randrange(len(s.alternativas)) for s in servicios]


def todos_los_programas(servicios):
    return itertools.product(*[range(len(s.alternativas)) for s in servicios])


# ---------------------------------------------------------------------------------------------------------
# Oráculos independientes
# ---------------------------------------------------------------------------------------------------------
def se_cruzan(a, b, transicion: float) -> bool:
    """Dos intervalos del MISMO recurso incumplen la transición mínima."""
    return not (a.inicio + a.duracion + transicion <= b.inicio or b.inicio + b.duracion + transicion <= a.inicio)


def comparten(a, b) -> bool:
    return a.vehiculo == b.vehiculo or a.conductor == b.conductor


def pares_fuerza_bruta(servicios, transicion: float = 0.0) -> set:
    """Pares en conflicto por comparación de TODAS las alternativas de servicios distintos: O((nk)^2)."""
    lista = [(i, a, x) for i, s in enumerate(servicios) for a, x in enumerate(s.alternativas)]
    pares = set()
    for (i, a, x), (j, b, y) in itertools.combinations(lista, 2):
        if i != j and comparten(x, y) and se_cruzan(x, y, transicion):
            pares.add(((i, a), (j, b)) if i < j else ((j, b), (i, a)))
    return pares


def metricas(programa, instancia: Instancia, transicion: float, solo_asignados: bool = False) -> dict:
    """Recalcula conflictos, excesos y los cuatro términos de J directamente desde las asignaciones."""
    servicios = [s for s in instancia.servicios if s.alternativas]
    elegidas = [(s, s.alternativas[int(g)], int(g)) for s, g in zip(servicios, programa)]
    conflictos = sum(1 for (_, x, _), (_, y, _) in itertools.combinations(elegidas, 2)
                     if comparten(x, y) and se_cruzan(x, y, transicion))
    carga = {}
    for _, a, _ in elegidas:
        carga[a.conductor] = carga.get(a.conductor, 0.0) + a.duracion
    exceso, excedidos = 0.0, 0
    for c, x in carga.items():
        total = instancia.conduccion_previa.get(c, 0.0) + x
        limite = instancia.limite_conduccion.get(c, math.inf)
        if total > limite + TOL:
            excedidos += 1
            exceso += total - limite
    retraso = sum(max(0.0, a.inicio - s.alternativas[s.comprometida].inicio)
                  for s, a, _ in elegidas if s.comprometida is not None)
    reprogramados = sum(1 for s, _, g in elegidas if s.comprometida is not None and g != s.comprometida)
    por_unidad = {}
    for _, a, _ in elegidas:
        por_unidad.setdefault(a.vehiculo, []).append((a.inicio, a.inicio + a.duracion))
    muerto = 0.0
    for intervalos in por_unidad.values():
        intervalos.sort()
        for (_, fin), (ini, _) in zip(intervalos, intervalos[1:]):
            muerto += max(0.0, ini - fin)
    if solo_asignados:
        cargas = list(carga.values())
    else:
        elegibles = {a.conductor for s in servicios for a in s.alternativas}
        cargas = [carga.get(c, 0.0) for c in elegibles]
    if cargas:
        media = sum(cargas) / len(cargas)
        desequilibrio = math.sqrt(sum((x - media) ** 2 for x in cargas) / len(cargas))
    else:
        desequilibrio = 0.0
    w, b = instancia.pesos, instancia.referencias
    z = {"retraso": retraso, "reprogramacion": reprogramados, "tiempo_muerto": muerto,
         "desequilibrio": desequilibrio}
    J = sum(w[k] * z[k] / b[k] for k in z)
    carga_max = max([carga.get(c, 0.0) for c in {a.conductor for s in servicios for a in s.alternativas}] or [0.0])
    sustituto = (w["retraso"] * retraso / b["retraso"] + w["reprogramacion"] * reprogramados / b["reprogramacion"]
                 + w["tiempo_muerto"] * muerto / b["tiempo_muerto"] + w["desequilibrio"] * carga_max / b["desequilibrio"])
    return {"conflictos": conflictos, "excedidos": excedidos, "incumplimientos": conflictos + excedidos,
            "exceso": exceso, "retraso": retraso, "reprogramados": reprogramados, "tiempo_muerto": muerto,
            "desequilibrio": desequilibrio, "J": J, "aptitud": -(M * (conflictos + excedidos) + exceso + J),
            "sustituto": sustituto, "carga": carga}


def optimo_fuerza_bruta(instancia: Instancia, transicion: float, clave: str = "J"):
    """Mínimo de `clave` (J o sustituto) entre las programaciones factibles; None si no hay ninguna."""
    servicios = [s for s in instancia.servicios if s.alternativas]
    mejor = None
    for p in todos_los_programas(servicios):
        m = metricas(p, instancia, transicion)
        if m["incumplimientos"] == 0 and (mejor is None or m[clave] < mejor[1] - 1e-12):
            mejor = (list(p), m[clave])
    return mejor


def emparejamiento_maximo_fuerza_bruta(n: int, aristas: set) -> int:
    """Tamaño del emparejamiento máximo de un grafo bipartito i -> j por búsqueda exhaustiva (n pequeño)."""
    sucesores = {i: sorted(j for (a, j) in aristas if a == i) for i in range(n)}
    mejor = 0

    def buscar(i, usados, tam):
        nonlocal mejor
        if tam + (n - i) <= mejor:
            return
        if i == n:
            mejor = max(mejor, tam)
            return
        for j in sucesores[i]:
            if j not in usados:
                buscar(i + 1, usados | {j}, tam + 1)
        buscar(i + 1, usados, tam)

    buscar(0, frozenset(), 0)
    return mejor


# ---------------------------------------------------------------------------------------------------------
# Comparación de corridas nuevas con las publicadas (resultados/*.csv)
# ---------------------------------------------------------------------------------------------------------
CAMPOS_ENTEROS = ("incumplimientos", "validador", "reprogramados", "vehiculos", "conductores")
CAMPOS_REALES = ("J", "retraso", "tiempo_muerto", "desequilibrio")


def comparar_fila(f, r, tol=1e-9):
    """True si la corrida nueva f repite la publicada r (enteros iguales, reales con tolerancia relativa)."""
    if any(int(f[c]) != int(r[c]) for c in CAMPOS_ENTEROS):
        return False
    if any(abs(float(f[c]) - float(r[c])) > tol * max(1.0, abs(float(r[c]))) for c in CAMPOS_REALES):
        return False
    if f["metodo"] == "EXACTO":
        a = dict(x.split("=") for x in f["extra"].split(";"))
        b = dict(x.split("=") for x in r["extra"].split(";"))
        if a["certificado"] != b["certificado"] or a["iteraciones"] != b["iteraciones"]:
            return False
        if abs(float(a["cota"]) - float(b["cota"])) > tol * max(1.0, abs(float(b["cota"]))):
            return False
    return True


def comparar(nuevas, publicadas):
    """(filas comparadas, filas distintas, mayor diferencia relativa en J) entre corridas nuevas y publicadas."""
    pub = {(r["metodo"], int(r["semilla"])): r for r in publicadas}
    distintas, peor = 0, 0.0
    for f in nuevas:
        r = pub[(f["metodo"], int(f["semilla"]))]
        distintas += int(not comparar_fila(f, r))
        peor = max(peor, abs(float(f["J"]) - float(r["J"])) / max(1.0, abs(float(r["J"]))))
    return len(nuevas), distintas, peor
