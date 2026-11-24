"""M08. Criterios de parada del AG (generaciones, saturación, tiempo) y presupuesto de la búsqueda tabú."""
from __future__ import annotations

import pytest

from core.conflicts import build_conflict_pairs
from core.repair import build_conflict_index, repair_targeted
from core.scheduler import GAConfig, run
from generador_sanfelipe import construir_instancia
from metodos import resolver_tabu, resolver_voraz

COMP = "Criterios de parada del AG (sec. 3.4.8)"


@pytest.mark.parametrize("ident,generaciones", [("M08-01", 1), ("M08-02", 25)], ids=["M08-01", "M08-02"])
def test_m08_numero_de_generaciones(caso, ident, generaciones):
    caso.definir(ident, COMP, "Valor límite del número de generaciones" if generaciones == 1 else "Partición: G típico",
                 f"G = {generaciones}, sin saturación ni límite de tiempo; n = 14", generaciones,
                 "El AG ejecuta exactamente G generaciones cuando no hay otro criterio activo")
    inst, meta = construir_instancia(14, 101)
    h = caso.cronometrar(run, inst, GAConfig(population_size=20, num_generations=generaciones,
                                            min_transition=meta.t_min, random_seed=1)).best_fitness_by_generation
    caso.observar(len(h))
    assert len(h) == generaciones


def test_m08_03_saturacion(caso):
    caso.definir("M08-03", COMP, "Criterio de saturación (v2: k = 20)", "n = 112, G = 200, k = 20, semilla 1",
                 20, "El AG se detiene tras k generaciones seguidas sin cambio de la mejor aptitud, contadas desde "
                     "la generación que fijó ese valor (PyGAD 3.7.0, utils/engine.py, criterio saturate_k)")
    inst, meta = construir_instancia(112, 101)
    cfg = GAConfig(population_size=100, num_generations=200, crossover_probability=0.80, mutation_probability=0.10,
                   tournament_size=3, elitism_fraction=0.10, min_transition=meta.t_min, random_seed=1,
                   mutation_scope="chromosome", repair_mode="targeted", repair_initial=True, stop_saturation=20)
    h = caso.cronometrar(run, inst, cfg).best_fitness_by_generation
    iguales = 1                                   # valores finales iguales en el historial por generación
    while iguales < len(h) and h[-iguales - 1] == h[-1]:
        iguales += 1
    # Si el valor final proviene de la población inicial, todas las generaciones registradas son "sin cambio";
    # si lo fijó una generación, esa generación no cuenta como estancada (corrección del oráculo, anomalía A-03).
    sin_cambio = iguales if iguales == len(h) else iguales - 1
    caso.observar(sin_cambio)
    assert len(h) < 200 and sin_cambio == 20


def test_m08_04_limite_de_tiempo(caso):
    caso.definir("M08-04", COMP, "Valor límite del tiempo máximo", "t_límite = 0 s; G = 200; n = 56", 1,
                 "Con el límite de tiempo agotado el AG termina tras la primera generación")
    inst, meta = construir_instancia(56, 101)
    h = caso.cronometrar(run, inst, GAConfig(population_size=50, num_generations=200, min_transition=meta.t_min,
                                            random_seed=1, time_limit=0.0)).best_fitness_by_generation
    caso.observar(len(h))
    assert len(h) == 1


@pytest.mark.parametrize("ident,presupuesto", [("M08-05", 1), ("M08-06", 100), ("M08-07", 5050)],
                         ids=["M08-05", "M08-06", "M08-07"])
def test_m08_presupuesto_tabu(caso, ident, presupuesto):
    caso.definir(ident, "Búsqueda tabú: presupuesto de evaluaciones (sec. 3.1.6)",
                 "Valor límite" if presupuesto == 1 else "Partición de equivalencia",
                 f"presupuesto = {presupuesto} evaluaciones; n = 28, semilla 3", f"≤ {presupuesto}",
                 "La búsqueda tabú nunca supera el presupuesto de evaluaciones de F")
    inst, meta = construir_instancia(28, 102)
    pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
    mejor, evals = caso.cronometrar(resolver_tabu, inst, pares, meta.t_min, 3, presupuesto=presupuesto)
    caso.observar(evals, margen=max(0, evals - presupuesto))
    assert evals <= presupuesto
    if presupuesto == 1:                              # solo la evaluación de la solución inicial
        servicios = inst.services_with_options()
        inicial = repair_targeted(resolver_voraz(inst, meta.t_min), servicios, build_conflict_index(servicios, pares),
                                  inst.driving_time_prior, inst.driving_time_limit)
        assert mejor == inicial


def test_m08_08_tabu_sin_mejora(caso):
    caso.definir("M08-08", "Búsqueda tabú: presupuesto de evaluaciones (sec. 3.1.6)", "Criterio de estancamiento (v2: 2 000)",
                 "sin_mejora = 300 evaluaciones; presupuesto = 20 000; n = 14", "< 20 000",
                 "La búsqueda se detiene antes del presupuesto si no mejora en el número fijado de evaluaciones")
    inst, meta = construir_instancia(14, 101)
    pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
    _, evals = caso.cronometrar(resolver_tabu, inst, pares, meta.t_min, 1, presupuesto=20000, sin_mejora=300)
    caso.observar(evals, margen=None)
    assert evals < 20000
