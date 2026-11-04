"""M07. Operadores del algoritmo genético (sección 3.4): cruce uniforme, mutación, elitismo,
población inicial reparada y configuración entregada a PyGAD (prueba con doble de prueba)."""
from __future__ import annotations

import random
from types import SimpleNamespace
from unittest import mock

import numpy as np

import core.scheduler as planificador
from core.conflicts import build_conflict_pairs
from core.domain import Instance, Service
from core.fitness import evaluate
from core.repair import build_conflict_index, repair_targeted
from core.scheduler import GAConfig, _make_operators, run
from generador_sanfelipe import construir_instancia
from metodos import resolver_ag
from utilidades import alt

COMP = "Operadores del AG (sec. 3.4.4 a 3.4.7)"


def _sin_conflictos(n=20, k=3):
    """Cada alternativa usa una unidad y un conductor exclusivos: la reparación es la identidad."""
    servicios = tuple(Service(f"S{i}", 1, tuple(alt(f"S{i}", f"V{i}_{j}", f"C{i}_{j}", f"h{j}", 10 * j, 30)
                                                for j in range(k))) for i in range(n))
    return servicios, Instance(servicios, {}, {})


def _operadores(pc=1.0, alcance="chromosome", semilla=1):
    servicios, inst = _sin_conflictos()
    pares = build_conflict_pairs(servicios)
    cruce, mutacion, _ = _make_operators(servicios, pares, semilla, pc, alcance, "targeted", inst)
    return servicios, cruce, mutacion


def test_m07_01_cruce_uniforme_hereda_de_los_padres(caso):
    caso.definir("M07-01", COMP, "Propiedad del cruce uniforme", "2 padres aleatorios, 2 000 hijos, 20 genes, p_c = 1",
                 0, "Cada gen del hijo es el gen del padre 1 o el del padre 2 en la misma posición")
    servicios, cruce, _ = _operadores(pc=1.0)
    rng = np.random.default_rng(0)
    padres = rng.integers(0, 3, size=(2, len(servicios)))
    hijos = caso.cronometrar(cruce, padres, (2000, len(servicios)), None)
    errores = 0
    for i, h in enumerate(hijos):
        p1, p2 = padres[i % 2], padres[(i + 1) % 2]
        errores += int(np.sum((h != p1) & (h != p2)))
    caso.observar(errores)
    assert errores == 0


def test_m07_02_pc_cero_copia_padre(caso):
    caso.definir("M07-02", COMP, "Valor límite: p_c = 0", "2 padres aleatorios, 200 hijos", 0,
                 "Sin cruce, cada hijo es copia exacta de su primer padre")
    servicios, cruce, _ = _operadores(pc=0.0)
    padres = np.random.default_rng(1).integers(0, 3, size=(2, len(servicios)))
    hijos = caso.cronometrar(cruce, padres, (200, len(servicios)), None)
    distintos = sum(1 for i, h in enumerate(hijos) if not np.array_equal(h, padres[i % 2]))
    caso.observar(distintos)
    assert distintos == 0


def test_m07_03_frecuencia_de_cruce(caso):
    caso.definir("M07-03", COMP, "Prueba estadística (binomial, 3σ)", "p_c = 0.80; 5 000 hijos de padres opuestos",
                 0.20, "La fracción de hijos que son copia del padre 1 es 1 − p_c")
    servicios, cruce, _ = _operadores(pc=0.8)
    padres = np.array([[0] * len(servicios), [1] * len(servicios)])
    hijos = caso.cronometrar(cruce, padres, (5000, len(servicios)), None)
    copias = sum(1 for i, h in enumerate(hijos) if np.array_equal(h, padres[i % 2]))
    fraccion = copias / 5000
    caso.observar(fraccion, tolerancia=0.02)
    assert abs(fraccion - 0.20) <= 0.02


def test_m07_04_mutacion_un_gen(caso):
    caso.definir("M07-04", COMP, "Valor límite: p_m = 1 (mutación por cromosoma)", "500 hijos de 20 genes", 0,
                 "Cada hijo cambia exactamente un gen, a otra alternativa válida de ese servicio")
    servicios, _, mutacion = _operadores(alcance="chromosome")
    antes = np.random.default_rng(2).integers(0, 3, size=(500, len(servicios)))
    despues = caso.cronometrar(mutacion, antes.copy(), SimpleNamespace(mutation_probability=1.0))
    errores = sum(1 for a, d in zip(antes, despues) if int(np.sum(a != d)) != 1)
    errores += int(np.sum((despues < 0) | (despues > 2)))
    caso.observar(errores)
    assert errores == 0


def test_m07_05_mutacion_nula(caso):
    caso.definir("M07-05", COMP, "Valor límite: p_m = 0", "500 hijos de 20 genes", 0, "Sin mutación los hijos no cambian")
    servicios, _, mutacion = _operadores(alcance="chromosome")
    antes = np.random.default_rng(3).integers(0, 3, size=(500, len(servicios)))
    despues = caso.cronometrar(mutacion, antes.copy(), SimpleNamespace(mutation_probability=0.0))
    cambios = int(np.sum(antes != despues))
    caso.observar(cambios)
    assert cambios == 0


