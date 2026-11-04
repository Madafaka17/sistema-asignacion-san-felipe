"""A03. Reparación (reparacion.py): reglas de conservación y traslado, límite de conducción, pasadas y propiedades."""
from __future__ import annotations

import hashlib
import os
import random
import subprocess
import sys

from modelo import Instancia, Servicio, pares_en_conflicto
from reparacion import reparar
from utilidades import PESOS, alt, instancia_aleatoria, instancia_control, metricas, programa_aleatorio

COMP = "Reparación de programaciones (reparacion.py)"
REF = {"retraso": 60.0, "reprogramacion": 1.0, "tiempo_muerto": 60.0, "desequilibrio": 60.0}


def _inst(servicios, limites=None, previa=None):
    conductores = {a.conductor for s in servicios for a in s.alternativas}
    lim = {c: 600.0 for c in conductores}
    lim.update(limites or {})
    return Instancia(servicios=tuple(servicios), conduccion_previa=dict(previa or {}), limite_conduccion=lim,
                     pesos=dict(PESOS), referencias=dict(REF))


def _reparar(inst, programa, t=10.0, **kw):
    return reparar(programa, inst, pares_en_conflicto(inst.servicios_con_opciones(), t), **kw)


def test_a03_01_programacion_factible_no_cambia(caso):
    caso.definir("A03-01", COMP, "Partición: programación sin incumplimientos",
                 "instancia de control, Y = (1, 1, 1, 0)", [1, 1, 1, 0],
                 "Una programación factible se devuelve sin cambios")
    obs = caso.cronometrar(_reparar, instancia_control(), [1, 1, 1, 0])
    caso.observar(obs, margen=0)
    assert obs == [1, 1, 1, 0]


def test_a03_02_se_conserva_el_de_mayor_prioridad(caso):
    caso.definir("A03-02", COMP, "Regla de negocio: prioridad",
                 "S1 (prioridad 1, sale a 0) y S2 (prioridad 3, sale a 50) en (V1, C1)", [1, 0],
                 "Se conserva S2 aunque salga después, y S1 pasa a su otra alternativa")
    inst = _inst([Servicio("S1", 1, (alt("S1", "V1", "C1", 0, 100), alt("S1", "V3", "C3", 300, 100, "h1"))),
                  Servicio("S2", 3, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 200, 100, "h1")))])
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar(obs, margen=0)
    assert obs == [1, 0]


def test_a03_03_empate_se_conserva_el_mas_temprano(caso):
    caso.definir("A03-03", COMP, "Regla de negocio: empate de prioridad",
                 "S1 y S2 con prioridad 2; S1 sale a 0 y S2 a 50 en (V1, C1)", [0, 1],
                 "Con igual prioridad se conserva el de salida más temprana")
    inst = _inst([Servicio("S1", 2, (alt("S1", "V1", "C1", 0, 100), alt("S1", "V3", "C3", 300, 100, "h1"))),
                  Servicio("S2", 2, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 200, 100, "h1")))])
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar(obs, margen=0)
    assert obs == [0, 1]


def test_a03_04_empate_total_se_mueve_el_siguiente(caso):
    caso.definir("A03-04", COMP, "Valor límite: misma prioridad y misma salida",
                 "S1 y S2 con prioridad 2, ambos salen a 50 en (V1, C1)", [0, 1],
                 "Si también empatan en la salida, se conserva el servicio de menor índice")
    inst = _inst([Servicio("S1", 2, (alt("S1", "V1", "C1", 50, 100), alt("S1", "V3", "C3", 300, 100, "h1"))),
                  Servicio("S2", 2, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 200, 100, "h1")))])
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar(obs, margen=0)
    assert obs == [0, 1]


