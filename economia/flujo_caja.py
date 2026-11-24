"""Figura del capítulo VI: flujo de caja neto anual y acumulado del caso base (un solo eje, S/)."""
import json
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.ticker import FuncFormatter  # noqa: E402

datos = json.load(open(sys.argv[1], encoding="utf8"))
flujo = datos["base"]["flujo"]
anios = [f["t"] for f in flujo]
neto = [f["F"] for f in flujo]
acum, s = [], 0.0
for v in neto:
    s += v
    acum.append(s)

plt.rcParams.update({"font.family": "Liberation Serif", "font.size": 11, "mathtext.fontset": "stix"})
MENOS = lambda v: f"{v:,.0f}".replace("-", "\u2212")  # noqa: E731
fig, ax = plt.subplots(figsize=(6.6, 3.9), dpi=220)
AZUL, TINTA, GRIS = "#3B6A9C", "#222222", "#B8B8B8"
barras = ax.bar(anios, neto, width=0.56, color=AZUL, edgecolor="white", linewidth=1.0, label="Flujo neto del año ($F_t$)",
                zorder=3)
ax.plot(anios, acum, color=TINTA, linewidth=1.6, marker="o", markersize=5, markerfacecolor="white",
        markeredgewidth=1.4, label="Flujo acumulado", zorder=4)
ax.axhline(0, color=TINTA, linewidth=0.9, zorder=2)
alto = max(max(neto), max(acum)) - min(neto)
for x, v in zip(anios, neto):
    if abs(v) >= 0.15 * alto:      # barra alta: etiqueta dentro
        ax.text(x, v / 2, MENOS(v), ha="center", va="center", fontsize=8.5, color="white", fontweight="bold",
                zorder=5)
    else:                          # barra baja: etiqueta encima, en tinta
        ax.text(x, v + 0.02 * alto, MENOS(v), ha="center", va="bottom", fontsize=8.5, color=TINTA,
                fontweight="bold", zorder=5)
ax.annotate(f"Acumulado al año 5: S/ {acum[-1]:,.0f}", (anios[-1], acum[-1]), xytext=(-8, 8),
            textcoords="offset points", ha="right", fontsize=9, color=TINTA)
ax.set_xticks(anios, [f"Año {a}" for a in anios])
ax.yaxis.set_major_formatter(FuncFormatter(lambda v, _: MENOS(v)))
ax.set_ylabel("Soles (S/)")
ax.grid(axis="y", color=GRIS, linewidth=0.5, zorder=0)
for lado in ("top", "right"):
    ax.spines[lado].set_visible(False)
ax.spines["left"].set_color(GRIS)
ax.spines["bottom"].set_visible(False)
ax.tick_params(axis="both", length=0)
ax.set_ylim(min(min(neto), min(acum)) - 0.08 * alto, max(max(neto), max(acum)) + 0.16 * alto)
ax.legend(loc="lower right", frameon=False, fontsize=9.5)
fig.tight_layout()
fig.savefig(sys.argv[2], dpi=220, facecolor="white")
print("ok", acum)
