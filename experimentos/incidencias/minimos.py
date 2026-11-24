"""Análisis adicional (sección 8.1 del protocolo), definido DESPUÉS de observar los resultados de v1.

Para cada uno de los 27 escenarios calcula, con programación lineal entera (PuLP y
CBC), dos referencias exactas sobre la misma instancia de reasignación:

- phi_min: el menor Φ posible (pares en conflicto elegidos + conductores sobre su
  límite) cuando se asigna una alternativa a cada servicio pendiente que la tiene,
  como exige el modelo (ecuación 3).
- sin_reasignacion_valida: el menor número de servicios pendientes que hay que dejar
  sin asignar para que el resto quede sin cruces ni excesos.
- phi_min_sin_limite: phi_min sin límite de conducción (sección 8.3, exploratorio).

Sirve para saber si una reasignación válida de todos los servicios existe con las
alternativas admisibles y si el AG alcanzó el mínimo. No modifica el protocolo.

    python3 minimos.py [v1|v2]   # -> minimos.csv o minimos_v2.csv
"""
from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path

import pulp

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))

from reasignacion import INCIDENCIAS, SEMILLAS_INSTANCIA, TAMANOS, construir_instancia, escenario  # noqa: E402
from core.conflicts import build_conflict_pairs  # noqa: E402
from core.domain import Instance  # noqa: E402



def _modelo(inst2, t_min, dejar_sin_asignar):
    servs = inst2.services_with_options()
    pares = build_conflict_pairs(servs, min_transition=t_min)
    prob = pulp.LpProblem("minimo", pulp.LpMinimize)
    x = {(s.service_id, i): pulp.LpVariable(f"x_{k}_{i}", cat="Binary")
         for k, s in enumerate(servs) for i in range(len(s.admissible))}
    u = {s.service_id: pulp.LpVariable(f"u_{k}", cat="Binary") for k, s in enumerate(servs)}
    for s in servs:
        suma = pulp.lpSum(x[(s.service_id, i)] for i in range(len(s.admissible)))
        prob += (suma + u[s.service_id] == 1) if dejar_sin_asignar else (suma == 1)
    y = {}
    for k, ((s1, i1), (s2, i2)) in enumerate(pares):
        if dejar_sin_asignar:
            prob += x[(s1, i1)] + x[(s2, i2)] <= 1
        else:
            y[k] = pulp.LpVariable(f"y_{k}", cat="Binary")
            prob += x[(s1, i1)] + x[(s2, i2)] - 1 <= y[k]
    carga = defaultdict(list)
    for s in servs:
        for i, a in enumerate(s.admissible):
            carga[a.driver_id].append(a.duration * x[(s.service_id, i)])
    z = {}
    for c, terminos in carga.items():
        previo = inst2.driving_time_prior.get(c, 0.0)
        limite = inst2.driving_time_limit.get(c, float("inf"))
        if dejar_sin_asignar:
            prob += previo + pulp.lpSum(terminos) <= limite
        else:
            z[c] = pulp.LpVariable(f"z_{c}", cat="Binary")
            prob += previo + pulp.lpSum(terminos) <= limite + 10000 * z[c]
    if dejar_sin_asignar:
        prob += pulp.lpSum(u.values())
    else:
        prob += pulp.lpSum(y.values()) + pulp.lpSum(z.values())
        for s in servs:
            prob += u[s.service_id] == 0
    estado = prob.solve(pulp.PULP_CBC_CMD(msg=False, timeLimit=120, threads=1))
    return pulp.LpStatus[estado], round(pulp.value(prob.objective) or 0.0)


def _sin_limites(inst2):
    """Sección 8.3: la misma instancia con un límite de conducción de 10^6 min."""
    return Instance(services=inst2.services, driving_time_prior=inst2.driving_time_prior,
                    driving_time_limit={c: 1.0e6 for c in inst2.driving_time_limit},
                    weights=inst2.weights, norm_refs=inst2.norm_refs)


def main(var):
    salida = AQUI / ("minimos.csv" if var == "v1" else f"minimos_{var}.csv")
    filas = []
    for n in TAMANOS:
        for s_inst in SEMILLAS_INSTANCIA:
            inst, meta = construir_instancia(n, s_inst)
            for tipo in INCIDENCIAS:
                inst2, _, info = escenario(inst, meta, tipo, ampliar=(var == "v2"))
                e1, phi_min = _modelo(inst2, meta.t_min, dejar_sin_asignar=False)
                e2, sin_val = _modelo(inst2, meta.t_min, dejar_sin_asignar=True)
                e3, phi_sin_lim = _modelo(_sin_limites(inst2), meta.t_min, dejar_sin_asignar=False)
                fila = {"n": n, "instancia": s_inst, "incidencia": tipo, "phi_min": phi_min,
                        "estado_phi": e1, "sin_reasignacion_valida": sin_val, "estado_cobertura": e2,
                        "phi_min_sin_limite": phi_sin_lim, "estado_sin_limite": e3,
                        "sin_alternativa": info["sin_alternativa"], "afectados": info["afectados"]}
                filas.append(fila)
                print(fila, flush=True)
    with open(salida, "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(filas[0]))
        w.writeheader()
        w.writerows(filas)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "v1")
