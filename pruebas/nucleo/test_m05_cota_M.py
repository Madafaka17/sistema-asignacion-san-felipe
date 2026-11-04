"""M05. Cota U de E + J y dominancia lexicográfica de Φ con M = 10^6 (sección 3.1.2).

U = n·d_máx + w_Ret·n_b·Δ_máx/b_Ret + w_R·n_b/b_R + w_Tm·|V|·H/b_Tm + w_D·n·d_máx/(2·b_D),
válida si H_c0 ≤ H_cmáx. Si M > U, Φ(X) < Φ(Y) implica F(X) > F(Y).
"""
from __future__ import annotations

import json
import random
from pathlib import Path

from core.conflicts import build_conflict_pairs
from core.fitness import evaluate
from generador_sanfelipe import TURNO_MIN, construir_instancia
from utilidades import cota_U, cromosoma_aleatorio, instancia_aleatoria

COMP = "Cota U de E + J y elección de M (sec. 3.1.2)"
M = 1.0e6
OFICIALES = [(n, s) for n in (7, 14, 28, 56, 112) for s in (101, 102, 103)]
from rutas import SANFELIPE as SANF  # noqa: E402  (experimentos/sanfelipe o el nombre anterior)


def test_m05_01_precondicion_horas_previas(caso):
    caso.definir("M05-01", COMP, "Precondición de la demostración", "15 instancias oficiales", 0,
                 "Ningún conductor inicia el turno por encima de su límite (H_c0 ≤ H_cmáx)")
    violaciones = 0
    for n, s in OFICIALES:
        inst, _ = caso.cronometrar(construir_instancia, n, s)
        violaciones += sum(1 for c, h0 in inst.driving_time_prior.items()
                           if h0 > inst.driving_time_limit.get(c, float("inf")))
    caso.observar(violaciones)
    assert violaciones == 0


def test_m05_02_cota_menor_que_M(caso):
    caso.definir("M05-02", COMP, "Valor límite del parámetro M", "15 instancias oficiales, H = 600 min",
                 "U < 10^6 y U ≤ 610·n",
                 "La cota de la tesis es menor que M en todas las instancias y respeta la forma general 610·n")
    peor_razon, u_max = 0.0, 0.0
    for n, s in OFICIALES:
        inst, _ = construir_instancia(n, s)
        u = caso.cronometrar(cota_U, inst, float(TURNO_MIN))
        u_max = max(u_max, u)
        peor_razon = max(peor_razon, u / (610 * n))
    caso.observar(f"U_máx = {u_max:.2f}; M/U_máx = {M / u_max:.1f}; máx U/(610 n) = {peor_razon:.3f}",
                  margen=round(M - u_max, 2))
    assert u_max < M and peor_razon <= 1.0


def test_m05_03_soluciones_registradas_bajo_la_cota(caso):
    caso.definir("M05-03", COMP, "Datos de las ejecuciones registradas (v1 y v2, 660 soluciones)",
                 "soluciones_v1.jsonl y soluciones_v2.jsonl", "E + J ≤ U en todas",
                 "Ninguna solución obtenida en el experimento supera la cota analítica")
    instancias = {(n, s): construir_instancia(n, s) for n, s in OFICIALES}
    cotas = {k: cota_U(i, float(TURNO_MIN)) for k, (i, _) in instancias.items()}
    pares = {k: build_conflict_pairs(i.services_with_options(), m.t_min) for k, (i, m) in instancias.items()}
    violaciones, max_ej, total = 0, 0.0, 0
    for var in ("v1", "v2"):
        for linea in open(SANF / f"soluciones_{var}.jsonl", encoding="utf8"):
            r = json.loads(linea)
            if r["cromosoma"] is None:
                continue
            k = (int(r["n"]), int(r["instancia"]))
            b = caso.cronometrar(evaluate, tuple(r["cromosoma"]), instancias[k][0], pares[k])
            ej = b.driving_time_excess + b.loss
            max_ej = max(max_ej, ej)
            violaciones += int(ej > cotas[k])
            total += 1
    caso.observar(f"{total} soluciones; máx E + J = {max_ej:.4f}; violaciones = {violaciones}", margen=violaciones)
    assert violaciones == 0 and total == 660


def test_m05_04_cromosomas_aleatorios_bajo_la_cota(caso):
    caso.definir("M05-04", COMP, "Muestreo aleatorio (300 cromosomas × 15 instancias)",
                 "cromosomas uniformes en A_s", 0, "E + J ≤ U incluso para soluciones muy infactibles")
    rng = random.Random(2026)
    violaciones = 0
    for n, s in OFICIALES:
        inst, meta = construir_instancia(n, s)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios, meta.t_min)
        u = cota_U(inst, float(TURNO_MIN))
        for _ in range(300):
            b = caso.cronometrar(evaluate, cromosoma_aleatorio(servicios, rng), inst, pares)
            violaciones += int(b.driving_time_excess + b.loss > u)
    caso.observar(violaciones)
    assert violaciones == 0


def test_m05_05_dominancia_lexicografica(caso):
    caso.definir("M05-05", COMP, "Propiedad (2 000 pares con Φ distinto por tamaño)",
                 "pares aleatorios en las instancias 101 de cada tamaño", 0,
                 "Si Φ(X) < Φ(Y), entonces F(X) > F(Y) con M = 10^6")
    rng = random.Random(7)
    inversiones = 0
    for n in (7, 14, 28, 56, 112):
        inst, meta = construir_instancia(n, 101)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios, meta.t_min)
        muestras = [caso.cronometrar(evaluate, cromosoma_aleatorio(servicios, rng), inst, pares) for _ in range(400)]
        comparados, intentos = 0, 0
        while comparados < 2000 and intentos < 200_000:
            intentos += 1
            a, b = rng.sample(muestras, 2)
            if a.feasibility_violations == b.feasibility_violations:
                continue
            x, y = (a, b) if a.feasibility_violations < b.feasibility_violations else (b, a)
            inversiones += int(not x.fitness > y.fitness)
            comparados += 1
    caso.observar(inversiones)
    assert inversiones == 0


def test_m05_06_control_negativo_M_pequeno(caso):
    caso.definir("M05-06", COMP, "Control negativo (M < U)", "instancias aleatorias con M = 0.01", "≥ 1 inversión",
                 "Con un M menor que la cota, una solución con más incumplimientos puede tener mejor F: la cota es necesaria")
    rng = random.Random(11)
    encontrado = None
    for semilla in range(200):
        inst = instancia_aleatoria(semilla, n=8)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios)
        muestras = [caso.cronometrar(evaluate, cromosoma_aleatorio(servicios, rng), inst, pares, big_m=0.01)
                    for _ in range(60)]
        for a in muestras:
            for b in muestras:
                if a.feasibility_violations < b.feasibility_violations and a.fitness < b.fitness:
                    encontrado = (a.feasibility_violations, a.fitness, b.feasibility_violations, b.fitness)
                    break
            if encontrado:
                break
        if encontrado:
            break
    caso.observar("sin inversión" if encontrado is None else
                  f"Φ(X)={encontrado[0]} F(X)={encontrado[1]:.4f} < F(Y)={encontrado[3]:.4f} con Φ(Y)={encontrado[2]}",
                  margen=0 if encontrado else 1)
    assert encontrado is not None
