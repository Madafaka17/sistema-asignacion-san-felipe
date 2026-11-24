"""A07. Búsqueda local de primera mejora y búsqueda tabú (metodos.py: busqueda_local y tabu); envoltorio del AG."""
from __future__ import annotations

import itertools
import random

from generador_sintetico import construir_instancia
from genetico import ConfigAG, ejecutar_ag
from metodos import busqueda_local, genetico, tabu, voraz
from modelo import evaluar, indice_conflictos, pares_en_conflicto
from reparacion import reparar
from utilidades import instancia_aleatoria, metricas, programa_aleatorio

COMP_BL = "Búsqueda local de primera mejora (metodos.py: busqueda_local)"
COMP_TB = "Búsqueda tabú (metodos.py: tabu)"
T = 10.0


def _contexto(inst, t=T):
    pares = pares_en_conflicto(inst.servicios_con_opciones(), t)
    return pares, indice_conflictos(pares)


def _vecinos_por_recurso(servicios):
    """Servicios que comparten alguna unidad o conductor posible (vecindario de los movimientos dobles)."""
    recursos = {}
    for i, s in enumerate(servicios):
        for a in s.alternativas:
            recursos.setdefault(("V", a.vehiculo), set()).add(i)
            recursos.setdefault(("C", a.conductor), set()).add(i)
    vecinos = {i: set() for i in range(len(servicios))}
    for grupo in recursos.values():
        for i in grupo:
            vecinos[i] |= grupo
    return vecinos


def test_a07_01_busqueda_local_no_empeora(caso):
    caso.definir("A07-01", COMP_BL, "Propiedad (100 instancias aleatorias)", "n = 8; |A_s| ≤ 3; inicio aleatorio", 0,
                 "La programación final nunca tiene menor aptitud que la inicial")
    rng = random.Random(2)
    empeoran = 0
    for semilla in range(100):
        inst = instancia_aleatoria(semilla, n=8, k_max=3)
        pares, indice = _contexto(inst)
        p0 = programa_aleatorio(inst.servicios_con_opciones(), rng)
        p1 = caso.cronometrar(busqueda_local, list(p0), inst, pares, indice)
        empeoran += int(metricas(p1, inst, T)["aptitud"] < metricas(p0, inst, T)["aptitud"] - 1e-12)
    caso.observar(empeoran)
    assert empeoran == 0


def test_a07_02_busqueda_local_termina_en_optimo_local(caso):
    caso.definir("A07-02", COMP_BL, "Oráculo: exploración completa del vecindario (60 instancias)",
                 "n = 7; |A_s| ≤ 3; movimientos de 1 servicio y de 2 servicios que comparten recurso", 0,
                 "Al terminar sin límite de tiempo, ningún movimiento simple ni doble del vecindario mejora la aptitud")
    rng = random.Random(4)
    mejorables = 0
    for semilla in range(60):
        inst = instancia_aleatoria(semilla, n=7, k_max=3)
        servicios = inst.servicios_con_opciones()
        pares, indice = _contexto(inst)
        p = caso.cronometrar(busqueda_local, programa_aleatorio(servicios, rng), inst, pares, indice)
        f = metricas(p, inst, T)["aptitud"]
        candidatos = []
        for i, s in enumerate(servicios):
            candidatos += [{i: k} for k in range(len(s.alternativas)) if k != p[i]]
        vecinos = _vecinos_por_recurso(servicios)
        for i in range(len(servicios)):
            for j in sorted(v for v in vecinos[i] if v > i):
                candidatos += [{i: k, j: l} for k, l in itertools.product(range(len(servicios[i].alternativas)),
                                                                          range(len(servicios[j].alternativas)))
                               if (k, l) != (p[i], p[j])]
        for mov in candidatos:
            q = list(p)
            for i, k in mov.items():
                q[i] = k
            if metricas(q, inst, T)["aptitud"] > f + 1e-12:
                mejorables += 1
                break
    caso.observar(mejorables)
    assert mejorables == 0


def test_a07_03_busqueda_local_sin_tiempo(caso):
    caso.definir("A07-03", COMP_BL, "Valor límite: límite de tiempo 0", "n = 8; programación aleatoria; limite = 0",
                 "programación sin cambios", "Con límite 0 la búsqueda devuelve la programación recibida")
    inst = instancia_aleatoria(5, n=8, k_max=3)
    pares, indice = _contexto(inst)
    p0 = programa_aleatorio(inst.servicios_con_opciones(), random.Random(1))
    p1 = caso.cronometrar(busqueda_local, list(p0), inst, pares, indice, limite=0)
    caso.observar("sin cambios" if p1 == p0 else "cambió", margen=None)
    assert p1 == p0


