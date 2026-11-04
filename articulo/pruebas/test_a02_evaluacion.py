"""A02. Función objetivo J y aptitud F = −(M·Φ + E + J) (modelo.py: componentes y evaluar).

Valores de la instancia de control calculados a mano (transición de 10 min):
  X = (0, 0, 0, 1): conflictos 1 (S1 y S3 en V1); C1 = 20 + 250 = 270 > 110 → 1 conductor excedido, E = 160;
                    retraso 20 (S4 sale 20 min después de su compromiso); reprogramados 2 (S2 y S4);
                    tiempo muerto 40 (V1: [0,100], [50,110], [150,250]); cargas de los conductores elegibles
                    (C1, C2, C3) = (250, 0, 60) → D = 10·√1022/3; J = 11/36 + √1022/72.
  Y = (1, 1, 1, 0): sin incumplimientos (C3 queda exactamente en su límite de 60); retraso 10; reprogramados 1;
                    tiempo muerto 230 (V2: [10,110], [300,360], [400,450]); cargas (0, 250, 60) → misma D;
                    J = 4/9 + √1022/72.
Con SOLO_ASIGNADOS = True la desviación se mide solo entre conductores con servicios: D = 95, y J vale 101/144 y
121/144, los mismos valores de la instancia de control de la tesis.
"""
from __future__ import annotations

import math
import random

import modelo
from modelo import evaluar, pares_en_conflicto
from utilidades import (M, instancia_aleatoria, instancia_control, metricas, programa_aleatorio, alt)

COMP = "Función objetivo J y aptitud F (modelo.py)"
RAIZ_1022 = math.sqrt(1022.0)
X, Y = [0, 0, 0, 1], [1, 1, 1, 0]


def _eval(programa, inst=None, t=10.0, **kw):
    inst = inst or instancia_control()
    pares = pares_en_conflicto(inst.servicios_con_opciones(), t)
    return evaluar(programa, inst, pares, **kw)


def test_a02_01_incumplimientos_de_X(caso):
    caso.definir("A02-01", COMP, "Resultado precalculado a mano", "instancia de control, X = (0, 0, 0, 1)",
                 (1, 1, 160.0), "Conflictos, conductores excedidos y exceso E de X")
    e = caso.cronometrar(_eval, X)
    obs = (e.conflictos, e.conductores_excedidos, e.exceso)
    caso.observar(obs, margen=abs(e.exceso - 160.0))
    assert obs == (1, 1, 160.0) and e.incumplimientos == 2


def test_a02_02_componentes_de_X(caso):
    esperado = (20.0, 2, 40.0, 10 * RAIZ_1022 / 3)
    caso.definir("A02-02", COMP, "Resultado precalculado a mano", "instancia de control, X = (0, 0, 0, 1)",
                 "(20, 2, 40, 10·√1022/3)", "Retraso, reprogramados, tiempo muerto y desequilibrio de X")
    e = caso.cronometrar(_eval, X)
    margen = max(abs(a - b) for a, b in zip((e.retraso, e.reprogramados, e.tiempo_muerto, e.desequilibrio), esperado))
    caso.observar((e.retraso, e.reprogramados, e.tiempo_muerto, round(e.desequilibrio, 6)), tolerancia=1e-9,
                  margen=margen)
    assert margen <= 1e-9


def test_a02_03_J_y_aptitud_de_X(caso):
    J = 11 / 36 + RAIZ_1022 / 72
    caso.definir("A02-03", COMP, "Resultado precalculado a mano", "instancia de control, X = (0, 0, 0, 1)",
                 round(-(2 * M + 160 + J), 6), "F = −(M·2 + 160 + J) con J = 11/36 + √1022/72")
    e = caso.cronometrar(_eval, X)
    margen = max(abs(e.J - J), abs(e.aptitud + 2 * M + 160 + J))
    caso.observar(round(e.aptitud, 6), tolerancia=1e-9, margen=margen)
    assert margen <= 1e-9


def test_a02_04_Y_factible_en_el_limite(caso):
    J = 4 / 9 + RAIZ_1022 / 72
    caso.definir("A02-04", COMP, "Valor límite: conductor exactamente en su límite (C3 = 60 de 60)",
                 "instancia de control, Y = (1, 1, 1, 0)", round(-J, 6),
                 "Y no tiene incumplimientos y F = −J con J = 4/9 + √1022/72")
    e = caso.cronometrar(_eval, Y)
    margen = abs(e.aptitud + J)
    caso.observar(round(e.aptitud, 6), tolerancia=1e-9, margen=margen)
    assert e.incumplimientos == 0 and e.exceso == 0.0 and (e.retraso, e.reprogramados, e.tiempo_muerto) == (10.0, 1, 230.0)
    assert margen <= 1e-9


