"""A11. Análisis de resultados (analisis.py): A12 de Vargha y Delaney, corrección de Holm, percentil 95, brecha y
protocolo de selección por etapas; reproducción de los resúmenes publicados."""
from __future__ import annotations

import contextlib
import csv
import io
import re
import sys

import pytest

import analisis
from analisis import METODOS, a12, holm, percentil95
from conftest import RAIZ

COMP = "Análisis estadístico y protocolo de selección (analisis.py)"
CAMPOS = ["fuente", "grupo", "metodo", "n", "instancia", "semilla", "tiempo_s", "J", "incumplimientos", "validador",
          "retraso", "reprogramados", "tiempo_muerto", "desequilibrio", "vehiculos", "conductores", "extra"]


def _analisis(archivo, *opciones):
    """Ejecuta analisis.main() con los argumentos de la línea de órdenes y devuelve lo que imprime."""
    argv = sys.argv
    sys.argv = ["analisis.py", str(archivo), *opciones]
    try:
        with contextlib.redirect_stdout(io.StringIO()) as buf:
            analisis.main()
    finally:
        sys.argv = argv
    return buf.getvalue()


def test_a11_01_a12_valores_conocidos(caso):
    caso.definir("A11-01", COMP, "Valores calculados a mano", "x = y; x < y; x > y; x = (1, 2, 3), y = (2, 3, 4)",
                 (0.5, 1.0, 0.0, 7 / 9), "A12 es la probabilidad de que un valor de x sea menor que uno de y (empates 1/2)")
    obs = (caso.cronometrar(a12, [1, 2], [1, 2]), a12([1, 2], [3, 4]), a12([3, 4], [1, 2]), a12([1, 2, 3], [2, 3, 4]))
    caso.observar(tuple(round(v, 6) for v in obs), margen=abs(obs[3] - 7 / 9))
    assert obs[:3] == (0.5, 1.0, 0.0) and abs(obs[3] - 7 / 9) <= 1e-12


def test_a11_02_holm(caso):
    caso.definir("A11-02", COMP, "Valores calculados a mano", "p = (0.01, 0.04, 0.03, 0.005) y p = (0.5, 0.6)",
                 ([0.03, 0.06, 0.06, 0.02], [1.0, 1.0]),
                 "Holm multiplica el k-ésimo menor p por (m − k + 1), impone monotonía y acota en 1")
    a = caso.cronometrar(holm, [0.01, 0.04, 0.03, 0.005])
    b = holm([0.5, 0.6])
    caso.observar(([round(x, 12) for x in a], b), margen=max(abs(x - y) for x, y in zip(a, [0.03, 0.06, 0.06, 0.02])))
    assert all(abs(x - y) <= 1e-12 for x, y in zip(a, [0.03, 0.06, 0.06, 0.02])) and b == [1.0, 1.0]


@pytest.mark.parametrize("n,esperado", [(1, 1), (19, 19), (20, 20), (21, 20), (100, 96)])
def test_a11_03_percentil95_valores_limite(caso, n, esperado):
    caso.definir(f"A11-03-N{n}", COMP, "Valor límite del índice", f"valores 1, 2, …, {n}", esperado,
                 "El percentil 95 es el elemento de posición int(0.95 × n) de la lista ordenada (rango más cercano por "
                 "exceso)")
    obs = caso.cronometrar(percentil95, list(range(n, 0, -1)))
    caso.observar(obs)
    assert obs == esperado


def _fila(metodo, n, inst, semilla, J, validador=0, tiempo=0.1, grupo="g", extra=""):
    return dict(fuente="prueba", grupo=grupo, metodo=metodo, n=n, instancia=inst, semilla=semilla, tiempo_s=tiempo, J=J,
                incumplimientos=validador, validador=validador, retraso=0, reprogramados=0, tiempo_muerto=0,
                desequilibrio=0, vehiculos=1, conductores=1, extra=extra)


