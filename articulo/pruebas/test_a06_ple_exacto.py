"""A06. Programación lineal entera con objetivo sustituto y método exacto con cortes tangentes (metodos.py).

Oráculo: enumeración completa de las programaciones de instancias pequeñas (n ≤ 7, |A_s| ≤ 3) con el cálculo
independiente de utilidades.metricas. El sustituto reemplaza el desequilibrio D por la carga máxima.
"""
from __future__ import annotations

import random

import pytest

from metodos import exacto, ple_sustituto
from modelo import Instancia, Servicio, pares_en_conflicto
from utilidades import PESOS, alt, instancia_aleatoria, metricas, optimo_fuerza_bruta

COMP = "PLE sustituto y método exacto (metodos.py)"
T = 10.0
HORIZONTE = 600.0


def _instancias_factibles(cantidad=20):
    salida, semilla = [], 0
    while len(salida) < cantidad:
        inst = instancia_aleatoria(1000 + semilla, n=random.Random(semilla).randint(4, 7), k_max=3)
        semilla += 1
        if optimo_fuerza_bruta(inst, T) is not None:
            salida.append(inst)
    return salida


_FACTIBLES = None


def factibles():
    global _FACTIBLES
    if _FACTIBLES is None:
        _FACTIBLES = _instancias_factibles()
    return _FACTIBLES


def _infactible():
    """Dos servicios con una sola alternativa cada uno, superpuestas en la misma unidad: ninguna programación es
    factible."""
    return Instancia(servicios=(Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 100),)),
                                Servicio("S2", 1, (alt("S2", "V1", "C2", 50, 100),))),
                     conduccion_previa={}, limite_conduccion={"C1": 600.0, "C2": 600.0}, pesos=dict(PESOS),
                     referencias={"retraso": 60.0, "reprogramacion": 1.0, "tiempo_muerto": 60.0, "desequilibrio": 60.0})


def test_a06_01_ple_optimo_del_sustituto(caso):
    caso.definir("A06-01", COMP, "Oráculo: enumeración completa (20 instancias factibles)",
                 "n ∈ {4, …, 7}; |A_s| ≤ 3; transición 10; horizonte 600", 0.0,
                 "La PLE alcanza el mínimo del objetivo sustituto (carga máxima en lugar de D)")
    peor = 0.0
    for inst in factibles():
        pares = pares_en_conflicto(inst.servicios_con_opciones(), T)
        prog, estado = caso.cronometrar(ple_sustituto, inst, pares, HORIZONTE)
        _, optimo = optimo_fuerza_bruta(inst, T, clave="sustituto")
        peor = max(peor, abs(metricas(prog, inst, T)["sustituto"] - optimo))
        assert estado == "Optimal"
    caso.observar(peor, tolerancia=1e-6)
    assert peor <= 1e-6


def test_a06_02_ple_respeta_restricciones(caso):
    caso.definir("A06-02", COMP, "Oráculo: validación independiente (20 instancias factibles)",
                 "las mismas 20 instancias", 0,
                 "La programación de la PLE no tiene conflictos ni conductores sobre su límite")
    incumplimientos = 0
    for inst in factibles():
        pares = pares_en_conflicto(inst.servicios_con_opciones(), T)
        prog, _ = caso.cronometrar(ple_sustituto, inst, pares, HORIZONTE)
        incumplimientos += metricas(prog, inst, T)["incumplimientos"]
    caso.observar(incumplimientos)
    assert incumplimientos == 0


def test_a06_03_ple_sin_solucion(caso):
    caso.definir("A06-03", COMP, "Partición: instancia sin programación factible",
                 "2 servicios de una alternativa superpuestos en V1", ("Infeasible", "ninguna programación válida"),
                 "Si no hay programación factible, la PLE lo informa en su estado y no entrega una programación válida "
                 "(con CBC devuelve los valores del solucionador, que el validador rechaza)")
    inst = _infactible()
    prog, estado = caso.cronometrar(ple_sustituto, inst, pares_en_conflicto(inst.servicios_con_opciones(), T),
                                    HORIZONTE)
    invalida = prog is None or metricas(prog, inst, T)["incumplimientos"] > 0
    caso.observar((estado, "ninguna programación válida" if invalida else "programación válida",
                   "None" if prog is None else f"devuelve {prog}"), margen=None)
    assert estado == "Infeasible" and invalida


