"""Variabilidad de los algoritmos estocásticos (AG y búsqueda tabú) con las semillas registradas.

Ejecuta, con la configuración v1 (Tabla 18 de la tesis), las 10 semillas de cada método en las
15 instancias oficiales (300 corridas), compara cada aptitud con resultados_crudos_v1.csv y
resume media y desviación estándar muestral (n − 1) de F, J, Φ y tiempo por método y tamaño.

    python pruebas/nucleo/estocasticas.py salidas/
"""
from __future__ import annotations

import csv
import json
import statistics
import sys
import time
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
sys.path.insert(0, str(AQUI))
from rutas import SANFELIPE as SANF  # noqa: E402  (experimentos/sanfelipe o el nombre anterior)

for ruta in (RAIZ, SANF, RAIZ / "experimentos" / "poc_cap3"):
    sys.path.insert(0, str(ruta))

from core.conflicts import build_conflict_pairs  # noqa: E402
from core.fitness import evaluate  # noqa: E402
from generador_sanfelipe import construir_instancia  # noqa: E402
from metodos import resolver_ag, resolver_tabu  # noqa: E402
from validador import contar_incumplimientos  # noqa: E402

TAMANOS = [7, 14, 28, 56, 112]
INSTANCIAS = [101, 102, 103]
SEMILLAS = list(range(1, 11))


def _registro():
    return {(r["metodo"], int(r["n"]), int(r["instancia"]), int(r["semilla"])): float(r["F"])
            for r in csv.DictReader(open(SANF / "resultados_crudos_v1.csv", encoding="utf8")) if r["F"] != ""}


def _resumen(valores):
    return {"media": statistics.fmean(valores), "desv_est": statistics.stdev(valores) if len(valores) > 1 else 0.0,
            "min": min(valores), "max": max(valores)}


def main(salida: Path):
    salida.mkdir(parents=True, exist_ok=True)
    registro = _registro()
    filas = []
    for n in TAMANOS:
        for s in INSTANCIAS:
            inst, meta = construir_instancia(n, s)
            servicios = inst.services_with_options()
            for semilla in SEMILLAS:
                for metodo in ("Tabu", "AG"):
                    # Medición igual a experimento.py: el tiempo de tabú incluye construir Γ;
                    # el AG construye Γ dentro de run().
                    t0 = time.perf_counter()
                    if metodo == "Tabu":
                        pares = build_conflict_pairs(servicios, min_transition=meta.t_min)
                        crom, _ = resolver_tabu(inst, pares, meta.t_min, semilla)
                    else:
                        crom = resolver_ag(inst, meta.t_min, semilla)
                    t = time.perf_counter() - t0
                    pares = build_conflict_pairs(servicios, min_transition=meta.t_min)
                    b = evaluate(crom, inst, pares)
                    f_reg = registro[(metodo, n, s, semilla)]
                    filas.append({"metodo": metodo, "n": n, "instancia": s, "semilla": semilla, "tiempo_s": t,
                                  "F": b.fitness, "J": b.loss, "phi": b.feasibility_violations,
                                  "validador": contar_incumplimientos(crom, servicios, inst, meta.t_min),
                                  "F_registrado": f_reg, "dif_abs": abs(b.fitness - f_reg)})
            print(f"listo n={n} instancia={s}", flush=True)

    with open(salida / "corridas_estocasticas.csv", "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(filas[0]))
        w.writeheader()
        w.writerows(filas)

    resumen = {}
    for metodo in ("AG", "Tabu"):
        for n in TAMANOS:
            grupo = [f for f in filas if f["metodo"] == metodo and f["n"] == n]
            por_instancia = {}
            for s in INSTANCIAS:
                g = [f for f in grupo if f["instancia"] == s]
                por_instancia[s] = {"F": _resumen([f["F"] for f in g]), "J": _resumen([f["J"] for f in g]),
                                    "tiempo_s": _resumen([f["tiempo_s"] for f in g]),
                                    "phi_media": statistics.fmean(f["phi"] for f in g)}
            resumen[f"{metodo}-{n}"] = {
                "corridas": len(grupo),
                "factibles_pct": 100.0 * sum(1 for f in grupo if f["validador"] == 0) / len(grupo),
                "J_desv_est_media_por_instancia": statistics.fmean(v["J"]["desv_est"] for v in por_instancia.values()),
                "F_desv_est_media_por_instancia": statistics.fmean(v["F"]["desv_est"] for v in por_instancia.values()),
                "tiempo_media_s": statistics.fmean(f["tiempo_s"] for f in grupo),
                "tiempo_desv_est_s": statistics.stdev(f["tiempo_s"] for f in grupo),
                "coincidencias_registro": sum(1 for f in grupo if f["dif_abs"] <= 1e-9),
                "por_instancia": por_instancia,
            }
    total = len(filas)
    iguales = sum(1 for f in filas if f["dif_abs"] <= 1e-9)
    discrepancias_validador = sum(1 for f in filas if f["phi"] != f["validador"])
    datos = {"corridas": total, "coincidencias_con_registro_v1": iguales,
             "discrepancias_validador": discrepancias_validador, "resumen": resumen}
    (salida / "resumen_estocasticas.json").write_text(json.dumps(datos, ensure_ascii=False, indent=2), encoding="utf8")
    print(f"corridas={total} coincidencias={iguales} discrepancias_validador={discrepancias_validador}")


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else AQUI / "salidas")
