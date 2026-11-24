"""Reproducción de corridas publicadas y variabilidad de los métodos estocásticos del artículo.

Repite con experimento.py (mismas funciones, semillas y parámetros) un subconjunto de las corridas publicadas en
resultados/ y compara cada fila: J, incumplimientos, validador, componentes de J, unidades, conductores y, en el
método exacto, certificado, iteraciones y cota. Resume además la media y la desviación estándar muestral
(n − 1) de J y del tiempo de AG_v1, AG_v2 y Tabu_v1 entre las 5 semillas de cada instancia.

  python pruebas/reproduccion.py pruebas/salidas/

Subconjunto: sintético n = 7 a 112, instancias 101 a 103 (285 corridas); variante con la plantilla de la empresa
(52 conductores para 56 unidades) n = 7 a 56, instancias 101 a 103 (228 corridas); Łódź, agencias MARCEL, MFTRAN y
PHUOLA, instancias 101 a 103 (171 corridas). Se omiten n = 224, Buzău y las agencias KASBUS y MSKRIS porque en ellas
el método exacto o la PLE llegan al límite de 300 s y su resultado depende de la velocidad del equipo.
"""
from __future__ import annotations

import csv
import json
import statistics
import sys
import tempfile
import time
import zipfile
from collections import defaultdict
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent
sys.path[:0] = [str(RAIZ), str(AQUI)]

import experimento  # noqa: E402
import generador_sintetico as G  # noqa: E402
from utilidades import comparar_fila  # noqa: E402

TAMANOS, INSTANCIAS, SEMILLAS = [7, 14, 28, 56, 112], [101, 102, 103], 5
TAMANOS_EMPRESA = [7, 14, 28, 56]
AGENCIAS = ["MARCEL", "MFTRAN", "PHUOLA"]
ESTOCASTICOS = ["AG_v1", "AG_v2", "Tabu_v1"]


def _publicadas(archivo):
    tabla = defaultdict(dict)
    for r in csv.DictReader(open(RAIZ / "resultados" / archivo, encoding="utf-8")):
        tabla[(r["grupo"], int(r["n"]), int(r["instancia"]))][(r["metodo"], int(r["semilla"]))] = r
    return tabla


def _comparar(filas, publicadas, conjunto):
    salida = []
    for f in filas:
        r = publicadas[(f["grupo"], int(f["n"]), int(f["instancia"]))][(f["metodo"], int(f["semilla"]))]
        salida.append(dict(f, conjunto=conjunto, J_publicado=r["J"], tiempo_publicado_s=r["tiempo_s"],
                           igual_al_publicado=comparar_fila(f, r)))
    return salida


def _de(valores):
    return statistics.stdev(valores) if len(valores) > 1 else 0.0


def main(salida: Path):
    salida.mkdir(parents=True, exist_ok=True)
    filas, inicio = [], time.perf_counter()
    pub = _publicadas("sintetico.csv")
    for n in TAMANOS:
        for i in INSTANCIAS:
            filas += _comparar(experimento.tarea_sintetica((n, i, SEMILLAS)), pub, "sintetico")
    pub = _publicadas("sintetico_52c56u.csv")
    lista, unidades = G.CONDUCTORES_LISTA, G.UNIDADES_ACTIVAS_DIA
    G.CONDUCTORES_LISTA, G.UNIDADES_ACTIVAS_DIA = 52, 56
    try:
        for n in TAMANOS_EMPRESA:
            for i in INSTANCIAS:
                filas += _comparar(experimento.tarea_sintetica((n, i, SEMILLAS)), pub, "sintetico_52c56u")
    finally:
        G.CONDUCTORES_LISTA, G.UNIDADES_ACTIVAS_DIA = lista, unidades
    pub = _publicadas("gtfs_lodz.csv")
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(RAIZ / "datos" / "gtfs" / "lodz.zip") as z:
            z.extractall(Path(tmp) / "lodz")
        for ag in AGENCIAS:
            for i in INSTANCIAS:
                filas += _comparar(experimento.tarea_gtfs((str(Path(tmp) / "lodz"), ag, "20261021", "wednesday", i,
                                                           SEMILLAS)), pub, "gtfs_lodz")
    total = time.perf_counter() - inicio

    campos = list(filas[0])
    with open(salida / "reproduccion.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=campos)
        w.writeheader()
        w.writerows(filas)

    por_conjunto = defaultdict(lambda: [0, 0])
    for f in filas:
        por_conjunto[f["conjunto"]][0] += 1
        por_conjunto[f["conjunto"]][1] += int(f["igual_al_publicado"])
    variabilidad = []
    grupos = defaultdict(list)
    for f in filas:
        if f["conjunto"] == "sintetico" and f["metodo"] in ESTOCASTICOS:
            grupos[(f["metodo"], int(f["n"]))].append(f)
    for (metodo, n), fs in sorted(grupos.items(), key=lambda k: (ESTOCASTICOS.index(k[0][0]), k[0][1])):
        por_instancia = defaultdict(list)
        for f in fs:
            por_instancia[int(f["instancia"])].append(f)
        de_j = [_de([float(x["J"]) for x in v]) for v in por_instancia.values()]
        tiempos = [float(f["tiempo_s"]) for f in fs]
        tiempos_pub = [float(f["tiempo_publicado_s"]) for f in fs]
        variabilidad.append({
            "metodo": metodo, "n": n, "corridas": len(fs),
            "factibles_pct": 100.0 * sum(int(f["validador"]) == 0 for f in fs) / len(fs),
            "J_media": statistics.fmean(float(f["J"]) for f in fs), "DE_J": statistics.fmean(de_j),
            "J_min": min(float(f["J"]) for f in fs), "J_max": max(float(f["J"]) for f in fs),
            "tiempo_media_s": statistics.fmean(tiempos), "tiempo_DE_s": _de(tiempos),
            "tiempo_publicado_media_s": statistics.fmean(tiempos_pub),
        })
    resumen = {
        "corridas": len(filas), "iguales": sum(int(f["igual_al_publicado"]) for f in filas),
        "por_conjunto": {k: {"corridas": v[0], "iguales": v[1]} for k, v in por_conjunto.items()},
        "max_dif_relativa_J": max(abs(float(f["J"]) - float(f["J_publicado"])) / max(1.0, abs(float(f["J_publicado"])))
                                  for f in filas),
        "tiempo_total_s": total, "variabilidad_sintetico": variabilidad,
        "instancias": {"sintetico": [TAMANOS, INSTANCIAS], "sintetico_52c56u": [TAMANOS_EMPRESA, INSTANCIAS],
                       "gtfs_lodz": [AGENCIAS, INSTANCIAS]}, "semillas": list(range(1, SEMILLAS + 1)),
    }
    (salida / "resumen_reproduccion.json").write_text(json.dumps(resumen, ensure_ascii=False, indent=2), encoding="utf8")
    print(f"corridas={resumen['corridas']} iguales={resumen['iguales']} "
          f"max_dif_J={resumen['max_dif_relativa_J']:.2e} tiempo={total:.1f}s")


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else AQUI / "salidas")
