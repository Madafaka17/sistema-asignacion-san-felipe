"""Modelo de casos de uso del negocio con el proceso objetivo y los flujos de información (UML 2.5.1, «flow»)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, Rectangle, FancyArrowPatch

plt.rcParams["font.family"] = "DejaVu Sans"
fig, ax = plt.subplots(figsize=(7.6, 5.4), dpi=260)
ax.set_xlim(0, 104); ax.set_ylim(0, 77); ax.axis("off")
F = 10.5   # tamaño base

ax.add_patch(Rectangle((17.5, 9.5), 69, 65, fill=False, lw=1.5))
ax.text(52, 71.6, "Empresa de Transportes y Turismo San Felipe S.A.C.", ha="center", va="center",
        fontsize=F, weight="bold")

def caso(x, y, cod, nombre, objetivo=False, w=30, h=13):
    ax.add_patch(Ellipse((x, y), w, h, fill=objetivo, facecolor="#e6e6e6" if objetivo else "none",
                         edgecolor="black", lw=2.4 if objetivo else 1.2))
    if objetivo:
        ax.text(x, y + 4.4, "«proceso objetivo»", ha="center", va="center", fontsize=F - 1.5, style="italic")
        ax.text(x, y - 1.8, f"{cod}\n{nombre}", ha="center", va="center", fontsize=F, weight="bold",
                linespacing=1.1)
    else:
        ax.text(x, y, f"{cod}\n{nombre}", ha="center", va="center", fontsize=F, linespacing=1.1)

caso(37, 48, "CUN-01", "Organizar y\nprestar viaje", objetivo=True, w=31, h=17)
caso(70, 56, "CUN-02", "Restituir\ndisponibilidad")
caso(37, 19, "CUN-03", "Atender solicitud\no reclamo", w=31)
caso(70, 19, "CUN-04", "Liquidar vuelta", w=27)

def actor(x, y, nombre):
    ax.add_patch(plt.Circle((x, y + 5.0), 1.4, fill=False, lw=1.2))
    ax.plot([x, x], [y + 3.6, y + 0.2], color="black", lw=1.2)
    ax.plot([x - 2.2, x + 2.2], [y + 2.5, y + 2.5], color="black", lw=1.2)
    ax.plot([x, x - 1.8], [y + 0.2, y - 2.4], color="black", lw=1.2)
    ax.plot([x, x + 1.8], [y + 0.2, y - 2.4], color="black", lw=1.2)
    ax.text(x, y - 3.6, nombre, ha="center", va="top", fontsize=F - 0.5, linespacing=1.05)

actor(7.5, 34, "Pasajero /\ncliente")
actor(96, 55, "Taller\nexterno")
actor(96, 18, "Entidad\nfinanciera")
ax.plot([10.0, 22.5], [37.5, 45.0], color="black", lw=1.1)
ax.plot([10.0, 23.0], [35.0, 23.0], color="black", lw=1.1)
ax.plot([93.5, 85.0], [57.5, 56.5], color="black", lw=1.1)
ax.plot([93.5, 83.5], [20.5, 19.5], color="black", lw=1.1)

def flujo(p, q, texto, tx, ty, rad=0.0):
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle="-|>", mutation_scale=12, lw=1.0, linestyle=(0, (4, 3)),
                                 color="black", connectionstyle=f"arc3,rad={rad}"))
    ax.text(tx, ty, texto, ha="center", va="center", fontsize=F - 1.5, linespacing=1.05,
            bbox=dict(facecolor="white", edgecolor="none", pad=0.5))

flujo((63.0, 62.0), (40.0, 56.8), "«flow»\nestado de la unidad", 49.0, 65.2, rad=0.32)
flujo((52.5, 46.0), (60.5, 51.0), "«flow»\naviso de falla", 61.5, 43.5, rad=0.2)
flujo((31.0, 39.5), (31.0, 25.5), "«flow»\nservicio y\nmanifiesto", 24.5, 32.0)
flujo((43.0, 25.5), (43.0, 39.5), "«flow»\nincidencia", 49.0, 32.0)
flujo((48.0, 41.5), (63.0, 25.0), "«flow»\nservicio realizado\ny manifiesto", 69.0, 34.0)

ax.text(52, 5.6, "Trabajadores internos: despacho, operaciones, conductor, mantenimiento,\natención y administración.",
        ha="center", va="center", fontsize=F - 1.5, linespacing=1.1)
ax.text(52, 0.8, "El sistema interviene en CUN-01 (CU-00 a CU-14); CUN-02 a CUN-04 son procesos relacionados.",
        ha="center", va="center", fontsize=F - 1.5)
fig.savefig("cun_modelo.png", dpi=260, bbox_inches="tight", pad_inches=0.06, facecolor="white")
