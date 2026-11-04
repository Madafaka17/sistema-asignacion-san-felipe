"""M11. Métodos de comparación del capítulo III: óptimo exhaustivo, PLE (PuLP + CBC), voraz y búsqueda tabú."""
from __future__ import annotations

import csv
import math
from pathlib import Path

from core.conflicts import build_conflict_pairs
from core.domain import Instance, Service
from core.fitness import evaluate
from core.repair import build_conflict_index, repair_targeted
from exhaustivo import optimo_exhaustivo
from generador_sanfelipe import TURNO_MIN, construir_instancia
from metodos import resolver_ag, resolver_ple, resolver_tabu, resolver_voraz
from utilidades import alt, instancia_aleatoria, todos_los_cromosomas

from rutas import SANFELIPE as SANF  # noqa: E402  (experimentos/sanfelipe o el nombre anterior)
OFICIALES = [(n, s) for n in (7, 14, 28, 56, 112) for s in (101, 102, 103)]


def _registrados(metodo, semilla=0):
    filas = csv.DictReader(open(SANF / "resultados_crudos_v1.csv", encoding="utf8"))
    return {(int(r["n"]), int(r["instancia"])): float(r["F"]) for r in filas
            if r["metodo"] == metodo and int(r["semilla"]) == semilla and r["F"] != ""}


def test_m11_01_exhaustivo_igual_a_fuerza_bruta(caso):
    caso.definir("M11-01", "Óptimo exhaustivo de referencia", "Oráculo: enumeración completa sin poda",
                 "40 instancias aleatorias, n = 6, |A_s| ≤ 3, t_min = 10", 0.0,
                 "La enumeración con poda devuelve el mismo óptimo factible que evaluar todos los cromosomas")
    peor = 0.0
    for semilla in range(40):
        inst = instancia_aleatoria(3000 + semilla, n=6, k_max=3)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios, 10.0)
        _, f_exh, _ = caso.cronometrar(optimo_exhaustivo, inst, pares, 10.0)
        factibles = [evaluate(x, inst, pares) for x in todos_los_cromosomas(servicios)]
        f_bf = max((b.fitness for b in factibles if b.is_feasible), default=float("-inf"))
        peor = max(peor, 0.0 if f_exh == f_bf else abs(f_exh - f_bf))
    caso.observar(peor, tolerancia=1e-9)
    assert peor <= 1e-9


def test_m11_02_exhaustivo_reproduce_optimos_registrados(caso):
    caso.definir("M11-02", "Óptimo exhaustivo de referencia", "Reproducción de datos registrados",
                 "instancias oficiales n = 7 (101, 102, 103)", 0.0, "El óptimo certificado coincide con optimos_n7_v1.csv")
    registrados = {int(r["instancia"]): (float(r["F_optimo"]), int(r["hojas_factibles"]))
                   for r in csv.DictReader(open(SANF / "optimos_n7_v1.csv", encoding="utf8"))}
    peor = 0.0
    for s in (101, 102, 103):
        inst, meta = construir_instancia(7, s)
        pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
        _, f, hojas = caso.cronometrar(optimo_exhaustivo, inst, pares, meta.t_min)
        peor = max(peor, abs(f - registrados[s][0]), abs(hojas - registrados[s][1]))
    caso.observar(peor, tolerancia=1e-9)
    assert peor <= 1e-9


def test_m11_03_ple_factible_y_acotada_por_el_optimo(caso):
    caso.definir("M11-03", "Programación lineal entera (ec. 9 a 11; PuLP + CBC)", "Oráculo: óptimo exhaustivo",
                 "instancias oficiales n = 7", 0, "La PLE termina en estado Optimal, sin incumplimientos y "
                 "sin superar el óptimo certificado de F (optimiza un sustituto lineal de D)")
    errores = 0
    for s in (101, 102, 103):
        inst, meta = construir_instancia(7, s)
        pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
        crom, estado = caso.cronometrar(resolver_ple, inst, pares, float(TURNO_MIN))
        b = evaluate(crom, inst, pares)
        _, f_opt, _ = optimo_exhaustivo(inst, pares, meta.t_min)
        errores += int(estado != "Optimal") + int(not b.is_feasible) + int(b.fitness > f_opt + 1e-9)
    caso.observar(errores)
    assert errores == 0


