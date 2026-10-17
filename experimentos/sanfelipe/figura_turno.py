"""Figura: programación de un turno sintético por conductor (n = 14, instancia 101, v1)
obtenida por el algoritmo voraz, la programación lineal entera y el algoritmo genético
(semilla 1, fijada de antemano para no elegir la mejor ejecución).

La instancia se eligió después de conocer los resultados, para ilustrar el origen de
la brecha de la programación lineal entera (n = 14 es el tamaño en que fue mayor);
la figura es ilustrativa y no forma parte de la matriz de decisión.

Cada fila es un conductor; cada barra, un viaje redondo desde Soritor, con la unidad
que conduce (* si el conductor es reemplazo del conductor fijo de esa unidad). El
tono indica el destino. A la derecha, la carga del conductor en minutos. Las barras
rayadas son servicios que participan en un cruce o cuyo conductor excede su límite.

    python3 figura_turno.py
"""
from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from itertools import combinations
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
sys.path.insert(0, str(AQUI.parents[1]))

from generador_sanfelipe import HORA_INICIO_TURNO, TURNO_MIN, construir_instancia  # noqa: E402

VAR, N, INSTANCIA, SEMILLA = "v1", 14, 101, 1
TONO = {"MOY": "0.86", "TAR": "0.55"}
PANELES = (("Voraz", 0, "a. Algoritmo voraz"),
           ("PLE", 0, "b. Programación lineal entera"),
           ("AG", SEMILLA, f"c. Algoritmo genético (semilla {SEMILLA})"))


def cromosoma(metodo, semilla):
    for linea in open(AQUI / f"soluciones_{VAR}.jsonl", encoding="utf8"):
        r = json.loads(linea)
        if r["metodo"] == metodo and r["n"] == N and r["instancia"] == INSTANCIA and r["semilla"] == semilla:
            return r["cromosoma"]
    raise KeyError((metodo, semilla))


def invalidos(asig, inst, t_min):
    por = defaultdict(list)
    for sid, a in asig:
        por[("V", a.vehicle_id)].append((sid, a))
        por[("C", a.driver_id)].append((sid, a))
    malos = set()
    for lista in por.values():
        for (s1, a1), (s2, a2) in combinations(lista, 2):
            if not (a1.start_time + a1.duration + t_min <= a2.start_time
                    or a2.start_time + a2.duration + t_min <= a1.start_time):
                malos.update((s1, s2))
    carga = defaultdict(float)
    for _, a in asig:
        carga[a.driver_id] += a.duration
    exc = {c for c, x in carga.items() if x > inst.driving_time_limit[c] + 1e-9}
    malos.update(sid for sid, a in asig if a.driver_id in exc)
    return malos


def panel(ax, inst, meta, crom, titulo):
    servs = inst.services_with_options()
    asig = [(s.service_id, s.admissible[g]) for s, g in zip(servs, crom)]
    malos = invalidos(asig, inst, meta.t_min)
    filas = {c: i for i, c in enumerate(meta.conductores)}
    carga = defaultdict(float)
    for sid, a in asig:
        y = filas[a.driver_id]
        carga[a.driver_id] += a.duration
        reemplazo = a.vehicle_id in meta.conductor_fijo and a.driver_id != meta.conductor_fijo[a.vehicle_id]
        ax.barh(y, a.duration, left=a.start_time, height=0.62, color=TONO[meta.ruta[sid]],
                edgecolor="black", linewidth=1.4 if sid in malos else 0.5,
                hatch="////" if sid in malos else None, alpha=0.95)
        ax.text(a.start_time + a.duration / 2, y, a.vehicle_id + ("*" if reemplazo else ""),
                ha="center", va="center", fontsize=6.3)
    for c, i in filas.items():
        ax.text(TURNO_MIN + 8, i, f"{carga[c]:.0f} min", ha="left", va="center", fontsize=6.5)
    cargas = [x for x in carga.values() if x > 0]
    media = sum(cargas) / len(cargas)
    de = math.sqrt(sum((x - media) ** 2 for x in cargas) / len(cargas))
    ax.set_yticks(range(len(meta.conductores)))
    ax.set_yticklabels(meta.conductores, fontsize=7)
    ax.invert_yaxis()
    ticks = list(range(0, TURNO_MIN + 1, 120))
    ax.set_xticks(ticks)
    ax.set_xticklabels([f"{(HORA_INICIO_TURNO + t) // 60:02d}:00" for t in ticks], fontsize=7)
    ax.set_xlim(0, TURNO_MIN)
    ax.grid(True, axis="x", color="0.88", linewidth=0.5)
    ax.set_axisbelow(True)
    ax.set_title(f"{titulo}: {len(malos)} servicios con incumplimiento; desviación estándar de la carga {de:.0f} min",
                 fontsize=8, loc="left")
    return len(malos), de


def main():
    plt.rcParams.update({"font.family": "DejaVu Serif", "font.size": 8, "axes.linewidth": 0.6,
                         "hatch.linewidth": 0.6})
    inst, meta = construir_instancia(N, INSTANCIA)
    fig, ejes = plt.subplots(len(PANELES), 1, figsize=(7.1, 7.2), sharex=True)
    hay_malos = False
    for ax, (metodo, sem, titulo) in zip(ejes, PANELES):
        k, de = panel(ax, inst, meta, cromosoma(metodo, sem), titulo)
        hay_malos |= k > 0
        print(metodo, "incumplimientos", k, "desviación", round(de, 1))
    ejes[-1].set_xlabel("Hora del turno sintético")
    leyenda = [Patch(facecolor=TONO["MOY"], edgecolor="black", linewidth=0.5, label="Soritor–Moyobamba–Soritor"),
               Patch(facecolor=TONO["TAR"], edgecolor="black", linewidth=0.5, label="Soritor–Tarapoto–Soritor")]
    if hay_malos:
        leyenda.append(Patch(facecolor="white", edgecolor="black", linewidth=1.4, hatch="////",
                             label="Servicio con incumplimiento"))
    fig.legend(handles=leyenda, loc="lower center", ncol=3, frameon=False, fontsize=7.5, bbox_to_anchor=(0.5, -0.005))
    fig.tight_layout(rect=(0, 0.035, 0.96, 1))
    fig.savefig(AQUI / "figura_turno.png", dpi=300)
    print("figura_turno.png")


if __name__ == "__main__":
    main()