def test_a06_04_exacto_igual_al_optimo_enumerado(caso):
    caso.definir("A06-04", COMP, "Oráculo: enumeración completa (20 instancias factibles)",
                 "las mismas 20 instancias; tolerancia relativa 10^{−7} (la del método)", 0.0,
                 "El método exacto devuelve el mínimo de J con el desequilibrio verdadero y lo certifica; su cota "
                 "inferior no supera a J más la tolerancia del método")
    peor = 0.0
    for inst in factibles():
        pares = pares_en_conflicto(inst.servicios_con_opciones(), T)
        prog, info = caso.cronometrar(exacto, inst, pares, HORIZONTE)
        _, optimo = optimo_fuerza_bruta(inst, T, clave="J")
        J = metricas(prog, inst, T)["J"]
        peor = max(peor, abs(J - optimo) / max(1.0, abs(optimo)))
        assert info["certificado"] and info["cota"] <= info["J"] + 1e-7 * max(1.0, abs(info["J"]))
        assert metricas(prog, inst, T)["incumplimientos"] == 0
    caso.observar(peor, tolerancia=1e-7)
    assert peor <= 1e-7


def test_a06_05_horizonte_igual_al_ultimo_fin(caso):
    caso.definir("A06-05", COMP, "Valor límite del horizonte (cota de las variables de inicio y fin)",
                 "horizonte = fin de la alternativa más tardía y ese valor − 1",
                 "mismo óptimo; luego, ninguna alternativa elegida termina después del horizonte",
                 "Con el horizonte igual al fin más tardío se obtiene el óptimo; con un minuto menos, el modelo excluye "
                 "en silencio las alternativas que terminan después (precondición: horizonte ≥ fin de toda alternativa)")
    inst = factibles()[0]
    pares = pares_en_conflicto(inst.servicios_con_opciones(), T)
    ultimo = max(a.fin for s in inst.servicios_con_opciones() for a in s.alternativas)
    prog, estado = caso.cronometrar(ple_sustituto, inst, pares, ultimo)
    prog2, estado2 = caso.cronometrar(ple_sustituto, inst, pares, ultimo - 1)
    _, optimo = optimo_fuerza_bruta(inst, T, clave="sustituto")
    servicios = inst.servicios_con_opciones()
    tardias = 0 if prog2 is None else sum(1 for s, g in zip(servicios, prog2) if s.alternativas[g].fin > ultimo - 1)
    caso.observar((estado, estado2, f"{tardias} alternativas elegidas después del horizonte"),
                  margen=abs(metricas(prog, inst, T)["sustituto"] - optimo))
    assert estado == "Optimal" and abs(metricas(prog, inst, T)["sustituto"] - optimo) <= 1e-6
    assert (estado2 == "Optimal" and tardias == 0) or estado2 == "Infeasible"


@pytest.mark.xfail(strict=True, raises=TypeError,
                   reason="Anomalía A-B1: exacto() falla con TypeError cuando no obtiene ninguna solución entera")
def test_a06_06_exacto_sin_solucion_entera(caso):
    caso.definir("A06-06", COMP, "Partición: sin solución entera (instancia infactible)",
                 "2 servicios de una alternativa superpuestos en V1", "(None, información) sin error",
                 "Se esperaría el mismo trato que da ple_sustituto: devolver la ausencia de programación sin "
                 "detener el experimento")
    inst = _infactible()
    try:
        prog, info = caso.cronometrar(exacto, inst, pares_en_conflicto(inst.servicios_con_opciones(), T), HORIZONTE)
    except TypeError as exc:
        caso.observar(f"TypeError: {exc}", margen=None)
        raise
    caso.observar((prog, info.get("certificado")), margen=None)
    assert prog is None and info["certificado"] is False
