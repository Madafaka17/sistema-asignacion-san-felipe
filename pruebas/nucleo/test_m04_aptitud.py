"""M04. Función de pérdida J (ecuación 8) y aptitud F = −[MΦ + E + J] (ecuación 7).

Valores de control de la instancia de control (utilidades.instancia_control), t_min = 10:

  X = (0, 0, 0, 1): S1→(V1,C1,[0,100]); S2→(V1,C1,[150,250]); S3→(V1,C3,[50,110]); S4→(V3,C1,[420,470])
    V = 1 (S1 y S3 comparten V1 y se cruzan); C1: 20 + 250 > 110 → E = 160; Φ = 1 + 1 = 2
    retraso = 20 (S4: 420 − 400); reprogramaciones = 2 (S2, S4); tiempo muerto V1 = 150 − 110 = 40
    desequilibrio = desviación estándar poblacional de (250, 60) = 95
    J = 0.25·(20/60 + 2/3 + 40/180 + 95/60) = 101/144;  F = −(2·10^6 + 160 + 101/144)
  Y = (1, 1, 1, 0): factible (Φ = 0, E = 0); retraso 10; 1 reprogramación; tiempo muerto 230;
    desequilibrio 95; J = 121/144;  F = −121/144
"""
from __future__ import annotations

import copy
import math
import random

import pytest

from core.conflicts import build_conflict_pairs
from core.domain import Instance
from core.fitness import evaluate
from utilidades import cromosoma_aleatorio, instancia_aleatoria, instancia_control, oraculo_componentes

COMP = "Pérdida J y aptitud F (ec. 7 y 8)"
M = 1.0e6


def _evaluar(caso, x, inst=None, big_m=M):
    inst = inst or instancia_control()
    pares = build_conflict_pairs(inst.services_with_options(), 10.0)
    return caso.cronometrar(evaluate, x, inst, pares, big_m=big_m)


COMPONENTES_X = [
    ("M04-01", "conflict_violations", 1, "Pares de Γ realizados, Cv(X) + Cc(X) (sec. 3.1.2)"),
    ("M04-02", "feasibility_violations", 2, "Φ(X) = Cv(X) + Cc(X) + Nexc(X)"),
    ("M04-03", "delay", 20.0, "Retraso: solo cuentan salidas posteriores a la comprometida (S4 +20; S2 −10 → 0)"),
    ("M04-04", "reschedule", 2, "Reprogramaciones: servicios comprometidos que cambian de alternativa (S2, S4)"),
    ("M04-05", "idle", 40.0, "Tiempo muerto: huecos entre servicios consecutivos de una unidad (V1: 150 − 110)"),
    ("M04-06", "workload_spread", 95.0, "Desequilibrio: desviación estándar poblacional de las cargas (250, 60)"),
    ("M04-07", "loss", 101 / 144, "J = Σ w_j z_j / b_j con w_j = 0.25"),
    ("M04-08", "fitness", -(2 * M + 160 + 101 / 144), "F = −(MΦ + E + J) con M = 10^6"),
]


@pytest.mark.parametrize("ident,atributo,esperado,descripcion", COMPONENTES_X, ids=[c[0] for c in COMPONENTES_X])
def test_m04_componentes_precalculados(caso, ident, atributo, esperado, descripcion):
    caso.definir(ident, COMP, "Resultado precalculado a mano", "instancia de control, X = (0, 0, 0, 1)",
                 esperado, descripcion)
    b = _evaluar(caso, (0, 0, 0, 1))
    obs = getattr(b, atributo)
    caso.observar(obs, tolerancia=1e-9)
    assert math.isclose(obs, esperado, rel_tol=0, abs_tol=1e-9)


def test_m04_09_solucion_factible(caso):
    caso.definir("M04-09", COMP, "Resultado precalculado a mano", "instancia de control, Y = (1, 1, 1, 0)",
                 -121 / 144, "Para una solución factible F = −J (Φ = 0 y E = 0; C3 justo en su límite)")
    b = _evaluar(caso, (1, 1, 1, 0))
    caso.observar(b.fitness, tolerancia=1e-9)
    assert b.is_feasible and b.driving_time_excess == 0.0
    assert math.isclose(b.fitness, -121 / 144, abs_tol=1e-9)


