"""Configuración común de las pruebas del código del artículo y registro de casos.

Cada prueba declara su caso con el accesorio `caso`:

    caso.definir("A01-03", componente="Pares en conflicto", tecnica="Valor límite",
                 entrada="holgura = transición = 10 min", esperado=0, descripcion="...")
    resultado = caso.cronometrar(pares_en_conflicto, servicios, 10.0)
    caso.observar(len(resultado))

Al terminar la sesión se escribe `salidas/casos.jsonl` con identificador, componente, técnica, vector de
entrada crítico, valor esperado, observado, margen de error, tolerancia, latencia de la función bajo prueba y
resultado (passed, failed o xfailed). Es el mismo formato que usa la suite del núcleo de la tesis.
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import pytest

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent                       # carpeta 02_codigo
for ruta in (RAIZ, AQUI):
    if str(ruta) not in sys.path:
        sys.path.insert(0, str(ruta))

SALIDA = Path(os.environ.get("SALIDA_PRUEBAS", AQUI / "salidas"))
_REGISTROS: list[dict] = []


class Caso:
    def __init__(self, nodeid: str):
        self.datos: dict = {"nodeid": nodeid}

    def definir(self, identificador, componente, tecnica, entrada, esperado, descripcion):
        self.datos.update(id=identificador, componente=componente, tecnica=tecnica,
                          entrada=entrada, esperado=esperado, descripcion=descripcion)
        return self

    def cronometrar(self, funcion, *args, **kwargs):
        """Ejecuta la función bajo prueba y acumula su latencia (perf_counter): media, máximo y llamadas."""
        t0 = time.perf_counter()
        salida = funcion(*args, **kwargs)
        ms = (time.perf_counter() - t0) * 1000.0
        lat = self.datos.setdefault("_latencias", [])
        lat.append(ms)
        self.datos.update(latencia_ms=sum(lat) / len(lat), latencia_max_ms=max(lat), llamadas=len(lat))
        return salida

    def observar(self, observado, tolerancia=0.0, margen=None):
        esperado = self.datos.get("esperado")
        if margen is None and isinstance(observado, (int, float)) and isinstance(esperado, (int, float)) \
                and not isinstance(observado, bool) and not isinstance(esperado, bool):
            margen = abs(float(observado) - float(esperado))
        self.datos.update(observado=observado, tolerancia=tolerancia, margen=margen)


@pytest.fixture
def caso(request):
    c = Caso(request.node.nodeid)
    request.node._caso = c
    return c


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    resultado = yield
    informe = resultado.get_result()
    if informe.when == "call" or (informe.when == "setup" and informe.outcome != "passed"):
        c = getattr(item, "_caso", None)
        registro = {k: v for k, v in c.datos.items() if k != "_latencias"} if c else {"nodeid": item.nodeid}
        estado = "xfailed" if hasattr(informe, "wasxfail") and informe.outcome == "skipped" else informe.outcome
        registro.update(resultado=estado, duracion_prueba_ms=informe.duration * 1000.0)
        _REGISTROS.append(registro)


def pytest_sessionfinish(session, exitstatus):
    SALIDA.mkdir(parents=True, exist_ok=True)
    with open(SALIDA / "casos.jsonl", "w", encoding="utf8") as fh:
        for r in _REGISTROS:
            fh.write(json.dumps(r, ensure_ascii=False, default=str) + "\n")
