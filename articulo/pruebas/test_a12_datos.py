"""A12. Datos publicables de la empresa (datos/manifiestos_publicables.csv) y su relación con el generador.

Solo se usa el archivo publicable. El libro de datos no publicables no forma parte de la suite.
"""
from __future__ import annotations

import ast
import csv
import re

import generador_sintetico as G
from conftest import RAIZ

COMP = "Datos publicables de los manifiestos"
ARCHIVO = RAIZ / "datos" / "manifiestos_publicables.csv"
COLUMNAS = ["registro", "fecha_viaje", "fecha_escrita_sin_anio", "hora_viaje", "origen", "destino", "asientos",
            "tarifa_soles", "unidad", "conductor", "conductor_en_lista_2025", "licencia_consignada", "pasajeros_listados",
            "total_origen_casilla", "ocupacion_pct", "observacion"]


def _filas():
    with open(ARCHIVO, encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def test_a12_01_estructura(caso):
    caso.definir("A12-01", COMP, "Revisión de estructura", "manifiestos_publicables.csv", (11, 16),
                 "Once manifiestos con las 16 columnas documentadas e identificadores M01 a M11 únicos")
    filas = caso.cronometrar(_filas)
    caso.observar((len(filas), len(filas[0])), margen=0)
    assert (len(filas), list(filas[0])) == (11, COLUMNAS)
    assert sorted(r["registro"] for r in filas) == [f"M{i:02d}" for i in range(1, 12)]


def test_a12_02_asientos_del_generador(caso):
    caso.definir("A12-02", COMP, "Consistencia entre datos y parámetro del generador",
                 "columna asientos; generador_sintetico.ASIENTOS", (16, {"16"}),
                 "El generador usa 16 asientos, el valor que consta en los once manifiestos")
    valores = {r["asientos"] for r in caso.cronometrar(_filas)}
    caso.observar((G.ASIENTOS, valores), margen=0)
    assert valores == {str(G.ASIENTOS)}


def test_a12_03_ruta_y_tarifa(caso):
    caso.definir("A12-03", COMP, "Revisión de valores", "columnas origen, destino y tarifa_soles",
                 ("Soritor", "Tarapoto", "22.00"), "Los manifiestos corresponden a la ruta Soritor–Tarapoto con tarifa "
                 "de S/ 22.00")
    filas = caso.cronometrar(_filas)
    obs = ({r["origen"] for r in filas}, {r["destino"] for r in filas}, {r["tarifa_soles"] for r in filas})
    caso.observar(tuple(sorted(x)[0] if len(x) == 1 else sorted(x) for x in obs), margen=0)
    assert obs == ({"Soritor"}, {"Tarapoto"}, {"22.00"})


def test_a12_04_ocupacion_calculada(caso):
    caso.definir("A12-04", COMP, "Valor calculado (11 filas)", "pasajeros_listados / asientos × 100, a un decimal", 0,
                 "La ocupación registrada es la de los pasajeros listados sobre la capacidad, sin exceder 100 %")
    errores = 0
    for r in caso.cronometrar(_filas):
        p, a = int(r["pasajeros_listados"]), int(r["asientos"])
        errores += int(float(r["ocupacion_pct"]) != round(100 * p / a, 1) or p > a)
    caso.observar(errores)
    assert errores == 0


def test_a12_05_faltantes_no_son_cero(caso):
    caso.definir("A12-05", COMP, "Partición: dato faltante", "columnas unidad, conductor, total_origen_casilla y "
                 "conductor_en_lista_2025", (2, 1, 7, 1),
                 "Los datos que el manifiesto no trae quedan vacíos y nunca se registran como cero; las filas «sin "
                 "placa» no tienen unidad")
    filas = caso.cronometrar(_filas)
    vacios = tuple(sum(1 for r in filas if r[c] == "") for c in
                   ("unidad", "conductor", "total_origen_casilla", "conductor_en_lista_2025"))
    ceros = sum(1 for r in filas for c in ("unidad", "conductor", "total_origen_casilla") if r[c] in ("0", "0.0"))
    sin_placa = [r for r in filas if "sin placa" in r["observacion"]]
    caso.observar(vacios, margen=0)
    assert vacios == (2, 1, 7, 1) and ceros == 0 and all(r["unidad"] == "" for r in sin_placa)


def test_a12_06_solo_codigos_aleatorios(caso):
    caso.definir("A12-06", COMP, "Revisión de privacidad", "columnas unidad y conductor; nombres de columna", 0,
                 "Unidades y conductores figuran solo con códigos aleatorios (U···· y K····) y no hay columnas de "
                 "nombres, documentos, licencias o placas")
    filas = caso.cronometrar(_filas)
    malos = sum(1 for r in filas if r["unidad"] and not re.fullmatch(r"U[A-Z0-9]{4}", r["unidad"]))
    malos += sum(1 for r in filas if r["conductor"] and not re.fullmatch(r"K[A-Z0-9]{4}", r["conductor"]))
    malos += sum(1 for c in filas[0] if re.search(r"nombre|dni|documento|placa|numero_licencia", c))
    caso.observar(malos)
    assert malos == 0


def test_a12_07_hora_del_manifiesto_no_se_usa(caso):
    caso.definir("A12-07", COMP, "Revisión estática del código (árbol sintáctico)", "módulos .py de 02_codigo", 0,
                 "Ningún módulo lee los manifiestos: la hora 04:00 que consta en ellos no se usa como hora real "
                 "de salida mientras no se verifique")
    usos = 0
    for archivo in sorted(RAIZ.glob("*.py")):
        arbol = caso.cronometrar(ast.parse, archivo.read_text(encoding="utf-8"))
        textos = [n.value for n in ast.walk(arbol) if isinstance(n, ast.Constant) and isinstance(n.value, str)]
        usos += sum(1 for t in textos if "manifiesto" in t or "hora_viaje" in t)
    caso.observar(usos)
    assert usos == 0
