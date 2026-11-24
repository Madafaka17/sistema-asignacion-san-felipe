"""A01. Modelo: alternativas, servicios con opciones, pares en conflicto e índice de conflictos (modelo.py)."""
from __future__ import annotations

import random

from modelo import Instancia, Servicio, contar_conflictos, indice_conflictos, pares_en_conflicto
from utilidades import alt, instancia_aleatoria, pares_fuerza_bruta, programa_aleatorio, instancia_control

COMP = "Modelo y pares en conflicto (modelo.py)"


def test_a01_01_servicios_con_opciones(caso):
    caso.definir("A01-01", COMP, "Partición de equivalencia (con y sin alternativas)",
                 "3 servicios; S2 sin alternativas", ("S1", "S3"),
                 "Solo los servicios con alternativas entran a la programación")
    inst = Instancia(servicios=(Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60),)), Servicio("S2", 1, ()),
                                Servicio("S3", 1, (alt("S3", "V2", "C2", 0, 60),))))
    obs = tuple(s.id for s in caso.cronometrar(inst.servicios_con_opciones))
    caso.observar(obs, margen=0)
    assert obs == ("S1", "S3")


def test_a01_02_fin_de_la_alternativa(caso):
    caso.definir("A01-02", COMP, "Valor calculado a mano", "inicio = 125, duración = 75", 200.0,
                 "El fin de una alternativa es su salida más su duración")
    obs = caso.cronometrar(lambda: alt("S1", "V1", "C1", 125, 75).fin)
    caso.observar(obs)
    assert obs == 200.0


def test_a01_03_holgura_igual_a_la_transicion(caso):
    caso.definir("A01-03", COMP, "Valor límite: holgura = transición",
                 "S1 = (V1, C1, [0, 60]); S2 = (V1, C2, [70, 130]); transición = 10", 0,
                 "Si la siguiente salida ocurre justo al cumplirse la transición, no hay conflicto")
    servicios = (Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60),)), Servicio("S2", 1, (alt("S2", "V1", "C2", 70, 60),)))
    obs = len(caso.cronometrar(pares_en_conflicto, servicios, 10.0))
    caso.observar(obs)
    assert obs == 0


def test_a01_04_holgura_un_minuto_menor(caso):
    caso.definir("A01-04", COMP, "Valor límite: holgura = transición − 1",
                 "S1 = (V1, C1, [0, 60]); S2 = (V1, C2, [69, 129]); transición = 10", 1,
                 "Un minuto menos que la transición ya es conflicto")
    servicios = (Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60),)), Servicio("S2", 1, (alt("S2", "V1", "C2", 69, 60),)))
    obs = len(caso.cronometrar(pares_en_conflicto, servicios, 10.0))
    caso.observar(obs)
    assert obs == 1


def test_a01_05_sin_recurso_compartido(caso):
    caso.definir("A01-05", COMP, "Partición: recursos distintos",
                 "S1 = (V1, C1, [0, 60]); S2 = (V2, C2, [0, 60])", 0,
                 "Dos servicios simultáneos con unidad y conductor distintos no están en conflicto")
    servicios = (Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60),)), Servicio("S2", 1, (alt("S2", "V2", "C2", 0, 60),)))
    obs = len(caso.cronometrar(pares_en_conflicto, servicios, 10.0))
    caso.observar(obs)
    assert obs == 0


def test_a01_06_comparten_unidad_y_conductor_cuentan_una_vez(caso):
    caso.definir("A01-06", COMP, "Partición: comparten unidad y conductor",
                 "S1 = (V1, C1, [0, 60]); S2 = (V1, C1, [30, 90])", 1,
                 "Un par que comparte los dos recursos aparece una sola vez en el conjunto de pares")
    servicios = (Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60),)), Servicio("S2", 1, (alt("S2", "V1", "C1", 30, 60),)))
    obs = len(caso.cronometrar(pares_en_conflicto, servicios, 0.0))
    caso.observar(obs)
    assert obs == 1


