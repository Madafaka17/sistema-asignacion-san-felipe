"""M03. Límite de horas de conducción (ecuación 6) y exceso E(X) de la ecuación 7."""
from __future__ import annotations

import math
import random

import pytest

from core.conflicts import build_conflict_pairs
from core.domain import Instance, Service
from core.fitness import evaluate
from utilidades import alt, cromosoma_aleatorio, instancia_aleatoria, instancia_control, oraculo_componentes

COMP = "Límite de conducción y exceso E (ec. 6 y 7)"


def _un_conductor(previo, limite, duraciones):
    servicios = tuple(Service(f"S{i}", 1, (alt(f"S{i}", f"V{i}", "C1", "h", 300 * i, d),))
                      for i, d in enumerate(duraciones))
    lim = {} if limite is None else {"C1": float(limite)}
    return Instance(services=servicios, driving_time_prior={"C1": float(previo)}, driving_time_limit=lim)


CASOS = [
    ("M03-01", "Valor límite: carga = límite", "H_c0 = 0; d = 100 + 100; H_cmáx = 200", 0, 200, (100, 100), 0.0,
     "Cargar exactamente el límite no genera exceso ni conductor sobre el límite"),
    ("M03-02", "Valor límite: carga = límite + 1", "H_c0 = 0; d = 100 + 101; H_cmáx = 200", 0, 200, (100, 101), 1.0,
     "Un minuto sobre el límite produce E = 1 y un conductor sobre el límite"),
    ("M03-03", "Partición: horas previas del periodo", "H_c0 = 30; d = 100; H_cmáx = 120", 30, 120, (100,), 10.0,
     "Las horas ya conducidas H_c0 se suman a la carga del turno"),
    ("M03-04", "Partición: límite no declarado", "H_c0 = 0; d = 500; sin H_cmáx", 0, None, (500,), 0.0,
     "Un conductor sin límite registrado se trata como límite infinito"),
]


@pytest.mark.parametrize("ident,tecnica,entrada,previo,limite,duraciones,esperado,descripcion", CASOS,
                         ids=[c[0] for c in CASOS])
def test_m03_casos(caso, ident, tecnica, entrada, previo, limite, duraciones, esperado, descripcion):
    caso.definir(ident, COMP, tecnica, entrada, esperado, descripcion)
    inst = _un_conductor(previo, limite, duraciones)
    cromosoma = tuple(0 for _ in duraciones)
    b = caso.cronometrar(evaluate, cromosoma, inst, build_conflict_pairs(inst.services_with_options()))
    caso.observar(b.driving_time_excess)
    assert b.driving_time_excess == esperado
    assert b.overlimit_drivers == (1 if esperado > 0 else 0)


def test_m03_05_instancia_de_control(caso):
    caso.definir("M03-05", COMP, "Resultado precalculado a mano", "instancia de control, X = (0, 0, 0, 1)",
                 160.0, "C1: 20 + 250 − 110 = 160; C3 en su límite exacto (60) no excede; un conductor sobre el límite")
    inst = instancia_control()
    pares = build_conflict_pairs(inst.services_with_options(), 10.0)
    b = caso.cronometrar(evaluate, (0, 0, 0, 1), inst, pares)
    caso.observar(b.driving_time_excess)
    assert b.driving_time_excess == 160.0 and b.overlimit_drivers == 1


def test_m03_06_igual_al_oraculo(caso):
    caso.definir("M03-06", COMP, "Oráculo independiente (300 instancias × 10 cromosomas)",
                 "n = 10, límites ∈ {240, 360, 480}, H_c0 ∈ {0, 30}", 0.0,
                 "E y el número de conductores sobre el límite coinciden con el recálculo directo")
    rng = random.Random(3)
    peor = 0.0
    for semilla in range(300):
        inst = instancia_aleatoria(semilla, n=10)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios)
        for _ in range(10):
            x = cromosoma_aleatorio(servicios, rng)
            b = caso.cronometrar(evaluate, x, inst, pares)
            o = oraculo_componentes(x, inst)
            peor = max(peor, abs(b.driving_time_excess - o["E"]), abs(b.overlimit_drivers - o["sobre_limite"]))
    caso.observar(peor, tolerancia=1e-9)
    assert math.isclose(peor, 0.0, abs_tol=1e-9)
