"""Figura de resultados de las pruebas de concepto (v1), monocromática:
la identidad de cada método se codifica con forma de marcador y estilo de
línea (no con color), para que sea legible en escala de grises."""
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager

R = json.load(open(Path(__file__).with_name('resumen.json'), encoding='utf8'))['resultados']
NS = [7, 14, 28, 56, 112]
ESTILO = {  # método: (etiqueta, marcador, estilo de línea)
    'PLE':   ('Programación lineal entera', 'o', '-'),
    'AG':    ('Algoritmo genético', 's', '--'),
    'Tabu':  ('Búsqueda tabú', '^', '-.'),
    'Voraz': ('Algoritmo voraz', 'D', ':'),
}
plt.rcParams.update({
    'font.family': 'Liberation Serif', 'font.size': 9, 'axes.edgecolor': '#555555',
    'axes.linewidth': 0.6, 'xtick.color': '#333333', 'ytick.color': '#333333',
    'axes.labelcolor': '#111111', 'axes.titlesize': 9.5, 'axes.titleweight': 'bold',
})
fig, axes = plt.subplots(1, 3, figsize=(6.3, 2.6), dpi=300)
paneles = [
    ('tiempo_medio_por_n', 'a) Tiempo medio (s, log.)', 'log'),
    ('brecha_por_n', 'b) Brecha media (%)', 'linear'),
    ('incumplimientos_por_n', 'c) Incumplimientos medios', 'linear'),
]
for ax, (clave, titulo, escala) in zip(axes, paneles):
    for m, (lab, mk, ls) in ESTILO.items():
        ys = [R[m][clave][str(n)] for n in NS]
        ax.plot(NS, ys, color='#111111', lw=1.0, ls=ls, marker=mk, ms=4.2,
                markerfacecolor='white', markeredgewidth=0.9, label=lab)
    ax.set_xscale('log', base=2)
    ax.set_xticks(NS); ax.set_xticklabels([str(n) for n in NS])
    ax.set_yscale(escala)
    ax.set_title(titulo, loc='left')
    ax.set_xlabel('Servicios por turno (n)')
    ax.grid(True, which='major', color='#DDDDDD', lw=0.5)
    ax.set_axisbelow(True)
    for s in ('top', 'right'):
        ax.spines[s].set_visible(False)
axes[1].set_ylim(-3, 103)
axes[2].set_ylim(bottom=-1)
h, l = axes[0].get_legend_handles_labels()
fig.legend(h, l, loc='upper center', ncol=4, frameon=False, fontsize=8.5,
           bbox_to_anchor=(0.5, 1.02), handlelength=2.6)
fig.tight_layout(rect=(0, 0, 1, 0.9))
fig.savefig(Path(__file__).with_name('figura_poc.png'), dpi=300, facecolor='white')
print('ok')