def test_m11_04_voraz_reproduce_registro(caso):
    caso.definir("M11-04", "Algoritmo voraz (ec. 12)", "Reproducción de datos registrados (v1)",
                 "15 instancias oficiales", 0.0, "El voraz es determinista: F coincide con resultados_crudos_v1.csv")
    reg = _registrados("Voraz")
    peor = 0.0
    for n, s in OFICIALES:
        inst, meta = construir_instancia(n, s)
        crom = caso.cronometrar(resolver_voraz, inst, meta.t_min)
        f = evaluate(crom, inst, build_conflict_pairs(inst.services_with_options(), meta.t_min)).fitness
        peor = max(peor, abs(f - reg[(n, s)]))
    caso.observar(peor, tolerancia=1e-9)
    assert peor <= 1e-9


def test_m11_05_voraz_primer_ajuste_por_hora(caso):
    caso.definir("M11-05", "Algoritmo voraz (ec. 12)", "Caso construido",
                 "S1=(V1,C1,[0,100]); S2: (V1,C1,[50,150]) | (V2,C2,[60,160]) | (V3,C3,[55,155])", (0, 2),
                 "Se elige la primera alternativa factible en orden de hora de inicio")
    servicios = (Service("S1", 1, (alt("S1", "V1", "C1", "h0", 0, 100),)),
                 Service("S2", 1, (alt("S2", "V1", "C1", "h0", 50, 100), alt("S2", "V2", "C2", "h1", 60, 100),
                                   alt("S2", "V3", "C3", "h2", 55, 100))))
    crom = caso.cronometrar(resolver_voraz, Instance(servicios, {}, {}), 0.0)
    caso.observar(crom, margen=0 if crom == (0, 2) else 1)
    assert crom == (0, 2)


def test_m11_06_tabu_no_empeora_la_solucion_inicial(caso):
    caso.definir("M11-06", "Búsqueda tabú (ec. 13 y 14)", "Propiedad (15 instancias × semillas 1 y 2)",
                 "presupuesto 5 050 evaluaciones, muestra 30, permanencia 7", 0,
                 "La mejor solución devuelta nunca es peor que la inicial (voraz + reparación dirigida)")
    errores = 0
    for n, s in OFICIALES:
        inst, meta = construir_instancia(n, s)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios, meta.t_min)
        inicial = repair_targeted(resolver_voraz(inst, meta.t_min), servicios, build_conflict_index(servicios, pares),
                                  inst.driving_time_prior, inst.driving_time_limit)
        f0 = evaluate(inicial, inst, pares).fitness
        for semilla in (1, 2):
            mejor, _ = caso.cronometrar(resolver_tabu, inst, pares, meta.t_min, semilla)
            errores += int(evaluate(mejor, inst, pares).fitness < f0)
    caso.observar(errores)
    assert errores == 0


def test_m11_07_tabu_reproducible(caso):
    caso.definir("M11-07", "Búsqueda tabú (ec. 13 y 14)", "Reproducibilidad con semilla fija", "n = 28, instancia 103, semilla 5 (×2)",
                 0, "Dos ejecuciones con la misma semilla devuelven la misma solución y el mismo número de evaluaciones")
    inst, meta = construir_instancia(28, 103)
    pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
    a = caso.cronometrar(resolver_tabu, inst, pares, meta.t_min, 5)
    b = resolver_tabu(inst, pares, meta.t_min, 5)
    caso.observar(int(a != b))
    assert a == b


def test_m11_08_ag_reproducible(caso):
    caso.definir("M11-08", "Algoritmo genético (Tabla 18)", "Reproducibilidad con semilla fija",
                 "n = 56, instancia 102, semilla 4 (×2)", 0, "Dos ejecuciones del AG con la misma semilla coinciden")
    inst, meta = construir_instancia(56, 102)
    a = caso.cronometrar(resolver_ag, inst, meta.t_min, 4)
    b = resolver_ag(inst, meta.t_min, 4)
    caso.observar(int(a != b))
    assert a == b
