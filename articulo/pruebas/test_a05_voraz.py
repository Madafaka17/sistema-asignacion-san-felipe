"""A05. Regla voraz de primer ajuste (metodos.voraz)."""
from __future__ import annotations

import random

from generador_sintetico import construir_instancia
from metodos import voraz
from modelo import Instancia, Servicio
from utilidades import PESOS, alt, instancia_aleatoria, se_cruzan, comparten

COMP = "Regla voraz de primer ajuste (metodos.py: voraz)"
REF = {"retraso": 60.0, "reprogramacion": 1.0, "tiempo_muerto": 60.0, "desequilibrio": 60.0}


def _inst(servicios, limites=None):
    conductores = {a.conductor for s in servicios for a in s.alternativas}
    lim = {c: 600.0 for c in conductores}
    lim.update(limites or {})
    return Instancia(servicios=tuple(servicios), conduccion_previa={}, limite_conduccion=lim, pesos=dict(PESOS),
                     referencias=dict(REF))


def test_a05_01_orden_por_salida_y_prioridad(caso):
    caso.definir("A05-01", COMP, "Regla de negocio: orden de atención",
                 "S0 (prioridad 1) y S1 (prioridad 3) con la misma primera salida (100) en (V1, C1)", [1, 0],
                 "En empate de salida se atiende primero el de mayor prioridad, que se queda con su primera opción")
    inst = _inst([Servicio("S0", 1, (alt("S0", "V1", "C1", 100, 50), alt("S0", "V3", "C3", 130, 50, "h1"))),
                  Servicio("S1", 3, (alt("S1", "V1", "C1", 100, 50), alt("S1", "V2", "C2", 120, 50, "h1")))])
    obs = caso.cronometrar(voraz, inst, 10.0)
    caso.observar(obs, margen=0)
    assert obs == [1, 0]


def test_a05_02_primera_alternativa_por_hora(caso):
    caso.definir("A05-02", COMP, "Regla de negocio: primer ajuste por hora de salida",
                 "un servicio con alternativas a 200, 100 y 150, todas libres", [1],
                 "Se elige la alternativa libre de salida más temprana, no la primera de la lista")
    inst = _inst([Servicio("S0", 1, (alt("S0", "V1", "C1", 200, 30), alt("S0", "V1", "C1", 100, 30, "h1"),
                                     alt("S0", "V2", "C2", 150, 30, "h2")))])
    obs = caso.cronometrar(voraz, inst, 10.0)
    caso.observar(obs, margen=0)
    assert obs == [1]


def test_a05_03_sin_opcion_libre_elige_la_de_menos_choques(caso):
    caso.definir("A05-03", COMP, "Regla de negocio: opción de menor daño",
                 "S1 con 3 alternativas que chocan con S0: 2, 1 y 1 choques (salidas 50, 60 y 70)", [0, 1],
                 "Si ninguna alternativa está libre, se elige la de menos choques y, en empate, la más temprana")
    inst = _inst([Servicio("S0", 3, (alt("S0", "V1", "C1", 0, 100),)),
                  Servicio("S1", 1, (alt("S1", "V1", "C1", 50, 30), alt("S1", "V1", "C2", 60, 30, "h1"),
                                     alt("S1", "V2", "C1", 70, 30, "h2")))])
    obs = caso.cronometrar(voraz, inst, 10.0)
    caso.observar(obs, margen=0)
    assert obs == [0, 1]


def test_a05_04_limite_de_conduccion_cuenta_como_choque(caso):
    caso.definir("A05-04", COMP, "Regla de negocio: límite de conducción",
                 "S1 a las 300 con C1 (excede: 100 + 100 > 150) o a las 310 con C2 (libre)", [0, 1],
                 "Una alternativa que excede el límite de su conductor no se considera libre")
    inst = _inst([Servicio("S0", 3, (alt("S0", "V1", "C1", 0, 100),)),
                  Servicio("S1", 1, (alt("S1", "V2", "C1", 300, 100), alt("S1", "V3", "C2", 310, 100, "h1")))],
                 limites={"C1": 150.0})
    obs = caso.cronometrar(voraz, inst, 10.0)
    caso.observar(obs, margen=0)
    assert obs == [0, 1]


def test_a05_05_transicion_exacta_es_libre(caso):
    caso.definir("A05-05", COMP, "Valor límite: holgura = transición",
                 "S0 = [0, 100] y S1 = [110, 160] en (V1, C1); transición 10 y 11", ([0, 0], [0, 1]),
                 "Con holgura igual a la transición la alternativa está libre; con un minuto más de transición, no")
    inst = _inst([Servicio("S0", 3, (alt("S0", "V1", "C1", 0, 100),)),
                  Servicio("S1", 1, (alt("S1", "V1", "C1", 110, 50), alt("S1", "V2", "C2", 200, 50, "h1")))])
    obs = (caso.cronometrar(voraz, inst, 10.0), caso.cronometrar(voraz, inst, 11.0))
    caso.observar(obs, margen=0)
    assert obs == ([0, 0], [0, 1])


def test_a05_06_programacion_valida_y_determinista(caso):
    caso.definir("A05-06", COMP, "Propiedad (300 instancias aleatorias)", "n ≤ 15; |A_s| ≤ 4; dos ejecuciones", 0,
                 "Devuelve un índice válido por servicio y, con la misma instancia, siempre la misma programación")
    errores = 0
    for semilla in range(300):
        inst = instancia_aleatoria(semilla, n=random.Random(semilla).randint(2, 15), k_max=4)
        a = caso.cronometrar(voraz, inst, 10.0)
        b = voraz(inst, 10.0)
        s = inst.servicios_con_opciones()
        errores += int(a != b or len(a) != len(s) or any(not 0 <= g < len(x.alternativas) for g, x in zip(a, s)))
    caso.observar(errores)
    assert errores == 0


def test_a05_07_factible_en_instancias_pequenas_del_caso(caso):
    caso.definir("A05-07", COMP, "Caracterización con el generador del caso",
                 "instancias sintéticas n = 7, semillas 101 a 120", "registro",
                 "Proporción de instancias en que la regla voraz, sin reparación, obtiene una programación sin "
                 "choques entre las alternativas elegidas (se informa; no es un requisito)")
    factibles = 0
    for semilla in range(101, 121):
        inst, d = construir_instancia(7, semilla)
        p = caso.cronometrar(voraz, inst, d.transicion)
        s = inst.servicios_con_opciones()
        elegidas = [x.alternativas[g] for x, g in zip(s, p)]
        choques = sum(1 for i in range(len(elegidas)) for j in range(i + 1, len(elegidas))
                      if comparten(elegidas[i], elegidas[j]) and se_cruzan(elegidas[i], elegidas[j], d.transicion))
        factibles += int(choques == 0)
    caso.observar(f"{factibles} de 20", margen=None)
    assert 0 <= factibles <= 20
