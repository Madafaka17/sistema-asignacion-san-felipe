"""A10. Instancias con horarios reales GTFS (generador_gtfs.py): lectura del día, terminales, flota mínima y reglas
de construcción. Usa un GTFS mínimo escrito por la prueba y los dos feeds incluidos en datos/gtfs (sin modificarlos).
"""
from __future__ import annotations

import csv
import random
import zipfile
from collections import Counter

import pytest

import generador_gtfs as GG
from conftest import RAIZ
from metodos import ple_sustituto
from modelo import pares_en_conflicto
from utilidades import emparejamiento_maximo_fuerza_bruta, metricas

COMP = "Generador de instancias GTFS (generador_gtfs.py)"


# ---------------------------------------------------------------------------------------------------- fixtures
def _escribir(carpeta, nombre, filas):
    with open(carpeta / nombre, "w", newline="", encoding="utf-8") as fh:
        csv.writer(fh).writerows(filas)


@pytest.fixture(scope="module")
def gtfs_minimo(tmp_path_factory):
    """Feed mínimo: miércoles 21/10/2026 con servicios activos, añadidos, retirados y vencidos."""
    c = tmp_path_factory.mktemp("gtfs_minimo")
    dias = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    _escribir(c, "agency.txt", [["agency_id", "agency_name"], ["A1", "Uno"], ["A2", "Dos"]])
    _escribir(c, "calendar.txt", [["service_id", *dias, "start_date", "end_date"],
                                  ["WK", 1, 1, 1, 1, 1, 0, 0, "20260101", "20271231"],
                                  ["WE", 0, 0, 0, 0, 0, 1, 1, "20260101", "20271231"],
                                  ["WK2", 1, 1, 1, 1, 1, 0, 0, "20260101", "20271231"],
                                  ["OLD", 1, 1, 1, 1, 1, 0, 0, "20250101", "20260930"]])
    _escribir(c, "calendar_dates.txt", [["service_id", "date", "exception_type"], ["WE", "20261021", 1],
                                        ["WK2", "20261021", 2]])
    _escribir(c, "routes.txt", [["route_id", "agency_id"], ["R1", "A1"], ["R2", "A2"]])
    _escribir(c, "stops.txt", [["stop_id", "stop_name", "stop_lat", "stop_lon"], ["P1", "Terminal Norte", "45.0", "26.0"],
                               ["P2", "Terminal Sur", "45.5", "26.0"], ["P3", "Paradero", "45.2", "26.0"]])
    viajes = {  # trip_id: (servicio, ruta, [(parada, llegada, salida, secuencia), ...])
        "T1": ("WK", "R1", [("P1", "05:00:00", "05:00:00", 1), ("P2", "06:00:00", "06:00:00", 2)]),
        "T2": ("WK", "R1", [("P1", "03:30:00", "03:30:00", 1), ("P2", "04:30:00", "04:30:00", 2)]),
        "T3": ("WK", "R1", [("P1", "06:00:00", "06:00:00", 1), ("P2", "10:30:00", "10:30:00", 2)]),
        "T4": ("WE", "R1", [("P2", "07:00:00", "07:00:00", 1), ("P1", "08:00:00", "08:00:00", 2)]),
        "T5": ("WK2", "R1", [("P1", "09:00:00", "09:00:00", 1), ("P2", "10:00:00", "10:00:00", 2)]),
        "T6": ("OLD", "R1", [("P1", "11:00:00", "11:00:00", 1), ("P2", "12:00:00", "12:00:00", 2)]),
        "T7": ("WK", "R2", [("P1", "09:00:00", "09:00:00", 1), ("P2", "10:30:00", "10:30:00", 2)]),
        "T8": ("WK", "R1", [("P2", "13:40:00", "13:40:00", 3), ("P1", "12:00:00", "12:00:00", 1),
                            ("P3", "12:50:00", "12:55:00", 2)]),
        "T9": ("WK", "R1", [("P1", "25:10:00", "25:10:00", 1), ("P2", "25:40:00", "25:40:00", 2)]),
        "T10": ("WK", "R1", [("P1", "14:00:00", "14:00:00", 1), ("P2", "14:00:00", "14:00:00", 2)]),
        "T11": ("WK", "R1", [("P1", "04:00:00", "04:00:00", 1), ("P2", "08:00:00", "08:00:00", 2)]),
    }
    _escribir(c, "trips.txt", [["route_id", "service_id", "trip_id"]] + [[r, s, t] for t, (s, r, _) in viajes.items()])
    filas = [["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence"]]
    for t, (_, _, paradas) in viajes.items():
        filas += [[t, ll, sa, p, q] for p, ll, sa, q in paradas]
    _escribir(c, "stop_times.txt", filas)
    return c


