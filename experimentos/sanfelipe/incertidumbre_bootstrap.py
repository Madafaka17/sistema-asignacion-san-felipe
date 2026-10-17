"""Incertidumbre de la brecha media (C1) por remuestreo bootstrap (material
suplementario, 2026-10-17).

Agregado después del registro del protocolo (ver DESVIACIONES.md); no cambia los
criterios, los anclajes ni los pesos, y solo lee resultados ya registrados
(resultados_crudos_<variante>.csv y optimos_n7_<variante>.csv). No ejecuta ningún
candidato ni necesita core/.

La brecha de cada ejecución es la de la ecuación (16), con la misma referencia que
experimento.py analizar: el óptimo certificado en n = 7 y la mejor F conocida en
n ≥ 14, que se mantiene fija (el remuestreo es condicional a esa referencia).

Remuestreo estratificado en dos etapas, con B = 10 000 réplicas y semilla fija por
variante:
dentro de cada tamaño n se eligen 3 instancias con reemplazo entre las 3 del
experimento y, dentro de cada instancia elegida, las ejecuciones de cada método con
reemplazo entre las registradas (10 semillas en búsqueda tabú y AG; 1 en PLE y
voraz). Todos los métodos comparten las instancias elegidas en cada réplica, lo
que permite estimar la diferencia pareada AG − PLE.

Para cada variante, método y alcance (todas las ejecuciones o un tamaño n) informa
la brecha media observada, el intervalo percentil del 95 % y el error estándar
bootstrap; en el alcance global, además, el puntaje C1 observado (Tabla 15) y la
proporción de réplicas que conservan ese puntaje. En la fila AG−PLE informa la
diferencia de brechas medias y la proporción de réplicas en que la del AG es mayor.

Con solo tres instancias por tamaño, los intervalos describen la variabilidad
entre las instancias y semillas del experimento; no son una inferencia sobre la
operación real de la empresa.

    python3 incertidumbre_bootstrap.py        # -> incertidumbre_brecha.csv
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

import numpy

AQUI = Path(__file__).resolve().parent
VARIANTES = ["v1", "v2", "v1D", "v2D"]
METODOS = ["PLE", "Voraz", "Tabu", "AG"]
TAMANOS = [7, 14, 28, 56, 112]
INSTANCIAS = [101, 102, 103]
B = 10_000
SEMILLA = 20261017
CORTES_C1 = (1, 5, 10, 20)          # Tabla 15: ≤ 1 % → 5, ≤ 5 % → 4, ≤ 10 % → 3, ≤ 20 % → 2


def puntaje_c1(brecha):
    for p, u in zip((5, 4, 3, 2), CORTES_C1):
        if brecha <= u:
            return p
    return 1


def brechas(var):
    """{(método, n, instancia): [brecha de cada ejecución en el orden registrado]}."""
    filas = list(csv.DictReader(open(AQUI / f"resultados_crudos_{var}.csv", encoding="utf8")))
    mejor = {}
    for r in filas:
        if r["F"] != "":
            k = (int(r["n"]), int(r["instancia"]))
            mejor[k] = max(mejor.get(k, float("-inf")), float(r["F"]))
    for r in csv.DictReader(open(AQUI / f"optimos_n7_{var}.csv", encoding="utf8")):
        mejor[(int(r["n"]), int(r["instancia"]))] = float(r["F_optimo"])
    datos = {}
    for r in filas:
        k = (int(r["n"]), int(r["instancia"]))
        if r["F"] == "":
            b = 100.0
        else:
            fb = mejor[k]
            b = min(100.0, max(0.0, (fb - float(r["F"])) / max(abs(fb), 1e-9) * 100.0))
        datos.setdefault((r["metodo"],) + k, []).append(b)
    return datos


def remuestrear(var, rng):
    datos = brechas(var)
    # Arreglo por método: tamaño × instancia × ejecución.
    arreglos = {m: numpy.array([[datos[(m, n, i)] for i in INSTANCIAS] for n in TAMANOS]) for m in METODOS}
    elegidas = rng.integers(0, len(INSTANCIAS), size=(B, len(TAMANOS), len(INSTANCIAS)))
    filas_n = numpy.arange(len(TAMANOS))[None, :, None]
    medias_n, medias = {}, {}
    for m, a in arreglos.items():
        k = a.shape[2]
        semillas = rng.integers(0, k, size=(B, len(TAMANOS), len(INSTANCIAS), k))
        replica = a[filas_n[..., None], elegidas[..., None], semillas]      # B × n × instancia × ejecución
        medias_n[m] = replica.mean(axis=(2, 3))                              # B × n
        medias[m] = replica.mean(axis=(1, 2, 3))                             # B
    observado = {m: (a.mean(), a.mean(axis=(1, 2))) for m, a in arreglos.items()}
    return arreglos, observado, medias, medias_n


def fila(var, metodo, alcance, ejecuciones, obs, replicas, extra=None):
    inf, sup = numpy.percentile(replicas, [2.5, 97.5])
    r = {"variante": var, "metodo": metodo, "alcance": alcance, "ejecuciones": ejecuciones,
         "brecha_media_pct": round(float(obs), 4), "ic95_inf_pct": round(float(inf), 4),
         "ic95_sup_pct": round(float(sup), 4), "error_estandar_pct": round(float(replicas.std(ddof=1)), 4),
         "puntaje_C1": "", "prop_mismo_puntaje_C1": "", "prop_mayor_que_cero": ""}
    r.update(extra or {})
    return r


def main():
    salida = []
    for k, var in enumerate(VARIANTES):
        rng = numpy.random.default_rng([SEMILLA, k])
        arreglos, observado, medias, medias_n = remuestrear(var, rng)
        for m in METODOS:
            obs, obs_n = observado[m]
            p = puntaje_c1(obs)
            mismo = numpy.mean([puntaje_c1(x) == p for x in medias[m]])
            salida.append(fila(var, m, "global", arreglos[m].size, obs, medias[m],
                               {"puntaje_C1": p, "prop_mismo_puntaje_C1": round(float(mismo), 4)}))
            for j, n in enumerate(TAMANOS):
                salida.append(fila(var, m, f"n={n}", arreglos[m][j].size, obs_n[j], medias_n[m][:, j]))
        dif = medias["AG"] - medias["PLE"]
        dif_n = medias_n["AG"] - medias_n["PLE"]
        obs_dif = observado["AG"][0] - observado["PLE"][0]
        salida.append(fila(var, "AG-PLE", "global", "", obs_dif, dif,
                           {"prop_mayor_que_cero": round(float(numpy.mean(dif > 0)), 4)}))
        for j, n in enumerate(TAMANOS):
            obs_j = observado["AG"][1][j] - observado["PLE"][1][j]
            salida.append(fila(var, "AG-PLE", f"n={n}", "", obs_j, dif_n[:, j],
                               {"prop_mayor_que_cero": round(float(numpy.mean(dif_n[:, j] > 0)), 4)}))
    with open(AQUI / "incertidumbre_brecha.csv", "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(salida[0]))
        w.writeheader()
        w.writerows(salida)
    for r in salida:
        if r["alcance"] == "global":
            print(r["variante"], r["metodo"], r["brecha_media_pct"], [r["ic95_inf_pct"], r["ic95_sup_pct"]],
                  "C1", r["puntaje_C1"], r["prop_mismo_puntaje_C1"], r["prop_mayor_que_cero"])
    print(f"incertidumbre_brecha.csv: {len(salida)} filas, B = {B}, semilla {SEMILLA}")


if __name__ == "__main__":
    sys.exit(main())