def test_m04_10_pesos_nulos_excluyen_termino(caso):
    caso.definir("M04-10", COMP, "Partición: pesos activos / inactivos", "X = (0, 0, 0, 1) con w_idle = 0",
                 0.25 * (20 / 60 + 2 / 3 + 95 / 60), "Un término con w_j = 0 no contribuye a J")
    base = instancia_control()
    pesos = dict(base.weights, idle=0.0)
    inst = Instance(base.services, base.driving_time_prior, base.driving_time_limit, pesos, base.norm_refs)
    b = _evaluar(caso, (0, 0, 0, 1), inst)
    caso.observar(b.loss, tolerancia=1e-9)
    assert math.isclose(b.loss, 0.25 * (20 / 60 + 2 / 3 + 95 / 60), abs_tol=1e-9)


def test_m04_11_referencia_ausente_vale_uno(caso):
    caso.definir("M04-11", COMP, "Valor por defecto de b_j", "X = (0, 0, 0, 1) sin b_workload",
                 0.25 * (20 / 60 + 2 / 3 + 40 / 180 + 95 / 1), "Si falta la referencia de normalización se usa b_j = 1")
    base = instancia_control()
    refs = {k: v for k, v in base.norm_refs.items() if k != "workload"}
    inst = Instance(base.services, base.driving_time_prior, base.driving_time_limit, base.weights, refs)
    b = _evaluar(caso, (0, 0, 0, 1), inst)
    caso.observar(b.loss, tolerancia=1e-9)
    assert math.isclose(b.loss, 0.25 * (20 / 60 + 2 / 3 + 40 / 180 + 95), abs_tol=1e-9)


def test_m04_12_igual_al_oraculo(caso):
    caso.definir("M04-12", COMP, "Oráculo independiente (300 instancias × 10 cromosomas)",
                 "n = 10, |A_s| ≤ 3, t_min = 0", 0.0,
                 "Φ, E, J y F coinciden con el recálculo directo desde las asignaciones")
    rng = random.Random(5)
    peor = 0.0
    for semilla in range(300):
        inst = instancia_aleatoria(500 + semilla, n=10)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios)
        for _ in range(10):
            x = cromosoma_aleatorio(servicios, rng)
            b = caso.cronometrar(evaluate, x, inst, pares)
            o = oraculo_componentes(x, inst)
            f_oraculo = -(M * o["phi"] + o["E"] + o["J"])
            peor = max(peor, abs(b.feasibility_violations - o["phi"]), abs(b.loss - o["J"]),
                       abs(b.fitness - f_oraculo), abs(b.workload_spread - o["workload"]),
                       abs(b.idle - o["idle"]), abs(b.delay - o["delay"]))
    caso.observar(peor, tolerancia=1e-6)
    assert peor <= 1e-6


def test_m04_13_funcion_pura(caso):
    caso.definir("M04-13", COMP, "Determinismo y ausencia de efectos secundarios",
                 "instancia de control evaluada 100 veces", 1,
                 "Misma entrada, misma salida; la instancia no se modifica")
    inst = instancia_control()
    antes = copy.deepcopy(inst)
    pares = build_conflict_pairs(inst.services_with_options(), 10.0)
    salidas = {caso.cronometrar(evaluate, (0, 0, 0, 1), inst, pares) for _ in range(100)}
    caso.observar(len(salidas))
    assert len(salidas) == 1 and inst == antes


def test_m04_14_factible_si_y_solo_si_phi_cero(caso):
    caso.definir("M04-14", COMP, "Enumeración completa", "instancia de control, los 16 cromosomas", 0,
                 "is_feasible es verdadero exactamente cuando Φ = 0 (y entonces E = 0)")
    inst = instancia_control()
    pares = build_conflict_pairs(inst.services_with_options(), 10.0)
    errores = 0
    for x in ((a, b, c, d) for a in (0, 1) for b in (0, 1) for c in (0, 1) for d in (0, 1)):
        r = caso.cronometrar(evaluate, x, inst, pares)
        errores += int(r.is_feasible != (r.feasibility_violations == 0))
        errores += int(r.is_feasible and r.driving_time_excess != 0.0)
    caso.observar(errores)
    assert errores == 0