@pytest.fixture(scope="module")
def feeds(tmp_path_factory):
    """Copias descomprimidas de los dos feeds incluidos (los zip del repositorio no se modifican)."""
    c = tmp_path_factory.mktemp("feeds")
    for nombre in ("lodz", "buzau"):
        with zipfile.ZipFile(RAIZ / "datos" / "gtfs" / f"{nombre}.zip") as z:
            z.extractall(c / nombre)
    return c


def _publicados(archivo):
    return list(csv.DictReader(open(RAIZ / "resultados" / archivo, encoding="utf-8")))


# ---------------------------------------------------------------------------------------------------- casos
def test_a10_01_horas_gtfs(caso):
    caso.definir("A10-01", COMP, "Valores límite del formato de hora GTFS", "04:30:00; 00:00:30; 25:10:30",
                 (270.0, 0.5, 1510.5), "Las horas se convierten a minutos, incluidas las mayores de 24:00 del GTFS")
    obs = tuple(caso.cronometrar(GG._min, t) for t in ("04:30:00", "00:00:30", "25:10:30"))
    caso.observar(obs, margen=0)
    assert obs == (270.0, 0.5, 1510.5)


def test_a10_02_distancia_entre_paradas(caso):
    caso.definir("A10-02", COMP, "Valor calculado a mano", "Δlatitud = 0.001° con la misma longitud", 111.19,
                 "La distancia equirrectangular reproduce 6 371 000 m × 0.001 × π/180")
    obs = caso.cronometrar(GG._distancia, {"stop_lat": "45.0", "stop_lon": "26.0"}, {"stop_lat": "45.001", "stop_lon": "26.0"})
    caso.observar(round(obs, 2), tolerancia=0.01, margen=abs(obs - 111.19492664455873))
    assert abs(obs - 111.19492664455873) <= 1e-6


def test_a10_03_union_de_terminales(caso):
    caso.definir("A10-03", COMP, "Partición: mismo nombre, cercanas con palabra poco frecuente, cercanas sin palabra "
                 "común y lejanas", "5 paradas (Autogara Sud, Buzău Autogara Sud a 111 m, Centru a 56 m, Autogara Nord "
                 "a 11 km y «autogara sud » a 111 km)", "{P1, P2, P5}, {P3}, {P4}",
                 "Se unen paradas con el mismo nombre o a menos de 300 m que comparten una palabra poco frecuente")
    paradas = [{"stop_id": "P1", "stop_name": "Autogara Sud", "stop_lat": "45.0", "stop_lon": "26.0"},
               {"stop_id": "P2", "stop_name": "Buzău Autogara Sud", "stop_lat": "45.001", "stop_lon": "26.0"},
               {"stop_id": "P3", "stop_name": "Centru", "stop_lat": "45.0005", "stop_lon": "26.0"},
               {"stop_id": "P4", "stop_name": "Autogara Nord", "stop_lat": "45.1", "stop_lon": "26.0"},
               {"stop_id": "P5", "stop_name": "autogara sud ", "stop_lat": "46.0", "stop_lon": "26.0"}]
    t = caso.cronometrar(GG._terminales, paradas)
    grupos = sorted(sorted(p for p in t if t[p] == v) for v in set(t.values()))
    caso.observar(grupos, margen=0)
    assert grupos == [["P1", "P2", "P5"], ["P3"], ["P4"]]


