"""A08. Validador independiente de las restricciones duras (validador.py)."""
from __future__ import annotations

import ast
import random

from conftest import RAIZ
from generador_sintetico import construir_instancia
from modelo import Instancia, Servicio, evaluar, pares_en_conflicto
from utilidades import PESOS, alt, instancia_aleatoria, instancia_control, metricas, programa_aleatorio
from validador import contar_incumplimientos

COMP = "Validador independiente (validador.py)"


def test_a08_01_no_depende_del_modelo(caso):
    caso.definir("A08-01", COMP, "Revisión estática del código (árbol sintáctico)", "validador.py", "sin importar modelo",
                 "El validador no importa los pares en conflicto ni la función de aptitud del modelo")
    arbol = caso.cronometrar(ast.parse, (RAIZ / "validador.py").read_text(encoding="utf8"))
    modulos = {n.module for n in ast.walk(arbol) if isinstance(n, ast.ImportFrom)} | \
              {a.name for n in ast.walk(arbol) if isinstance(n, ast.Import) for a in n.names}
    caso.observar(sorted(m for m in modulos if m), margen=None)
    assert not ({"modelo", "reparacion", "genetico", "metodos"} & modulos)


def test_a08_02_control(caso):
    caso.definir("A08-02", COMP, "Resultado precalculado", "instancia de control; X = (0, 0, 0, 1) e Y = (1, 1, 1, 0)",
                 (2, 0), "X tiene un cruce y un conductor excedido; Y no tiene incumplimientos")
    inst = instancia_control()
    s = inst.servicios_con_opciones()
    obs = (caso.cronometrar(contar_incumplimientos, [0, 0, 0, 1], s, inst, 10.0),
           caso.cronometrar(contar_incumplimientos, [1, 1, 1, 0], s, inst, 10.0))
    caso.observar(obs, margen=0)
    assert obs == (2, 0)


def test_a08_03_par_con_dos_recursos_cuenta_una_vez(caso):
    caso.definir("A08-03", COMP, "Partición: comparten unidad y conductor", "S1 = (V1, C1, [0, 60]); S2 = (V1, C1, [30, 90])",
                 1, "Un par que comparte unidad y conductor es un solo incumplimiento")
    inst = Instancia(servicios=(Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 60),)),
                                Servicio("S2", 1, (alt("S2", "V1", "C1", 30, 60),))),
                     limite_conduccion={"C1": 600.0}, pesos=dict(PESOS))
    obs = caso.cronometrar(contar_incumplimientos, [0, 0], inst.servicios_con_opciones(), inst, 0.0)
    caso.observar(obs)
    assert obs == 1


def test_a08_04_igual_al_modelo_y_al_oraculo(caso):
    caso.definir("A08-04", COMP, "Oráculo cruzado (3000 programaciones aleatorias)",
                 "300 instancias aleatorias × 10 programaciones; transición 10", 0,
                 "El validador coincide con evaluar() del modelo y con el cálculo directo de las pruebas")
    rng = random.Random(21)
    diferencias = 0
    for semilla in range(300):
        inst = instancia_aleatoria(semilla, n=rng.randint(3, 12), k_max=4)
        s = inst.servicios_con_opciones()
        pares = pares_en_conflicto(s, 10.0)
        for _ in range(10):
            p = programa_aleatorio(s, rng)
            v = caso.cronometrar(contar_incumplimientos, p, s, inst, 10.0)
            diferencias += int(v != evaluar(p, inst, pares).incumplimientos or v != metricas(p, inst, 10.0)["incumplimientos"])
    caso.observar(diferencias)
    assert diferencias == 0


def test_a08_05_programacion_oculta_valida(caso):
    caso.definir("A08-05", COMP, "Datos construidos: programación oculta del generador",
                 "instancias sintéticas n ∈ {7, …, 224}, semillas 101 a 120", 0,
                 "La programación oculta, factible por construcción, no tiene incumplimientos según el validador")
    total = 0
    for n in (7, 14, 28, 56, 112, 224):
        for semilla in range(101, 121):
            inst, d = construir_instancia(n, semilla)
            total += caso.cronometrar(contar_incumplimientos, list(d.opcion_oculta), inst.servicios_con_opciones(),
                                      inst, d.transicion)
    caso.observar(total)
    assert total == 0