@pytest.mark.filterwarnings("ignore:invalid value encountered:RuntimeWarning")
def test_a11_04_brecha_y_protocolo_en_los_limites(caso, tmp_path):
    caso.definir("A11-04", COMP, "Valores límite del protocolo (resultados construidos)",
                 "AG_v1 en n = 10: 99 % factibles, 95 % a ≤ 1 % del óptimo, p95 = 306 s (300 s + 2 %); "
                 "en n = 20: 98 % factibles", "punto de quiebre 10; falla factibilidad en n = 20",
                 "Se aprueba un tamaño en el límite exacto de cada umbral y el punto de quiebre es el último tamaño "
                 "aprobado; una corrida infactible tiene brecha 100 %")
    filas = []
    for n, factibles in ((10, 99), (20, 98)):
        for inst in range(20):
            for metodo in METODOS:
                if metodo in ("EXACTO", "PLE_sustituto", "PLE+BL", "Voraz"):
                    filas.append(_fila(metodo, n, inst, 0, 1.0, extra="certificado=True" if metodo == "EXACTO" else ""))
                    continue
                for s in range(1, 6):
                    k = inst * 5 + (s - 1)                     # 0..99: índice de la corrida en el tamaño
                    if metodo != "AG_v1":
                        filas.append(_fila(metodo, n, inst, s, 1.0))
                        continue
                    validador = 1 if k >= factibles else 0
                    J = 1.0 if k < 95 else 1.05               # 95 corridas a 0 % y el resto a 5 % del óptimo
                    tiempo = 306.0 if k >= 95 else 1.0         # percentil 95 (posición 95 de 100) = 306 s
                    filas.append(_fila(metodo, n, inst, s, J, validador=validador, tiempo=tiempo))
    archivo = tmp_path / "construido.csv"
    with open(archivo, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=CAMPOS)
        w.writeheader()
        w.writerows(filas)
    salida = caso.cronometrar(_analisis, archivo)
    linea = next(l for l in salida.splitlines() if l.strip().startswith("AG_v1") and "punto de quiebre" in l)
    medias = re.search(r"AG_v1\n\s+g n=10:\s+([\d.]+) \|\s+([\d.]+)", salida)
    caso.observar(linea.strip(), margen=None)
    assert re.search(r"punto de quiebre\s+10 .*falla factibilidad en n=20", linea)
    assert medias and float(medias.group(2)) == 99.0 and abs(float(medias.group(1)) - (4 * 5 + 100) / 100) < 0.01


@pytest.mark.parametrize("csv_publicado,resumen,opciones", [
    ("sintetico.csv", "resumen_sintetico.txt", ()),
    ("sintetico_52c56u.csv", "resumen_sintetico_52c56u.txt", ()),
    ("gtfs_lodz.csv", "resumen_gtfs_lodz.txt", ()),
    ("gtfs_buzau.csv", "resumen_gtfs_buzau.txt", ("--volumen-real", "241")),
])
def test_a11_05_reproduce_resumenes_publicados(caso, csv_publicado, resumen, opciones):
    publicado = (RAIZ / "resultados" / resumen).read_text(encoding="utf-8")
    caso.definir(f"A11-05-{resumen.replace('resumen_', '').replace('.txt', '')}", COMP,
                 "Reproducción con datos registrados", f"analisis.py resultados/{csv_publicado} {' '.join(opciones)}".strip(),
                 f"igual a resultados/{resumen}", "El análisis vuelve a producir, línea por línea, el resumen publicado")
    salida = caso.cronometrar(_analisis, RAIZ / "resultados" / csv_publicado, *opciones)
    a, b = salida.strip().splitlines(), publicado.strip().splitlines()
    distintas = [i for i, (x, y) in enumerate(zip(a, b)) if x != y] + list(range(min(len(a), len(b)), max(len(a), len(b))))
    caso.observar(f"{len(distintas)} líneas distintas de {len(b)}", margen=len(distintas))
    assert not distintas, (distintas[:3], [a[i] if i < len(a) else None for i in distintas[:3]])