def test_a10_04_viajes_del_dia(caso, gtfs_minimo):
    caso.definir("A10-04", COMP, "Partición del calendario y valores límite de los filtros",
                 "feed mínimo, miércoles 21/10/2026: servicios activo, añadido, retirado y vencido; viajes de 0 min, "
                 "240 min, 270 min, a las 03:30, a las 04:00 y después de 24:00", ["T11", "T1", "T4", "T7", "T8", "T9"],
                 "Se leen los viajes activos ese día, con duración en (0, 240] min y salida desde las 04:00, "
                 "ordenados por salida")
    v = caso.cronometrar(GG.viajes_del_dia, gtfs_minimo, "20261021", "wednesday")
    obs = [x[0] for x in v]
    caso.observar(obs, margen=0)
    assert obs == ["T11", "T1", "T4", "T7", "T8", "T9"]
    t8 = next(x for x in v if x[0] == "T8")
    assert (t8[3], t8[4]) == (720.0, 100.0)          # 12:00 a 13:40, según el orden de stop_sequence


def test_a10_05_filtro_por_agencia(caso, gtfs_minimo):
    caso.definir("A10-05", COMP, "Partición: agencia", "feed mínimo; agencia A1", ["T11", "T1", "T4", "T8", "T9"],
                 "Con agencia se excluyen los viajes de rutas de otras agencias")
    obs = [x[0] for x in caso.cronometrar(GG.viajes_del_dia, gtfs_minimo, "20261021", "wednesday", "A1")]
    caso.observar(obs, margen=0)
    assert obs == ["T11", "T1", "T4", "T8", "T9"]


def test_a10_06_flota_minima(caso):
    caso.definir("A10-06", COMP, "Oráculo: emparejamiento máximo por búsqueda exhaustiva (300 conjuntos)",
                 "4 a 8 viajes aleatorios entre 3 terminales", 0,
                 "Número de bloques = viajes − emparejamiento máximo (cobertura mínima de caminos); cada bloque es "
                 "una cadena válida y los bloques cubren todos los viajes una sola vez")
    errores = 0
    for semilla in range(300):
        rng = random.Random(semilla)
        viajes = []
        for k in range(rng.randint(4, 8)):
            a = float(rng.randrange(240, 900, 10))
            viajes.append((f"T{k}", f"X{rng.randint(1, 3)}", f"X{rng.randint(1, 3)}", a, float(rng.choice([30, 60, 90]))))
        viajes.sort(key=lambda v: v[3])
        bloques = caso.cronometrar(GG.bloques_minimos, viajes)
        n = len(viajes)
        aristas = {(i, j) for i in range(n) for j in range(n)
                   if viajes[j][1] == viajes[i][2] and viajes[j][3] >= viajes[i][3] + viajes[i][4] + GG.TRANSICION}
        errores += int(len(bloques) != n - emparejamiento_maximo_fuerza_bruta(n, aristas))
        errores += int(sorted(i for b in bloques for i in b) != list(range(n)))
        errores += sum(1 for b in bloques for i, j in zip(b, b[1:]) if (i, j) not in aristas)
    caso.observar(errores)
    assert errores == 0


def test_a10_07_tamanos_de_los_feeds_reales(caso, feeds):
    publicados = Counter()
    for archivo in ("gtfs_lodz.csv", "gtfs_buzau.csv"):
        for r in _publicados(archivo):
            publicados[(r["grupo"], int(r["n"]))] += 0
    esperado = sorted(publicados)
    caso.definir("A10-07", COMP, "Datos reales: reproducción del tamaño de las instancias publicadas",
                 "feeds incluidos; miércoles 21/10/2026; Łódź por agencia y Buzău completo", esperado,
                 "El número de viajes del día por grupo coincide con el de resultados/gtfs_*.csv")
    obs = []
    agencias = sorted({r["agency_id"] for r in csv.DictReader(open(feeds / "lodz" / "agency.txt", encoding="utf-8-sig"))})
    for ag in agencias:
        obs.append((f"lodz:{ag}", len(caso.cronometrar(GG.viajes_del_dia, feeds / "lodz", "20261021", "wednesday", ag))))
    obs.append(("buzau:todas", len(caso.cronometrar(GG.viajes_del_dia, feeds / "buzau", "20261021", "wednesday"))))
    caso.observar(sorted(obs), margen=0)
    assert sorted(obs) == esperado


