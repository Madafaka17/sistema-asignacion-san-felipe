"""Pruebas de integración contra MySQL.

Se omiten por defecto. Para ejecutarlas, con la base de datos levantada
(docker compose up -d) y el archivo .env configurado:

    PRUEBAS_BD=1 pytest -m integracion          # Linux / macOS
    $env:PRUEBAS_BD=1; pytest -m integracion    # Windows PowerShell
"""

import os

import pytest

from src.datos.conexion import obtener_conexion

pytestmark = [
    pytest.mark.integracion,
    pytest.mark.skipif(os.getenv("PRUEBAS_BD") != "1", reason="defina PRUEBAS_BD=1 para usar MySQL"),
]

TABLAS_ESPERADAS = {
    "usuario", "categoria_licencia", "vehiculo", "conductor", "ruta",
    "horario", "programacion", "asignacion", "historial_aptitud",
}


def consultar(sql, parametros=()):
    with obtener_conexion() as conexion:
        cursor = conexion.cursor()
        cursor.execute(sql, parametros)
        filas = cursor.fetchall()
        cursor.close()
    return filas


def test_existen_todas_las_tablas():
    filas = consultar(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE'"
    )
    assert TABLAS_ESPERADAS <= {nombre for (nombre,) in filas}


def test_datos_de_ejemplo_cargados():
    ((vehiculos, conductores, horarios),) = consultar(
        "SELECT (SELECT COUNT(*) FROM vehiculo), (SELECT COUNT(*) FROM conductor), "
        "(SELECT COUNT(*) FROM horario)"
    )
    assert (vehiculos, conductores, horarios) == (8, 12, 19)


@pytest.mark.parametrize("dia, salidas_esperadas", [("LUN", 18), ("DOM", 14)])
def test_salidas_por_dia(dia, salidas_esperadas):
    ((salidas,),) = consultar(
        "SELECT COUNT(*) FROM horario WHERE activo AND FIND_IN_SET(%s, dias_operacion)", (dia,)
    )
    assert salidas == salidas_esperadas


def test_recursos_disponibles_para_programar():
    ((vehiculos,),) = consultar("SELECT COUNT(*) FROM vehiculo WHERE estado = 'operativo'")
    ((conductores,),) = consultar(
        "SELECT COUNT(*) FROM conductor "
        "WHERE estado = 'activo' AND fecha_vencimiento_licencia >= CURDATE()"
    )
    assert (vehiculos, conductores) == (7, 10)
