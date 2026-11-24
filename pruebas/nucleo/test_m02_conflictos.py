"""M02. Conjunto de pares en conflicto Γ (ecuaciones 4 y 5) e índice de conducción (ecuación 6)."""
from __future__ import annotations

import os
import subprocess
import sys

import pytest

from core.conflicts import build_conflict_pairs, build_driving_time_index
from core.domain import Service
from generador_sanfelipe import construir_instancia
from utilidades import alt, instancia_aleatoria, pares_fuerza_bruta

COMP = "Pares en conflicto Γ (ec. 4 y 5)"


def _dos(a1, a2):
    return (Service("S1", 1, (a1,)), Service("S2", 1, (a2,)))


CASOS = [
    # id, técnica, entrada, servicios, t_min, esperado, descripción
    ("M02-01", "Partición: comparten unidad y se cruzan", "S1=(V1,C1,[0,60]); S2=(V1,C2,[30,90]); t_min=0",
     _dos(alt("S1", "V1", "C1", "h", 0, 60), alt("S2", "V1", "C2", "h", 30, 60)), 0.0, 1,
     "Dos servicios en la misma unidad con intervalos superpuestos forman un par"),
    ("M02-02", "Partición: comparten conductor y se cruzan", "S1=(V1,C1,[0,60]); S2=(V2,C1,[30,90]); t_min=0",
     _dos(alt("S1", "V1", "C1", "h", 0, 60), alt("S2", "V2", "C1", "h", 30, 60)), 0.0, 1,
     "El mismo conductor no puede atender dos servicios superpuestos"),
    ("M02-03", "Partición: recursos distintos", "S1=(V1,C1,[0,60]); S2=(V2,C2,[0,60]); t_min=0",
     _dos(alt("S1", "V1", "C1", "h", 0, 60), alt("S2", "V2", "C2", "h", 0, 60)), 0.0, 0,
     "Sin recurso compartido no hay conflicto aunque coincida el horario"),
    ("M02-04", "Partición: comparten unidad y conductor", "S1=(V1,C1,[0,60]); S2=(V1,C1,[30,90]); t_min=0",
     _dos(alt("S1", "V1", "C1", "h", 0, 60), alt("S2", "V1", "C1", "h", 30, 60)), 0.0, 1,
     "Compartir dos recursos genera un único par (sin duplicados)"),
    ("M02-06", "Valor límite: holgura = t_min", "S1=(V1,C1,[0,60]); S2=(V1,C1,[70,130]); t_min=10",
     _dos(alt("S1", "V1", "C1", "h", 0, 60), alt("S2", "V1", "C1", "h", 70, 60)), 10.0, 0,
     "Una holgura exactamente igual a t_min es admisible (desigualdad no estricta)"),
    ("M02-07", "Valor límite: holgura = t_min − 1", "S1=(V1,C1,[0,60]); S2=(V1,C1,[69,129]); t_min=10",
     _dos(alt("S1", "V1", "C1", "h", 0, 60), alt("S2", "V1", "C1", "h", 69, 60)), 10.0, 1,
     "Un minuto menos que t_min ya es conflicto"),
    ("M02-08", "Valor límite: t_min = 0 e intervalos contiguos", "S1=(V1,C1,[0,60]); S2=(V1,C1,[60,120]); t_min=0",
     _dos(alt("S1", "V1", "C1", "h", 0, 60), alt("S2", "V1", "C1", "h", 60, 60)), 0.0, 0,
     "Con t_min = 0, terminar exactamente cuando empieza el otro no es conflicto"),
    ("M02-09", "Partición: un intervalo contiene al otro", "S1=(V1,C1,[0,200]); S2=(V2,C1,[50,110]); t_min=0",
     _dos(alt("S1", "V1", "C1", "h", 0, 200), alt("S2", "V2", "C1", "h", 50, 60)), 0.0, 1,
     "La contención también es superposición"),
]


@pytest.mark.parametrize("ident,tecnica,entrada,servicios,t_min,esperado,descripcion", CASOS,
                         ids=[c[0] for c in CASOS])
def test_m02_casos_elementales(caso, ident, tecnica, entrada, servicios, t_min, esperado, descripcion):
    caso.definir(ident, COMP, tecnica, entrada, esperado, descripcion)
    pares = caso.cronometrar(build_conflict_pairs, servicios, t_min)
    caso.observar(len(pares))
    assert len(pares) == esperado


def test_m02_05_alternativas_del_mismo_servicio(caso):
    caso.definir("M02-05", COMP, "Partición: alternativas de un mismo servicio",
                 "S1 con dos alternativas (V1,C1,[0,60]) y (V1,C1,[30,90])", 0,
                 "Dos alternativas del mismo servicio nunca se eligen juntas y no forman par")
    servicios = (Service("S1", 1, (alt("S1", "V1", "C1", "h0", 0, 60), alt("S1", "V1", "C1", "h1", 30, 60))),)
    pares = caso.cronometrar(build_conflict_pairs, servicios, 0.0)
    caso.observar(len(pares))
    assert pares == ()