def test_a03_05_primera_alternativa_por_hora_de_salida(caso):
    caso.definir("A03-05", COMP, "Regla de negocio: orden de búsqueda",
                 "S2 con alternativas a 50 (actual), 400, 150 y 105 (en conflicto); transición = 10", [0, 2],
                 "El servicio movido pasa a la primera alternativa, por hora de salida, sin conflictos")
    inst = _inst([Servicio("S1", 3, (alt("S1", "V1", "C1", 0, 100),)),
                  Servicio("S2", 1, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 400, 100, "h1"),
                                     alt("S2", "V2", "C2", 150, 100, "h2"), alt("S2", "V1", "C1", 105, 100, "h3")))])
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar(obs, margen=0)
    assert obs == [0, 2]


def test_a03_06_si_no_puede_moverse_se_mueve_el_conservado(caso):
    caso.definir("A03-06", COMP, "Regla de negocio: segundo intento",
                 "S2 (prioridad 1) sin otra alternativa; S1 (prioridad 3) con una alternativa libre", [1, 0],
                 "Si el servicio que debía moverse no tiene alternativa válida, se mueve el conservado")
    inst = _inst([Servicio("S1", 3, (alt("S1", "V1", "C1", 0, 100), alt("S1", "V2", "C2", 300, 100, "h1"))),
                  Servicio("S2", 1, (alt("S2", "V1", "C1", 50, 100),))])
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar(obs, margen=0)
    assert obs == [1, 0]


def test_a03_07_conflicto_irresoluble_se_conserva(caso):
    caso.definir("A03-07", COMP, "Partición: conflicto sin solución",
                 "S1 y S2 con una sola alternativa cada uno, superpuestas en (V1, C1)", ([0, 0], 1),
                 "Lo que no se puede resolver queda en la programación y lo penaliza la aptitud")
    inst = _inst([Servicio("S1", 3, (alt("S1", "V1", "C1", 0, 100),)),
                  Servicio("S2", 1, (alt("S2", "V1", "C1", 50, 100),))])
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar((obs, metricas(obs, inst, 10.0)["incumplimientos"]), margen=0)
    assert obs == [0, 0] and metricas(obs, inst, 10.0)["incumplimientos"] == 1


def test_a03_08_exceso_de_conduccion_mueve_el_menos_prioritario_y_mas_tardio(caso):
    caso.definir("A03-08", COMP, "Regla de negocio: conductor sobre su límite",
                 "C1 con 3 servicios de 100 min y límite 200; S2 y S3 con prioridad 1 (S3 más tardío)", [0, 0, 1],
                 "Se mueve primero el servicio de menor prioridad y, en empate, el más tardío; basta un traslado")
    inst = _inst([Servicio("S1", 2, (alt("S1", "V1", "C1", 0, 100), alt("S1", "V3", "C3", 0, 100, "h1"))),
                  Servicio("S2", 1, (alt("S2", "V2", "C1", 200, 100), alt("S2", "V4", "C4", 200, 100, "h1"))),
                  Servicio("S3", 1, (alt("S3", "V5", "C1", 400, 100), alt("S3", "V6", "C5", 400, 100, "h1")))],
                 limites={"C1": 200.0})
    obs = caso.cronometrar(_reparar, inst, [0, 0, 0])
    caso.observar(obs, margen=0)
    assert obs == [0, 0, 1]


def test_a03_09_destino_justo_en_el_limite_se_acepta(caso):
    caso.definir("A03-09", COMP, "Valor límite: carga del destino = límite",
                 "mover S2 (100 min) a C2 con límite 100", [0, 1],
                 "Un traslado que deja al nuevo conductor exactamente en su límite es válido")
    inst = _inst([Servicio("S1", 3, (alt("S1", "V1", "C1", 0, 100),)),
                  Servicio("S2", 1, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 200, 100, "h1")))],
                 limites={"C2": 100.0})
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar(obs, margen=0)
    assert obs == [0, 1]


def test_a03_10_destino_sobre_el_limite_se_rechaza(caso):
    caso.definir("A03-10", COMP, "Valor límite: carga del destino = límite + 1",
                 "mover S2 (100 min) a C2 con límite 99", [0, 0],
                 "Un traslado que dejaría al nuevo conductor sobre su límite no se hace")
    inst = _inst([Servicio("S1", 3, (alt("S1", "V1", "C1", 0, 100),)),
                  Servicio("S2", 1, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 200, 100, "h1")))],
                 limites={"C2": 99.0})
    obs = caso.cronometrar(_reparar, inst, [0, 0])
    caso.observar(obs, margen=0)
    assert obs == [0, 0]


