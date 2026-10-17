"""Pruebas de coherencia de config/parametros_ga.yaml."""

from pathlib import Path

import pytest
import yaml

RUTA_PARAMETROS = Path(__file__).resolve().parents[1] / "config" / "parametros_ga.yaml"


@pytest.fixture(scope="module")
def parametros():
    with RUTA_PARAMETROS.open(encoding="utf-8") as archivo:
        return yaml.safe_load(archivo)


def test_contiene_todas_las_secciones(parametros):
    secciones = {"semilla_aleatoria", "poblacion", "seleccion", "cruce", "mutacion",
                 "elitismo", "parada", "aptitud", "reglas_operativas"}
    assert secciones <= parametros.keys()


def test_semilla_es_entera_o_nula(parametros):
    semilla = parametros["semilla_aleatoria"]
    assert semilla is None or (isinstance(semilla, int) and semilla >= 0)


def test_probabilidades_entre_0_y_1(parametros):
    probabilidades = [
        parametros["poblacion"]["proporcion_heuristica"],
        parametros["cruce"]["probabilidad"],
        parametros["mutacion"]["probabilidad_gen"],
        parametros["mutacion"]["probabilidad_intercambio"],
    ]
    assert all(0 <= p <= 1 for p in probabilidades)


def test_tamanos_compatibles_con_la_poblacion(parametros):
    tamano = parametros["poblacion"]["tamano"]
    assert 2 <= parametros["seleccion"]["num_padres"] <= tamano
    assert 2 <= parametros["seleccion"]["tamano_torneo"] <= tamano
    assert 0 <= parametros["elitismo"]["num_elites"] < tamano


def test_criterios_de_parada_positivos(parametros):
    parada = parametros["parada"]
    assert parada["max_generaciones"] > 0
    assert 0 < parada["generaciones_sin_mejora"] <= parada["max_generaciones"]
    assert 0 < parada["aptitud_objetivo"] <= 1
    assert parada["tiempo_maximo_s"] > 0


def test_restricciones_duras_pesan_mas_que_las_blandas(parametros):
    duras = parametros["aptitud"]["pesos_restricciones_duras"].values()
    blandas = parametros["aptitud"]["pesos_restricciones_blandas"].values()
    assert min(duras) > max(blandas) > 0


def test_reglas_operativas_positivas(parametros):
    assert all(valor > 0 for valor in parametros["reglas_operativas"].values())
