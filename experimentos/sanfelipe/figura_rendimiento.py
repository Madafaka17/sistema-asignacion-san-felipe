"""Figura: tiempo medio, brecha media e incumplimientos medios por tamaño (v1 y v2).

Monocromática: cada candidato se distingue por marcador y tipo de línea, de modo
que la figura es legible impresa en escala de grises.
"""
from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

AQUI = Path(__file__).resolve().parent
TAMANOS = [7, 14, 28, 56, 112]
ESTILO = {
    "PLE": dict(marker="s", linestyle="-", label="Programación lineal entera"),
    "Voraz": dict(marker="^", linestyle=":", label="Algoritmo voraz"),
    "Tabu": dict(marker="D", linestyle="-.", label="Búsqueda tabú"),
    "AG": dict(marker="o", linestyle="--", label="Algoritmo genético"),
}


def main():
    plt.rcParams.update({"font.family": "DejaVu Serif", "font.size": 9, "axes.linewidth": 0.6})
    fig, ejes = plt.subplots(2, 3, figsize=(7.1, 5.0), sharex=True)
    for fila, var in enumerate(("v1", "v2")):
        res = json.load(open(AQUI / f"resumen_{var}.json", encoding="utf8"))["resultados"]
        for m, est in ESTILO.items():
            r = res[m]
            t = [max(r["tiempo_medio_por_n"][str(n)], 1e-5) for n in TAMANOS]
            g = [r["brecha_por_n"][str(n)] for n in TAMANOS]
            v = [r["incumplimientos_por_n"][str(n)] for n in TAMANOS]
            for ax, y in zip(ejes[fila], (t, g, v)):
                ax.plot(TAMANOS, y, color="black", linewidth=1.0, markersize=4.5,
                        markerfacecolor="white", markeredgewidth=0.9, **est)
        ejes[fila][0].set_yscale("log")
        titulos = (("a. Tiempo medio (s), v1", "b. Brecha media (%), v1", "c. Incumplimientos, v1"),
                   ("d. Tiempo medio (s), v2", "e. Brecha media (%), v2", "f. Incumplimientos, v2"))[fila]
        for k, ax in enumerate(ejes[fila]):
            ax.set_xscale("log", base=2)
            ax.set_xticks(TAMANOS)
            ax.set_xticklabels([str(n) for n in TAMANOS])
            ax.grid(True, which="major", color="0.85", linewidth=0.5)
            ax.set_title(titulos[k], fontsize=8.5, loc="left")
            ax.tick_params(labelsize=8)
            if fila == 1:
                ax.set_xlabel("Servicios por turno (n)")
    h, l = ejes[0][0].get_legend_handles_labels()
    fig.legend(h, l, loc="lower center", ncol=4, frameon=False, fontsize=8, bbox_to_anchor=(0.5, -0.01))
    fig.tight_layout(rect=(0, 0.05, 1, 1))
    fig.savefig(AQUI / "figura_rendimiento.png", dpi=300)
    print("figura_rendimiento.png")


if __name__ == "__main__":
    main()