def test_m07_06_mutacion_por_gen(caso):
    caso.definir("M07-06", COMP, "Prueba estadística (binomial, 3σ)", "p_m = 0.30 por gen; |A_s| = 3; 10 000 genes",
                 0.20, "Fracción de genes cambiados = p_m·(1 − 1/|A_s|) = 0.20 en el modo por gen")
    servicios, _, mutacion = _operadores(alcance="gene")
    antes = np.random.default_rng(4).integers(0, 3, size=(500, len(servicios)))
    despues = caso.cronometrar(mutacion, antes.copy(), SimpleNamespace(mutation_probability=0.30))
    fraccion = float(np.mean(antes != despues))
    caso.observar(fraccion, tolerancia=0.015)
    assert abs(fraccion - 0.20) <= 0.015


def _config_tesis(semilla, t_min, **extra):
    return GAConfig(population_size=50, num_generations=100, crossover_probability=0.80, mutation_probability=0.10,
                    tournament_size=3, elitism_fraction=0.10, min_transition=t_min, random_seed=semilla,
                    mutation_scope="chromosome", repair_mode="targeted", repair_initial=True, **extra)


def test_m07_07_elitismo_no_empeora(caso):
    caso.definir("M07-07", COMP, "Propiedad del elitismo", "configuración de la Tabla 18; n = 14 y 28; semillas 1–10",
                 0, "La mejor aptitud por generación nunca disminuye")
    retrocesos = 0
    for n, s in ((14, 102), (28, 103)):
        inst, meta = construir_instancia(n, s)
        for semilla in range(1, 11):
            h = caso.cronometrar(run, inst, _config_tesis(semilla, meta.t_min)).best_fitness_by_generation
            retrocesos += sum(1 for a, b in zip(h, h[1:]) if b < a)
    caso.observar(retrocesos)
    assert retrocesos == 0


def test_m07_08_aptitud_final_consistente(caso):
    caso.definir("M07-08", COMP, "Consistencia interna", "configuración de la Tabla 18; n = 28, semilla de instancia 101",
                 0.0, "La última aptitud registrada es la de evaluar el cromosoma devuelto")
    inst, meta = construir_instancia(28, 101)
    r = caso.cronometrar(run, inst, _config_tesis(3, meta.t_min))
    pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
    diferencia = abs(r.best_fitness_by_generation[-1] - evaluate(r.chromosome, inst, pares).fitness)
    caso.observar(diferencia, tolerancia=1e-9)
    assert diferencia <= 1e-9 and r.breakdown.fitness == evaluate(r.chromosome, inst, pares).fitness


class _GAFalso:
    """Doble de prueba (mock) de pygad.GA: registra la configuración recibida."""
    recibido: dict = {}

    def __init__(self, **kwargs):
        _GAFalso.recibido = kwargs

    def run(self):
        pass

    def best_solution(self):
        return np.zeros(self.recibido["num_genes"], dtype=int), 0.0, 0


def test_m07_09_configuracion_entregada_a_pygad(caso):
    caso.definir("M07-09", COMP, "Doble de prueba (mock) de la dependencia externa PyGAD",
                 "resolver_ag(n = 14, semilla 7) con P = 50, G = 100", "Tabla 18",
                 "El núcleo llama a PyGAD con torneo K = 3, elitismo 5, p_m = 0.10, P = 50, G = 100, "
                 "25 padres, semilla y dominio de genes correctos")
    inst, meta = construir_instancia(14, 102)
    with mock.patch.object(planificador.pygad, "GA", _GAFalso):
        caso.cronometrar(resolver_ag, inst, meta.t_min, 7)
    k = _GAFalso.recibido
    esperado = {"num_generations": 100, "sol_per_pop": 50, "num_parents_mating": 25,
                "parent_selection_type": "tournament", "K_tournament": 3, "keep_elitism": 5,
                "mutation_probability": 0.10, "random_seed": 7, "gene_type": int, "stop_criteria": None}
    discrepancias = [c for c, v in esperado.items() if k.get(c) != v]
    servicios = inst.services_with_options()
    if k["gene_space"] != [{"low": 0, "high": len(s.admissible)} for s in servicios]:
        discrepancias.append("gene_space")
    if not (callable(k["crossover_type"]) and callable(k["mutation_type"])):
        discrepancias.append("operadores")
    if len(k["initial_population"]) != 50:
        discrepancias.append("initial_population")
    caso.observar(discrepancias or "sin discrepancias", margen=len(discrepancias))
    assert not discrepancias


def test_m07_10_poblacion_inicial_reparada(caso):
    caso.definir("M07-10", COMP, "Doble de prueba + oráculo", "resolver_ag(n = 56, semilla 2): 50 individuos iniciales",
                 0, "Cada individuo inicial es la versión reparada de un individuo aleatorio y no tiene más "
                    "incumplimientos que él")
    inst, meta = construir_instancia(56, 101)
    servicios = inst.services_with_options()
    pares = build_conflict_pairs(servicios, meta.t_min)
    with mock.patch.object(planificador.pygad, "GA", _GAFalso):
        caso.cronometrar(resolver_ag, inst, meta.t_min, 2)
    iniciales = _GAFalso.recibido["initial_population"]
    rng = random.Random(2 + 7919)                     # flujo propio de la población inicial (core/scheduler.py)
    indice = build_conflict_index(servicios, pares)
    errores = 0
    for individuo in iniciales:
        crudo = tuple(rng.randrange(len(s.admissible)) for s in servicios)
        reparado = repair_targeted(crudo, servicios, indice, inst.driving_time_prior, inst.driving_time_limit)
        errores += int(tuple(individuo) != reparado)
        errores += int(evaluate(reparado, inst, pares).feasibility_violations
                       > evaluate(crudo, inst, pares).feasibility_violations)
    caso.observar(errores)
    assert errores == 0