def test_a03_11_cero_pasadas(caso):
    caso.definir("A03-11", COMP, "Valor límite: pasadas_max = 0", "conflicto reparable, pasadas_max = 0", [0, 0],
                 "Sin pasadas no se hace ningún cambio")
    inst = _inst([Servicio("S1", 3, (alt("S1", "V1", "C1", 0, 100),)),
                  Servicio("S2", 1, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 200, 100, "h1")))])
    obs = caso.cronometrar(_reparar, inst, [0, 0], pasadas_max=0)
    caso.observar(obs, margen=0)
    assert obs == [0, 0]


def test_a03_12_no_aumenta_incumplimientos_ni_exceso(caso):
    caso.definir("A03-12", COMP, "Propiedad (4000 programaciones aleatorias)",
                 "400 instancias (n = 10, |A_s| ≤ 4, con conducción previa) × 10 programaciones", "0 aumentos",
                 "La reparación nunca aumenta Φ (conflictos + conductores excedidos) ni el exceso E")
    rng = random.Random(1)
    aumentos, total = 0, 0
    for semilla in range(400):
        inst = instancia_aleatoria(semilla, n=10, k_max=4)
        servicios = inst.servicios_con_opciones()
        pares = pares_en_conflicto(servicios, 10.0)
        for _ in range(10):
            x = programa_aleatorio(servicios, rng)
            y = caso.cronometrar(reparar, x, inst, pares)
            a, b = metricas(x, inst, 10.0), metricas(y, inst, 10.0)
            aumentos += int(b["incumplimientos"] > a["incumplimientos"] or b["exceso"] > a["exceso"] + 1e-9)
            total += 1
    caso.observar(f"{aumentos} de {total}", margen=0)
    assert aumentos == 0


def test_a03_13_no_modifica_la_entrada(caso):
    caso.definir("A03-13", COMP, "Ausencia de efectos secundarios", "programación [0, 0] con conflicto reparable",
                 ([0, 0], [0, 1]), "Devuelve una lista nueva y deja intacta la recibida")
    inst = _inst([Servicio("S1", 3, (alt("S1", "V1", "C1", 0, 100),)),
                  Servicio("S2", 1, (alt("S2", "V1", "C1", 50, 100), alt("S2", "V2", "C2", 200, 100, "h1")))])
    x = [0, 0]
    y = caso.cronometrar(_reparar, inst, x)
    caso.observar((x, y), margen=0)
    assert x == [0, 0] and y == [0, 1] and y is not x


_SCRIPT = (
    "import hashlib, random, sys; sys.path.insert(0, r'{raiz}');"
    "from generador_sintetico import construir_instancia;"
    "from modelo import pares_en_conflicto; from reparacion import reparar;"
    "inst, d = construir_instancia(56, 102); s = inst.servicios_con_opciones();"
    "rng = random.Random(5); p = [rng.randrange(len(x.alternativas)) for x in s];"
    "print(hashlib.sha256(repr(reparar(p, inst, pares_en_conflicto(s, d.transicion))).encode()).hexdigest())"
)


def test_a03_14_determinista_entre_procesos(caso):
    from conftest import RAIZ
    caso.definir("A03-14", COMP, "Reproducibilidad entre procesos",
                 "instancia sintética n = 56, semilla 102; PYTHONHASHSEED = 0, 1 y 4242", 1,
                 "La reparación no depende de la aleatorización de hash del intérprete")
    huellas = set()
    for hs in ("0", "1", "4242"):
        r = caso.cronometrar(subprocess.run, [sys.executable, "-c", _SCRIPT.format(raiz=RAIZ)],
                             env=dict(os.environ, PYTHONHASHSEED=hs), capture_output=True, text=True, check=True)
        huellas.add(r.stdout.strip())
    caso.observar(len(huellas))
    assert len(huellas) == 1
