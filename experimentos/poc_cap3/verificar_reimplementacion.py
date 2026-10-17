"""Comprueba la reimplementación contra los resultados registrados (2026-10-17).

    python3 experimentos/poc_cap3/verificar_reimplementacion.py

1. Voraz: el cromosoma de cada una de las 15 instancias es el registrado en
   soluciones_v1.jsonl y soluciones_v2.jsonl.
2. PLE: la F de cada instancia es la registrada en resultados_crudos_v1.csv y
   resultados_crudos_v2.csv (CBC puede devolver otro óptimo alternativo del mismo
   modelo, con la misma Z y la misma F).
3. Búsqueda tabú y AG: con la misma semilla dan dos veces el mismo cromosoma.

La evaluación de F(X), Φ y del validador sobre las 1 320 soluciones registradas,
y los óptimos de n = 7, se comprueban con experimentos/sanfelipe/reevaluar_cromosomas.py.
Sale con código 1 si algo no coincide.
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
PAQUETE = AQUI.parent / "sanfelipe"
sys.path.insert(0, str(AQUI))
sys.path.insert(0, str(PAQUETE))
sys.path.insert(0, str(AQUI.parents[1]))

from core.conflicts import build_conflict_pairs  # noqa: E402
from core.fitness import evaluate  # noqa: E402
from generador_sanfelipe import TURNO_MIN, construir_instancia  # noqa: E402
from metodos import resolver_ag, resolver_ple, resolver_tabu, resolver_voraz  # noqa: E402

TOL = 1e-9


def registrados(var, metodo):
    filas = csv.DictReader(open(PAQUETE / f"resultados_crudos_{var}.csv", encoding="utf8"))
    sols = map(json.loads, open(PAQUETE / f"soluciones_{var}.jsonl", encoding="utf8"))
    return {(s["n"], s["instancia"]): (s["cromosoma"], float(f["F"])) for f, s in zip(filas, sols)
            if f["metodo"] == metodo}


def main():
    fallas = 0
    instancias = {}
    for n, semilla in registrados("v1", "Voraz"):
        inst, meta = construir_instancia(n, semilla)
        instancias[(n, semilla)] = (inst, meta, build_conflict_pairs(inst.services_with_options(),
                                                                     min_transition=meta.t_min))
    for var in ("v1", "v2"):
        voraz = registrados(var, "Voraz")
        iguales = sum(resolver_voraz(instancias[k][0], instancias[k][1].t_min) == c for k, (c, _) in voraz.items())
        print(f"Voraz {var}: {iguales} de {len(voraz)} cromosomas iguales a los registrados")
        fallas += iguales != len(voraz)

    ple = registrados("v1", "PLE")
    soluciones_ple = {k: resolver_ple(instancias[k][0], instancias[k][2], TURNO_MIN) for k in ple}
    for var in ("v1", "v2"):
        reg = registrados(var, "PLE")
        mismas_f = sum(1 for k, (_, f) in reg.items()
                       if abs(evaluate(soluciones_ple[k][0], instancias[k][0], instancias[k][2]).fitness - f)
                       <= TOL * max(1.0, abs(f)))
        mismos = sum(soluciones_ple[k][0] == c for k, (c, _) in reg.items())
        print(f"PLE {var}: {mismas_f} de {len(reg)} con la F registrada ({mismos} con el mismo cromosoma)")
        fallas += mismas_f != len(reg)

    inst, meta, pares = instancias[(14, 101)]
    for nombre, resolver in (("Tabu", lambda s: resolver_tabu(inst, pares, meta.t_min, s)[0]),
                             ("AG", lambda s: resolver_ag(inst, meta.t_min, s))):
        repetible = all(resolver(s) == resolver(s) for s in (1, 2))
        print(f"{nombre}: {'repetible' if repetible else 'NO repetible'} con la misma semilla (n = 14, instancia 101)")
        fallas += not repetible
    return int(fallas > 0)


if __name__ == "__main__":
    sys.exit(main())