def test_m02_10_igual_a_fuerza_bruta(caso):
    caso.definir("M02-10", COMP, "Oráculo independiente por fuerza bruta (200 instancias aleatorias)",
                 "n ∈ {6..15}, |A_s| ≤ 4, t_min ∈ {0, 10}", 0,
                 "El agrupamiento por recurso produce exactamente el mismo conjunto que comparar todas las tripletas")
    diferencias = 0
    for semilla in range(100):
        inst = instancia_aleatoria(1000 + semilla, n=6 + semilla % 10, k_max=4, vehiculos=3, conductores=4)
        servicios = inst.services_with_options()
        for t_min in (0.0, 10.0):
            pares = caso.cronometrar(build_conflict_pairs, servicios, t_min)
            diferencias += len(set(pares) ^ pares_fuerza_bruta(servicios, t_min))
    caso.observar(diferencias)
    assert diferencias == 0


def test_m02_11_orden_canonico(caso):
    caso.definir("M02-11", COMP, "Propiedad estructural en la instancia oficial más grande",
                 "instancia sintética n = 112, semilla 101, t_min = 10", 0,
                 "La tupla está ordenada, sin duplicados y cada par guarda (s, a) < (t, b)")
    inst, meta = construir_instancia(112, 101)
    pares = caso.cronometrar(build_conflict_pairs, inst.services_with_options(), meta.t_min)
    errores = int(list(pares) != sorted(pares)) + (len(pares) - len(set(pares))) \
        + sum(1 for p, q in pares if not p < q)
    caso.observar(errores)
    assert errores == 0 and len(pares) > 0


_SCRIPT = (
    "import hashlib, sys; sys.path[:0] = [r'{raiz}', r'{gen}'];"
    "from generador_sanfelipe import construir_instancia;"
    "from core.conflicts import build_conflict_pairs;"
    "i, m = construir_instancia(56, 102);"
    "print(hashlib.sha256(repr(build_conflict_pairs(i.services_with_options(), m.t_min)).encode()).hexdigest())"
)


def test_m02_12_independiente_de_pythonhashseed(caso):
    from conftest import RAIZ
    caso.definir("M02-12", COMP, "Regresión del error de orden por hash (README del núcleo)",
                 "mismo cálculo en 3 procesos con PYTHONHASHSEED = 0, 1 y 4242", 1,
                 "El orden de Γ no depende de la aleatorización de hash del intérprete")
    from rutas import SANFELIPE
    script = _SCRIPT.format(raiz=RAIZ, gen=SANFELIPE)
    huellas = set()
    for hs in ("0", "1", "4242"):
        entorno = dict(os.environ, PYTHONHASHSEED=hs)
        salida = caso.cronometrar(subprocess.run, [sys.executable, "-c", script], env=entorno,
                                  capture_output=True, text=True, check=True)
        huellas.add(salida.stdout.strip())
    caso.observar(len(huellas))
    assert len(huellas) == 1


def test_m02_13_indice_de_conduccion(caso):
    caso.definir("M02-13", "Índice de horas de conducción (ec. 6)", "Oráculo por conteo",
                 "instancia sintética n = 28, semilla 103", 0,
                 "Cada tripleta aparece una vez bajo su conductor con su duración d_sa")
    inst, _ = construir_instancia(28, 103)
    servicios = inst.services_with_options()
    indice = caso.cronometrar(build_driving_time_index, servicios)
    esperado = sorted((a.driver_id, s.service_id, i, a.duration) for s in servicios for i, a in enumerate(s.admissible))
    obtenido = sorted((c, sid, i, d) for c, filas in indice.items() for sid, i, d in filas)
    diferencias = len(set(esperado) ^ set(obtenido)) + abs(len(esperado) - len(obtenido))
    caso.observar(diferencias)
    assert diferencias == 0


def test_m02_14_orden_canonico_de_las_claves(caso):
    caso.definir("M02-14", COMP, "Valor límite: orden lexicográfico distinto del orden de inserción",
                 "S9=(V1,C1,[0,60]) insertado antes que S10=(V1,C1,[30,90]); t_min=0", "((S10, 0), (S9, 0))",
                 "Cada par de Γ se guarda una sola vez con la clave lexicográficamente menor primero, aunque su "
                 "servicio se haya registrado después (forma canónica que fija el orden de la reparación)")
    servicios = (Service("S9", 1, (alt("S9", "V1", "C1", "h", 0, 60),)),
                 Service("S10", 1, (alt("S10", "V1", "C1", "h", 30, 60),)))
    pares = caso.cronometrar(build_conflict_pairs, servicios, 0.0)
    esperado = ((("S10", 0), ("S9", 0)),)
    caso.observar([list(map(list, p)) for p in pares], margen=0 if pares == esperado else 1)
    assert pares == esperado