def test_a01_07_alternativas_del_mismo_servicio(caso):
    caso.definir("A01-07", COMP, "Partición: alternativas de un mismo servicio",
                 "S1 con dos alternativas superpuestas en (V1, C1)", 0,
                 "Las alternativas de un mismo servicio nunca forman un par, porque solo se elige una")
    servicios = (Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60), alt("S1", "V1", "C1", 10, 60, "h1"))),)
    obs = len(caso.cronometrar(pares_en_conflicto, servicios, 10.0))
    caso.observar(obs)
    assert obs == 0


def test_a01_08_control_un_solo_par(caso):
    caso.definir("A01-08", COMP, "Resultado precalculado (instancia de control)",
                 "instancia de control; transición = 10", (((0, 0), (2, 0)),),
                 "En la instancia de control solo S1 (h0) y S3 (h0) se cruzan en la unidad V1")
    inst = instancia_control()
    obs = tuple(sorted(caso.cronometrar(pares_en_conflicto, inst.servicios_con_opciones(), 10.0)))
    caso.observar(obs, margen=0)
    assert obs == (((0, 0), (2, 0)),)


def test_a01_09_pares_igual_a_fuerza_bruta(caso):
    caso.definir("A01-09", COMP, "Oráculo independiente por fuerza bruta (200 instancias aleatorias)",
                 "n ∈ {4, …, 12}; |A_s| ≤ 4; transición ∈ {0, 10}", 0,
                 "El conjunto de pares coincide con la comparación de todas las alternativas")
    diferencias = 0
    for semilla in range(200):
        rng = random.Random(semilla)
        inst = instancia_aleatoria(semilla, n=rng.randint(4, 12), k_max=4)
        t = rng.choice([0.0, 10.0])
        servicios = inst.servicios_con_opciones()
        diferencias += int(set(caso.cronometrar(pares_en_conflicto, servicios, t)) != pares_fuerza_bruta(servicios, t))
    caso.observar(diferencias)
    assert diferencias == 0


def test_a01_10_indice_simetrico(caso):
    caso.definir("A01-10", COMP, "Propiedad (100 instancias aleatorias)", "n = 10; |A_s| ≤ 4; transición = 10", 0,
                 "El índice de conflictos es simétrico y contiene exactamente los pares del conjunto")
    errores = 0
    for semilla in range(100):
        servicios = instancia_aleatoria(semilla, n=10, k_max=4).servicios_con_opciones()
        pares = pares_en_conflicto(servicios, 10.0)
        indice = caso.cronometrar(indice_conflictos, pares)
        reconstruido = {(p, q) if p < q else (q, p) for p, vecinos in indice.items() for q in vecinos}
        errores += int(reconstruido != set(pares))
        errores += sum(1 for p, vecinos in indice.items() for q in vecinos if p not in indice.get(q, ()))
    caso.observar(errores)
    assert errores == 0


def test_a01_11_contar_conflictos_igual_a_fuerza_bruta(caso):
    caso.definir("A01-11", COMP, "Oráculo independiente (2000 programaciones aleatorias)",
                 "200 instancias × 10 programaciones; transición = 10", 0,
                 "El número de pares realizados coincide con el conteo directo sobre las alternativas elegidas")
    rng = random.Random(7)
    diferencias = 0
    for semilla in range(200):
        servicios = instancia_aleatoria(semilla, n=10, k_max=4).servicios_con_opciones()
        pares = pares_en_conflicto(servicios, 10.0)
        for _ in range(10):
            p = programa_aleatorio(servicios, rng)
            directo = sum(1 for (i, a), (j, b) in pares_fuerza_bruta(servicios, 10.0) if p[i] == a and p[j] == b)
            diferencias += int(caso.cronometrar(contar_conflictos, p, pares) != directo)
    caso.observar(diferencias)
    assert diferencias == 0
