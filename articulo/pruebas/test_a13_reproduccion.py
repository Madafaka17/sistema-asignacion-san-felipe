"""A13. Reproducción de corridas publicadas (resultados/*.csv) con experimento.correr y las mismas semillas.

La repetición completa de 15 instancias sintéticas, 9 instancias de Łódź y la variante con la plantilla de la
empresa, con la desviación estándar de los métodos estocásticos, la hace pruebas/reproduccion.py.
"""
from __future__ import annotations

import csv

import pytest

import experimento
import generador_sintetico as G
from conftest import RAIZ
from utilidades import comparar

COMP = "Reproducción de resultados publicados (experimento.py)"


def _publicadas(archivo, n, instancia):
    return [r for r in csv.DictReader(open(RAIZ / "resultados" / archivo, encoding="utf-8"))
            if int(r["n"]) == n and int(r["instancia"]) == instancia]


@pytest.mark.parametrize("n,instancia", [(7, 101), (7, 102), (14, 101), (14, 102)])
def test_a13_01_sintetico(caso, n, instancia):
    caso.definir(f"A13-01-n{n}-{instancia}", COMP, "Reproducción con datos registrados",
                 f"sintético n = {n}, instancia {instancia}; 7 métodos; semillas 1 a 5", "19 filas iguales",
                 "Las 19 corridas de la instancia (4 deterministas y 3 métodos estocásticos × 5 semillas) repiten J, "
                 "incumplimientos, validador, componentes de J y certificado del exacto")
    filas = caso.cronometrar(experimento.tarea_sintetica, (n, instancia, 5))
    total, distintas, peor = comparar(filas, _publicadas("sintetico.csv", n, instancia))
    caso.observar(f"{total - distintas} de {total} iguales", tolerancia=1e-9, margen=peor)
    assert total == 19 and distintas == 0


def test_a13_02_plantilla_de_la_empresa(caso, monkeypatch):
    caso.definir("A13-02", COMP, "Reproducción con datos registrados",
                 "CONDUCTORES_EMPRESA (52 para 56 unidades); n = 14, instancia 101", "19 filas iguales",
                 "La variante con la plantilla de la empresa repite las corridas publicadas en sintetico_52c56u.csv")
    monkeypatch.setattr(G, "CONDUCTORES_LISTA", 52)
    monkeypatch.setattr(G, "UNIDADES_ACTIVAS_DIA", 56)
    filas = caso.cronometrar(experimento.tarea_sintetica, (14, 101, 5))
    total, distintas, peor = comparar(filas, _publicadas("sintetico_52c56u.csv", 14, 101))
    caso.observar(f"{total - distintas} de {total} iguales", tolerancia=1e-9, margen=peor)
    assert total == 19 and distintas == 0
