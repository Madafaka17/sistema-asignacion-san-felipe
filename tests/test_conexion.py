"""Pruebas de la lectura de configuración de la base de datos (no requieren MySQL)."""

import pytest

from src.datos.conexion import ConfiguracionBD, cargar_configuracion

ENTORNO_VALIDO = {
    "DB_HOST": "127.0.0.1",
    "DB_PORT": "3307",
    "DB_NAME": "san_felipe",
    "DB_USER": "san_felipe_app",
    "DB_PASSWORD": "secreto",
}


def test_carga_todas_las_variables():
    config = cargar_configuracion(ENTORNO_VALIDO)
    assert config == ConfiguracionBD("127.0.0.1", 3307, "san_felipe", "san_felipe_app", "secreto")


def test_puerto_por_defecto_es_3306():
    entorno = {k: v for k, v in ENTORNO_VALIDO.items() if k != "DB_PORT"}
    assert cargar_configuracion(entorno).puerto == 3306


@pytest.mark.parametrize("variable", ["DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD"])
def test_falta_variable_obligatoria(variable):
    entorno = {**ENTORNO_VALIDO, variable: ""}
    with pytest.raises(RuntimeError, match=variable):
        cargar_configuracion(entorno)


@pytest.mark.parametrize("puerto", ["abc", "0", "70000"])
def test_puerto_invalido(puerto):
    with pytest.raises(RuntimeError, match="DB_PORT"):
        cargar_configuracion({**ENTORNO_VALIDO, "DB_PORT": puerto})


def test_la_contrasena_no_se_muestra_al_imprimir():
    assert "secreto" not in repr(cargar_configuracion(ENTORNO_VALIDO))
