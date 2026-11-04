"""M10. Validador independiente de restricciones duras (experimentos/poc_cap3/validador.py)."""
from __future__ import annotations

import json
import random
from pathlib import Path

from core.conflicts import build_conflict_pairs
from core.domain import Instance, Service
from core.fitness import evaluate
from generador_sanfelipe import construir_instancia
from utilidades import alt, cromosoma_aleatorio, instancia_control
from validador import contar_incumplimientos

COMP = "Validador independiente de Φ (ec. 4 a 6)"
OFICIALES = [(n, s) for n in (7, 14, 28, 56, 112) for s in (101, 102, 103)]
from rutas import SANFELIPE as SANF  # noqa: E402  (experimentos/sanfelipe o el nombre anterior)


def test_m10_01_coincide_con_phi_aleatorios(caso):
    caso.definir("M10-01", COMP, "Oráculo cruzado (3 000 cromosomas aleatorios)", "200 cromosomas × 15 instancias", 0,
                 "El validador, que recalcula desde los intervalos crudos, coincide con Φ del núcleo")
    rng = random.Random(10)
    discrepancias = 0
    for n, s in OFICIALES:
        inst, meta = construir_instancia(n, s)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios, meta.t_min)
        for _ in range(200):
            x = cromosoma_aleatorio(servicios, rng)
            v = caso.cronometrar(contar_incumplimientos, x, servicios, inst, meta.t_min)
            discrepancias += int(v != evaluate(x, inst, pares).feasibility_violations)
    caso.observar(discrepancias)
    assert discrepancias == 0


def test_m10_02_coincide_en_soluciones_registradas(caso):
    caso.definir("M10-02", COMP, "Datos registrados (660 soluciones v1 y v2)", "soluciones_v*.jsonl", 0,
                 "El validador coincide con Φ en las soluciones reales del experimento")
    instancias = {(n, s): construir_instancia(n, s) for n, s in OFICIALES}
    discrepancias = total = 0
    for var in ("v1", "v2"):
        for linea in open(SANF / f"soluciones_{var}.jsonl", encoding="utf8"):
            r = json.loads(linea)
            if r["cromosoma"] is None:
                continue
            inst, meta = instancias[(int(r["n"]), int(r["instancia"]))]
            servicios = inst.services_with_options()
            x = tuple(r["cromosoma"])
            v = caso.cronometrar(contar_incumplimientos, x, servicios, inst, meta.t_min)
            discrepancias += int(v != evaluate(x, inst, build_conflict_pairs(servicios, meta.t_min)).feasibility_violations)
            total += 1
    caso.observar(discrepancias)
    assert discrepancias == 0 and total == 660


def test_m10_03_recurso_doble_cuenta_una_vez(caso):
    caso.definir("M10-03", COMP, "Partición: comparten unidad y conductor", "S1=(V1,C1,[0,60]); S2=(V1,C1,[30,90])", 1,
                 "Un par de servicios que comparte dos recursos cuenta como un solo incumplimiento")
    servicios = (Service("S1", 1, (alt("S1", "V1", "C1", "h", 0, 60),)), Service("S2", 1, (alt("S2", "V1", "C1", "h", 30, 60),)))
    v = caso.cronometrar(contar_incumplimientos, (0, 0), servicios, Instance(servicios, {}, {}), 0.0)
    caso.observar(v)
    assert v == 1


def test_m10_04_instancia_de_control(caso):
    caso.definir("M10-04", COMP, "Resultado precalculado a mano", "instancia de control, X = (0, 0, 0, 1)", 2,
                 "Un cruce (S1–S3) más un conductor sobre el límite (C1)")
    inst = instancia_control()
    v = caso.cronometrar(contar_incumplimientos, (0, 0, 0, 1), inst.services_with_options(), inst, 10.0)
    caso.observar(v)
    assert v == 2