def test_a07_04_tabu_presupuesto_exacto(caso):
    caso.definir("A07-04", COMP_TB, "Valores límite del presupuesto", "n = 28, instancia 101; presupuesto 1, 2, 31, 100 y 5050",
                 [1, 2, 31, 100, 5050], "El número de evaluaciones nunca supera el presupuesto y lo agota si no hay "
                 "otra condición de parada")
    inst, d = construir_instancia(28, 101)
    pares, _ = _contexto(inst, d.transicion)
    obs = [caso.cronometrar(tabu, inst, pares, d.transicion, 1, presupuesto=b)[1]["evaluaciones"]
           for b in (1, 2, 31, 100, 5050)]
    caso.observar(obs, margen=0)
    assert obs == [1, 2, 31, 100, 5050]


def test_a07_05_tabu_parte_del_voraz_reparado(caso):
    caso.definir("A07-05", COMP_TB, "Valor límite: presupuesto = 1 (sin iteraciones)", "n = 56, instancia 102; semilla 1",
                 "reparar(voraz)", "Con una sola evaluación, la búsqueda tabú devuelve el voraz reparado")
    inst, d = construir_instancia(56, 102)
    pares, indice = _contexto(inst, d.transicion)
    prog, info = caso.cronometrar(tabu, inst, pares, d.transicion, 1, presupuesto=1)
    inicial = reparar(voraz(inst, d.transicion), inst, indice=indice)
    caso.observar("igual" if prog == inicial and info["iteraciones"] == 0 else "distinto", margen=None)
    assert prog == inicial and info["iteraciones"] == 0


def test_a07_06_tabu_no_empeora_y_aptitud_consistente(caso):
    caso.definir("A07-06", COMP_TB, "Propiedad (5 tamaños × 3 instancias × 3 semillas)", "n = 7 a 112; presupuesto 5050",
                 0, "La mejor solución nunca es peor que el punto de partida y su aptitud es la informada")
    errores = 0
    for n in (7, 14, 28, 56, 112):
        for semilla_inst in (101, 102, 103):
            inst, d = construir_instancia(n, semilla_inst)
            pares, indice = _contexto(inst, d.transicion)
            f0 = evaluar(reparar(voraz(inst, d.transicion), inst, indice=indice), inst, pares).aptitud
            for s in (1, 2, 3):
                prog, info = caso.cronometrar(tabu, inst, pares, d.transicion, s)
                f = evaluar(prog, inst, pares).aptitud
                errores += int(f < f0 or f != info["aptitud"])
    caso.observar(errores)
    assert errores == 0


def test_a07_07_tabu_reproducible(caso):
    caso.definir("A07-07", COMP_TB, "Reproducibilidad con semilla fija", "n = 56, instancia 103; semilla 4; dos ejecuciones",
                 True, "La misma semilla repite la solución y el número de evaluaciones")
    inst, d = construir_instancia(56, 103)
    pares, _ = _contexto(inst, d.transicion)
    a = caso.cronometrar(tabu, inst, pares, d.transicion, 4)
    b = caso.cronometrar(tabu, inst, pares, d.transicion, 4)
    igual = a[0] == b[0] and a[1]["evaluaciones"] == b[1]["evaluaciones"] and a[1]["aptitud"] == b[1]["aptitud"]
    caso.observar(igual)
    assert igual


def test_a07_08_tabu_parada_por_estancamiento(caso):
    caso.definir("A07-08", COMP_TB, "Partición: con parada sin mejora", "n = 14, instancia 101; sin_mejora = 50",
                 "< 5050 evaluaciones", "Con sin_mejora la búsqueda se detiene antes de agotar el presupuesto")
    inst, d = construir_instancia(14, 101)
    pares, _ = _contexto(inst, d.transicion)
    _, info = caso.cronometrar(tabu, inst, pares, d.transicion, 1, sin_mejora=50)
    caso.observar(info["evaluaciones"], margen=None)
    assert info["evaluaciones"] < 5050


def test_a07_09_envoltorio_del_ag(caso):
    caso.definir("A07-09", "Envoltorio del AG (metodos.py: genetico)",
                 "Equivalencia de interfaces", "n = 14, instancia 102; semilla 2; AG_v2 (100, 200, 20 sin mejora)", True,
                 "metodos.genetico devuelve la programación de ejecutar_ag con la configuración equivalente")
    inst, d = construir_instancia(14, 102)
    a = caso.cronometrar(genetico, inst, d.transicion, 2, poblacion=100, generaciones=200, sin_mejora=20)
    b = ejecutar_ag(inst, d.transicion, ConfigAG(poblacion=100, generaciones=200, generaciones_sin_mejora=20,
                                                 semilla=2)).programacion
    caso.observar(a == b)
    assert a == b