def test_a10_08_recursos_de_las_instancias_publicadas(caso, feeds):
    caso.definir("A10-08", COMP, "Datos reales: reproducción de unidades y conductores publicados",
                 "Łódź (5 agencias × 10 semillas) y Buzău (5 semillas)", 0,
                 "Con la misma semilla, la flota mínima y la plantilla generada coinciden con las publicadas")
    filas = {}
    for archivo in ("gtfs_lodz.csv", "gtfs_buzau.csv"):
        for r in _publicados(archivo):
            filas[(r["grupo"], int(r["instancia"]))] = (int(r["vehiculos"]), int(r["conductores"]))
    diferencias = 0
    cache = {}
    for (grupo, semilla), esperado in sorted(filas.items()):
        nombre, ag = grupo.split(":")
        if grupo not in cache:
            cache[grupo] = GG.viajes_del_dia(feeds / nombre, "20261021", "wednesday", None if ag == "todas" else ag)
        _, info = caso.cronometrar(GG.construir_instancia_gtfs, cache[grupo], semilla)
        diferencias += int((info["vehiculos"], info["conductores"]) != esperado)
    caso.observar(f"{diferencias} de {len(filas)}", margen=0)
    assert diferencias == 0


def test_a10_09_reglas_de_las_alternativas(caso, feeds):
    caso.definir("A10-09", COMP, "Regla de negocio (Łódź, 5 agencias × 3 semillas; Buzău, 2 semillas)",
                 "instancias GTFS de los feeds incluidos", 0,
                 "Hasta 5 alternativas por servicio, demora de 0, 10 o 20 min respecto de la salida del GTFS, fin "
                 "dentro del día y plantilla ≥ round(1.19 × unidades)")
    errores = 0
    agencias = sorted({r["agency_id"] for r in csv.DictReader(open(feeds / "lodz" / "agency.txt", encoding="utf-8-sig"))})
    casos = [(feeds / "lodz", ag, s) for ag in agencias for s in (101, 102, 103)] + \
            [(feeds / "buzau", None, s) for s in (101, 102)]
    for carpeta, ag, semilla in casos:
        viajes = GG.viajes_del_dia(carpeta, "20261021", "wednesday", ag)
        inst, info = caso.cronometrar(GG.construir_instancia_gtfs, viajes, semilla)
        salida = {f"S{k + 1:04d}": v for k, v in enumerate(sorted(viajes, key=lambda v: v[3]))}
        errores += int(info["conductores"] < round(info["vehiculos"] * 1.19))
        for s in inst.servicios_con_opciones():
            errores += int(not 1 <= len(s.alternativas) <= GG.ALTERNATIVAS[1])
            for a in s.alternativas:
                errores += int(round(a.inicio - salida[s.id][3], 6) not in (0.0, 10.0, 20.0))
                errores += int(a.inicio + a.duracion > info["fin_dia"] or a.duracion != salida[s.id][4])
    caso.observar(errores)
    assert errores == 0


def test_a10_10_instancias_reales_factibles(caso, feeds):
    caso.definir("A10-10", COMP, "Oráculo: solución de la PLE validada de forma independiente",
                 "Łódź, agencias MARCEL (12 viajes), MFTRAN y PHUOLA (34 viajes); semillas 101 a 103", 0,
                 "Las instancias construidas sobre horarios reales admiten una programación sin incumplimientos")
    incumplimientos = 0
    for ag in ("MARCEL", "MFTRAN", "PHUOLA"):
        viajes = GG.viajes_del_dia(feeds / "lodz", "20261021", "wednesday", ag)
        for semilla in (101, 102, 103):
            inst, info = GG.construir_instancia_gtfs(viajes, semilla)
            pares = pares_en_conflicto(inst.servicios_con_opciones(), GG.TRANSICION)
            prog, estado = caso.cronometrar(ple_sustituto, inst, pares, info["fin_dia"], 120)
            incumplimientos += 99 if prog is None else metricas(prog, inst, GG.TRANSICION)["incumplimientos"]
    caso.observar(incumplimientos)
    assert incumplimientos == 0