def test_a02_05_solo_asignados_reproduce_la_tesis(caso, monkeypatch):
    caso.definir("A02-05", COMP, "Partición: medida del desequilibrio (SOLO_ASIGNADOS = True)",
                 "instancia de control, X e Y", "(101/144, 121/144)",
                 "Midiendo D solo entre conductores con servicios se obtienen los J de la instancia de control "
                 "de la tesis")
    monkeypatch.setattr(modelo, "SOLO_ASIGNADOS", True)
    jx, jy = caso.cronometrar(_eval, X).J, caso.cronometrar(_eval, Y).J
    margen = max(abs(jx - 101 / 144), abs(jy - 121 / 144))
    caso.observar((round(jx, 9), round(jy, 9)), tolerancia=1e-9, margen=margen)
    assert margen <= 1e-9


def test_a02_06_desequilibrio_incluye_conductores_sin_carga(caso):
    caso.definir("A02-06", COMP, "Partición: conductor elegible sin servicios",
                 "2 servicios de 60 min a C1; C2 elegible sin carga", 60.0,
                 "Con SOLO_ASIGNADOS = False, D se mide sobre todos los conductores elegibles: cargas (120, 0) → 60")
    from modelo import Instancia, Servicio
    inst = Instancia(servicios=(Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60), alt("S1", "V2", "C2", 0, 60, "h1"))),
                                Servicio("S2", 1, (alt("S2", "V1", "C1", 100, 60),))),
                     limite_conduccion={"C1": 600.0, "C2": 600.0}, conduccion_previa={},
                     pesos={"retraso": 0.25, "reprogramacion": 0.25, "tiempo_muerto": 0.25, "desequilibrio": 0.25},
                     referencias={"retraso": 60.0, "reprogramacion": 1.0, "tiempo_muerto": 60.0, "desequilibrio": 60.0})
    e = caso.cronometrar(_eval, [0, 0], inst)
    caso.observar(e.desequilibrio, margen=abs(e.desequilibrio - 60.0))
    assert abs(e.desequilibrio - 60.0) <= 1e-9


def test_a02_07_evaluar_igual_al_oraculo(caso):
    caso.definir("A02-07", COMP, "Oráculo independiente (3000 programaciones aleatorias)",
                 "300 instancias (n ≤ 12, con conducción previa) × 10 programaciones; transición = 10", 0,
                 "Todos los componentes y la aptitud coinciden con el cálculo directo")
    rng = random.Random(11)
    peor = 0.0
    distintos = 0
    for semilla in range(300):
        inst = instancia_aleatoria(semilla, n=rng.randint(3, 12), k_max=4)
        servicios = inst.servicios_con_opciones()
        pares = pares_en_conflicto(servicios, 10.0)
        for _ in range(10):
            p = programa_aleatorio(servicios, rng)
            e = caso.cronometrar(evaluar, p, inst, pares)
            o = metricas(p, inst, 10.0)
            distintos += int((e.conflictos, e.conductores_excedidos, e.reprogramados)
                             != (o["conflictos"], o["excedidos"], o["reprogramados"]))
            for a, b in ((e.exceso, o["exceso"]), (e.retraso, o["retraso"]), (e.tiempo_muerto, o["tiempo_muerto"]),
                         (e.desequilibrio, o["desequilibrio"]), (e.J, o["J"]), (e.aptitud, o["aptitud"])):
                peor = max(peor, abs(a - b) / max(1.0, abs(b)))
    caso.observar(distintos, tolerancia=1e-12, margen=peor)
    assert distintos == 0 and peor <= 1e-12


def test_a02_08_penalidad_ordena_por_factibilidad(caso):
    caso.definir("A02-08", COMP, "Propiedad (200 instancias aleatorias)",
                 "200 instancias × 30 programaciones; M = 10^6", 0,
                 "Toda programación con menos incumplimientos tiene mayor aptitud (M domina a E + J)")
    rng = random.Random(3)
    violaciones = 0
    for semilla in range(200):
        inst = instancia_aleatoria(semilla, n=8, k_max=3)
        servicios = inst.servicios_con_opciones()
        pares = pares_en_conflicto(servicios, 10.0)
        evals = [caso.cronometrar(evaluar, programa_aleatorio(servicios, rng), inst, pares) for _ in range(30)]
        for a in evals:
            for b in evals:
                if a.incumplimientos < b.incumplimientos and not a.aptitud > b.aptitud:
                    violaciones += 1
    caso.observar(violaciones)
    assert violaciones == 0
