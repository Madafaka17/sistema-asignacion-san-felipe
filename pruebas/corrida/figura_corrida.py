"""Figura de la corrida del capítulo IV: programación del turno (n = 7, instancia 101) por conductor con la regla
voraz (línea base) y con el AG (configuración v1, semilla 1). Lee la traza JSON de trazar_corrida.py.
Uso: python figura_corrida.py traza.json salida.png"""
import json
import math
import sys
from collections import defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Patch  # noqa: E402

t = json.load(open(sys.argv[1], encoding="utf8"))
TONO = {"MOY": "0.86", "TAR": "0.55"}
INICIO = 6 * 60
alt = {(s["id"], a["k"]): (s, a) for s in t["servicios"] for a in s["alternativas"]}
conductores = t["conductores"]


def malos(crom):
    v = None
    sel = [(s["id"], g) for s, g in zip(t["servicios"], crom)]
    # incumplimientos por pares (unidad o conductor) y por exceso de conducción
    m = set()
    asig = [(sid, alt[(sid, g)][1]) for sid, g in sel]
    for i in range(len(asig)):
        for j in range(i + 1, len(asig)):
            (s1, a1), (s2, a2) = asig[i], asig[j]
            if a1["unidad"] == a2["unidad"] or a1["conductor"] == a2["conductor"]:
                if not (a1["inicio"] + a1["duracion"] + t["t_min"] <= a2["inicio"]
                        or a2["inicio"] + a2["duracion"] + t["t_min"] <= a1["inicio"]):
                    m.update((s1, s2))
    carga = defaultdict(float)
    for _, a in asig:
        carga[a["conductor"]] += a["duracion"]
    exc = {c for c, x in carga.items() if x > t["limite"][c] + 1e-9}
    m.update(sid for sid, a in asig if a["conductor"] in exc)
    return m, carga


def panel(ax, crom, titulo):
    m, carga = malos(crom)
    filas = {c: i for i, c in enumerate(conductores)}
    puestos = defaultdict(list)
    for s, g in zip(t["servicios"], crom):
        a = alt[(s["id"], g)][1]
        puestos[a["conductor"]].append((s, a))
    for c, lista in puestos.items():
        lista.sort(key=lambda z: z[1]["inicio"])
        for k, (s, a) in enumerate(lista):
            y = filas[c]
            solapa = any(not (a["inicio"] + a["duracion"] <= b["inicio"] or b["inicio"] + b["duracion"] <= a["inicio"])
                         for s2, b in lista if s2["id"] != s["id"])
            h, dy = (0.3, (-0.16 if k % 2 == 0 else 0.16)) if solapa else (0.6, 0.0)
            ax.barh(y + dy, a["duracion"], left=a["inicio"], height=h, color=TONO[s["ruta"]], edgecolor="black",
                    linewidth=1.4 if s["id"] in m else 0.5, hatch="////" if s["id"] in m else None)
            etiqueta = s["id"] if solapa else f"{s['id']} · {a['unidad']}"
            ax.text(a["inicio"] + a["duracion"] / 2, y + dy, etiqueta, ha="center", va="center",
                    fontsize=5.6 if solapa else 6.4,
                    bbox=dict(boxstyle="square,pad=0.1", facecolor="white", edgecolor="none") if s["id"] in m else None)
    for c, i in filas.items():
        exceso = carga[c] - t["limite"][c]
        txt = f"{carga[c]:.0f} / {t['limite'][c]:.0f} min" + (f"  (+{exceso:.0f})" if exceso > 0 else "")
        ax.text(t["turno_min"] + 6, i, txt, ha="left", va="center", fontsize=6.6)
    usados = [x for x in carga.values() if x > 0]
    media = sum(usados) / len(usados)
    de = math.sqrt(sum((x - media) ** 2 for x in usados) / len(usados))
    ax.set_yticks(range(len(conductores)))
    ax.set_yticklabels(conductores, fontsize=7)
    ax.invert_yaxis()
    ticks = list(range(0, t["turno_min"] + 1, 120))
    ax.set_xticks(ticks)
    ax.set_xticklabels([f"{(INICIO + x) // 60:02d}:00" for x in ticks], fontsize=7)
    ax.set_xlim(0, t["turno_min"])
    ax.grid(True, axis="x", color="0.88", linewidth=0.5)
    ax.set_axisbelow(True)
    ax.set_title(f"{titulo}: {len(m)} servicios con incumplimiento; DE de la carga {de:.1f} min",
                 fontsize=8, loc="left")


plt.rcParams.update({"font.family": "DejaVu Serif", "font.size": 8, "axes.linewidth": 0.6, "hatch.linewidth": 0.6})
fig, ejes = plt.subplots(2, 1, figsize=(7.1, 4.6), sharex=True)
panel(ejes[0], t["voraz"]["c"], "a. Regla voraz (línea base)")
panel(ejes[1], t["mejor"], f"b. AG (v1, semilla {t['semilla_ag']})")
ejes[-1].set_xlabel("Hora del turno")
leyenda = [Patch(facecolor=TONO["MOY"], edgecolor="black", linewidth=0.5, label="Soritor–Moyobamba–Soritor"),
           Patch(facecolor=TONO["TAR"], edgecolor="black", linewidth=0.5, label="Soritor–Tarapoto–Soritor"),
           Patch(facecolor="white", edgecolor="black", linewidth=1.4, hatch="////", label="Servicio con incumplimiento")]
fig.legend(handles=leyenda, loc="lower center", ncol=3, frameon=False, fontsize=7.4, bbox_to_anchor=(0.5, -0.01))
fig.tight_layout(rect=(0, 0.05, 0.93, 1))
fig.savefig(sys.argv[2], dpi=300)
print("ok", sys.argv[2])
