"""A04. Algoritmo genético (genetico.py): configuración, población inicial reparada, operadores, elitismo,
criterios de parada y reproducibilidad.

Los operadores de cruce y mutación son funciones internas de ejecutar_ag; se obtienen con un doble de prueba
de pygad.GA que registra los argumentos en lugar de ejecutar el algoritmo.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys

import numpy
import pytest

import genetico
from genetico import ConfigAG, ejecutar_ag
from generador_sintetico import construir_instancia
from modelo import evaluar, pares_en_conflicto
from reparacion import reparar

COMP = "Algoritmo genético (genetico.py)"


class _GAFalso:
    registro: dict = {}

    def __init__(self, **kw):
        _GAFalso.registro = kw
        self.generations_completed = 0

    def run(self):
        pass


def _capturar(monkeypatch, inst, t, conf):
    monkeypatch.setattr(genetico.pygad, "GA", _GAFalso)
    ejecutar_ag(inst, t, conf)
    return dict(_GAFalso.registro)


def test_a04_01_configuracion_por_omision(caso):
    caso.definir("A04-01", COMP, "Revisión de valores declarados", "ConfigAG()",
                 (50, 100, 0.8, 0.1, 3, 0.1, None, 300.0, 1),
                 "Población 50, 100 generaciones, cruce 0.80, mutación 0.10, torneo 3, élite 10 %, tiempo 300 s, "
                 "semilla 1 (configuración AG_v1 del artículo)")
    c = caso.cronometrar(ConfigAG)
    obs = (c.poblacion, c.generaciones, c.prob_cruce, c.prob_mutacion, c.torneo, c.elitismo,
           c.generaciones_sin_mejora, c.limite_tiempo, c.semilla)
    caso.observar(obs, margen=0)
    assert obs == (50, 100, 0.8, 0.1, 3, 0.1, None, 300.0, 1)


def test_a04_02_argumentos_entregados_a_pygad(caso, monkeypatch):
    caso.definir("A04-02", COMP, "Doble de prueba de pygad.GA", "instancia sintética n = 14, semilla 101; AG_v1",
                 ("tournament", 3, 50, 100, 5, ["time_300"]),
                 "Selección por torneo de 3, 50 progenitores, 100 generaciones, 5 élites y parada por tiempo")
    inst, d = construir_instancia(14, 101)
    kw = caso.cronometrar(_capturar, monkeypatch, inst, d.transicion, ConfigAG())
    obs = (kw["parent_selection_type"], kw["K_tournament"], kw["num_parents_mating"], kw["num_generations"],
           kw["keep_elitism"], kw["stop_criteria"])
    caso.observar(obs, margen=0)
    assert obs == ("tournament", 3, 50, 100, 5, ["time_300"]) and kw["gene_type"] is int and kw["random_seed"] == 1


@pytest.mark.parametrize("poblacion,esperado", [(1, 1), (5, 1), (15, 2), (50, 5), (100, 10)])
def test_a04_03_elitismo_valores_limite(caso, monkeypatch, poblacion, esperado):
    caso.definir(f"A04-03-P{poblacion}", COMP, "Valor límite del redondeo de la élite",
                 f"población = {poblacion}; élite = 10 %", esperado,
                 "keep_elitism = max(1, round(0.10 × población)); round usa redondeo al par (0.5 → 0, 1.5 → 2)")
    inst, d = construir_instancia(7, 101)
    kw = caso.cronometrar(_capturar, monkeypatch, inst, d.transicion, ConfigAG(poblacion=poblacion))
    caso.observar(kw["keep_elitism"])
    assert kw["keep_elitism"] == esperado


def test_a04_04_parada_por_saturacion_declarada(caso, monkeypatch):
    caso.definir("A04-04", COMP, "Partición: con y sin parada por estancamiento",
                 "AG_v2: población 100, 200 generaciones, 20 sin mejora", ["time_300", "saturate_20"],
                 "La configuración AG_v2 añade la parada tras 20 generaciones sin mejora")
    inst, d = construir_instancia(7, 101)
    kw = caso.cronometrar(_capturar, monkeypatch, inst, d.transicion,
                          ConfigAG(poblacion=100, generaciones=200, generaciones_sin_mejora=20))
    caso.observar(kw["stop_criteria"], margen=0)
    assert kw["stop_criteria"] == ["time_300", "saturate_20"]


def test_a04_05_poblacion_inicial_reparada(caso, monkeypatch):
    caso.definir("A04-05", COMP, "Reconstrucción independiente",
                 "instancia sintética n = 28, semilla 103; semilla del AG 4", 0,
                 "La población inicial es la de un generador uniforme con la semilla del AG, reparada cromosoma "
                 "por cromosoma")
    inst, d = construir_instancia(28, 103)
    kw = caso.cronometrar(_capturar, monkeypatch, inst, d.transicion, ConfigAG(semilla=4))
    servicios = inst.servicios_con_opciones()
    pares = pares_en_conflicto(servicios, d.transicion)
    rng = numpy.random.default_rng(4)
    esperada = [reparar([int(rng.integers(len(s.alternativas))) for s in servicios], inst, pares) for _ in range(50)]
    diferencias = sum(1 for a, b in zip(kw["initial_population"].tolist(), esperada) if a != b)
    caso.observar(diferencias)
    assert diferencias == 0 and kw["initial_population"].shape == (50, len(servicios))


def test_a04_06_cruce_uniforme_con_probabilidad(caso, monkeypatch):
    caso.definir("A04-06", COMP, "Prueba estadística (binomial, 3σ)",
                 "10 000 descendientes de padres opuestos de 30 genes; prob_cruce = 0.80",
                 "0.20 ± 0.012 sin cruzar; 0.50 ± 0.003 de genes del segundo padre",
                 "Un descendiente se cruza con probabilidad 0.80 y, si se cruza, hereda cada gen de uno u otro "
                 "padre con probabilidad 0.5; si no, copia al primero")
    inst, d = construir_instancia(28, 101)
    kw = _capturar(monkeypatch, inst, d.transicion, ConfigAG(semilla=9))
    cruce = kw["crossover_type"]
    n = 30
    padres = numpy.array([[0] * n, [1] * n])
    copias, genes_p2, genes_cruzados = 0, 0, 0
    for _ in range(500):
        hijos = caso.cronometrar(cruce, padres, (20, n), None)
        for k, h in enumerate(hijos):
            p1, p2 = padres[k % 2], padres[(k + 1) % 2]
            assert all(g in (a, b) for g, a, b in zip(h, p1, p2))
            if (h == p1).all():
                copias += 1
            else:
                genes_cruzados += n
                genes_p2 += int((h == p2).sum())
    frac_copias = copias / 10000
    frac_p2 = genes_p2 / genes_cruzados
    caso.observar(f"{frac_copias:.4f}; {frac_p2:.4f}", margen=max(abs(frac_copias - 0.2), abs(frac_p2 - 0.5)))
    assert abs(frac_copias - 0.2) <= 3 * (0.2 * 0.8 / 10000) ** 0.5
    assert abs(frac_p2 - 0.5) <= 3 * (0.25 / genes_cruzados) ** 0.5


def test_a04_07_mutacion_cambia_un_gen_mutable(caso, monkeypatch):
    caso.definir("A04-07", COMP, "Prueba estadística (binomial, 3σ) con doble de la reparación",
                 "10 000 descendientes; prob_mutacion = 0.10; reparación sustituida por la identidad",
                 "0.10 ± 0.009 mutados; exactamente 1 gen cambiado",
                 "Con probabilidad 0.10 un servicio con más de una alternativa pasa a otra alternativa válida")
    inst, d = construir_instancia(28, 101)
    servicios = inst.servicios_con_opciones()
    tamanos = [len(s.alternativas) for s in servicios]
    kw = _capturar(monkeypatch, inst, d.transicion, ConfigAG(semilla=9))
    monkeypatch.setattr(genetico, "reparar", lambda prog, instancia, pares=None, indice=None: list(prog))
    mutacion = kw["mutation_type"]
    rng = numpy.random.default_rng(0)
    mutados, malos = 0, 0
    for _ in range(500):
        base = numpy.array([[int(rng.integers(k)) for k in tamanos] for _ in range(20)])
        hijos = caso.cronometrar(mutacion, base.copy(), None)
        for h, b in zip(hijos, base):
            cambios = [i for i in range(len(tamanos)) if h[i] != b[i]]
            if cambios:
                mutados += 1
                i = cambios[0]
                malos += int(len(cambios) != 1 or tamanos[i] < 2 or not 0 <= h[i] < tamanos[i])
    frac = mutados / 10000
    caso.observar(f"{frac:.4f}; {malos} con más de un cambio o valor inválido", margen=abs(frac - 0.1))
    assert malos == 0 and abs(frac - 0.1) <= 3 * (0.1 * 0.9 / 10000) ** 0.5


def test_a04_08_mutacion_repara_cada_descendiente(caso, monkeypatch):
    caso.definir("A04-08", COMP, "Doble de prueba (espía de la reparación)", "200 descendientes de n = 28", 200,
                 "Cada descendiente se repara después de la mutación, se haya mutado o no")
    inst, d = construir_instancia(28, 101)
    kw = _capturar(monkeypatch, inst, d.transicion, ConfigAG(semilla=9))
    llamadas = []
    monkeypatch.setattr(genetico, "reparar",
                        lambda prog, instancia, pares=None, indice=None: llamadas.append(1) or list(prog))
    hijos = numpy.array(kw["initial_population"][:20].tolist() * 10)
    caso.cronometrar(kw["mutation_type"], hijos, None)
    caso.observar(len(llamadas))
    assert len(llamadas) == 200


def test_a04_09_reproducible_con_la_misma_semilla(caso):
    caso.definir("A04-09", COMP, "Reproducibilidad con semilla fija", "n = 28, instancia 102; semilla 3; dos ejecuciones",
                 True, "La misma semilla repite programación, aptitud, generaciones, evaluaciones e historia")
    inst, d = construir_instancia(28, 102)
    a = caso.cronometrar(ejecutar_ag, inst, d.transicion, ConfigAG(semilla=3))
    b = caso.cronometrar(ejecutar_ag, inst, d.transicion, ConfigAG(semilla=3))
    igual = (a.programacion, a.aptitud, a.generaciones, a.evaluaciones, a.historia) == \
            (b.programacion, b.aptitud, b.generaciones, b.evaluaciones, b.historia)
    caso.observar(igual)
    assert igual


def test_a04_10_resultado_consistente(caso):
    caso.definir("A04-10", COMP, "Consistencia interna", "n = 56, instancia 101; semilla 2",
                 "aptitud = F(programación); historia no decreciente; |historia| = generaciones",
                 "La aptitud informada es la de la programación devuelta y la historia guarda la mejor por generación")
    inst, d = construir_instancia(56, 101)
    r = caso.cronometrar(ejecutar_ag, inst, d.transicion, ConfigAG(semilla=2))
    pares = pares_en_conflicto(inst.servicios_con_opciones(), d.transicion)
    f = evaluar(r.programacion, inst, pares).aptitud
    crece = all(b >= a for a, b in zip(r.historia, r.historia[1:]))
    caso.observar(f"|ΔF| = {abs(f - r.aptitud):.1e}; no decreciente = {crece}; {len(r.historia)} de {r.generaciones}",
                  margen=abs(f - r.aptitud))
    assert f == r.aptitud and crece and len(r.historia) == r.generaciones == 100
    assert r.evaluaciones > 0 and r.historia[-1] == r.aptitud


def test_a04_11_parada_por_estancamiento(caso):
    caso.definir("A04-11", COMP, "Valor límite del criterio de parada", "n = 7, instancia 101; 300 generaciones; 10 sin mejora",
                 "< 300 generaciones; últimas 10 iguales",
                 "Con parada por estancamiento, el AG termina antes del máximo cuando la mejor aptitud deja de cambiar")
    inst, d = construir_instancia(7, 101)
    r = caso.cronometrar(ejecutar_ag, inst, d.transicion, ConfigAG(generaciones=300, generaciones_sin_mejora=10))
    ultimas = r.historia[-10:]
    caso.observar(f"{r.generaciones} generaciones; últimas 10 iguales = {len(set(ultimas)) == 1}", margen=None)
    assert r.generaciones < 300 and len(set(ultimas)) == 1


def test_a04_12_parada_por_tiempo(caso):
    caso.definir("A04-12", COMP, "Valor límite del criterio de parada", "n = 112, instancia 101; 5000 generaciones; límite 1 s",
                 "< 5000 generaciones y tiempo < 2 s",
                 "El límite de tiempo detiene el AG aunque no haya completado las generaciones")
    inst, d = construir_instancia(112, 101)
    r = caso.cronometrar(ejecutar_ag, inst, d.transicion, ConfigAG(generaciones=5000, limite_tiempo=1.0))
    caso.observar(f"{r.generaciones} generaciones en {r.tiempo:.2f} s", margen=None)
    assert r.generaciones < 5000 and r.tiempo < 2.0


_SCRIPT = (
    "import hashlib, sys; sys.path.insert(0, r'{raiz}');"
    "from generador_sintetico import construir_instancia; from genetico import ConfigAG, ejecutar_ag;"
    "inst, d = construir_instancia(28, 103); r = ejecutar_ag(inst, d.transicion, ConfigAG(semilla=5));"
    "print(hashlib.sha256(repr((r.programacion, r.aptitud)).encode()).hexdigest())"
)


def test_a04_13_reproducible_entre_procesos(caso):
    from conftest import RAIZ
    caso.definir("A04-13", COMP, "Reproducibilidad entre procesos",
                 "n = 28, instancia 103, semilla 5; PYTHONHASHSEED = 0, 7 y 99", 1,
                 "El resultado no depende de la aleatorización de hash del intérprete")
    huellas = set()
    for hs in ("0", "7", "99"):
        r = caso.cronometrar(subprocess.run, [sys.executable, "-c", _SCRIPT.format(raiz=RAIZ)],
                             env=dict(os.environ, PYTHONHASHSEED=hs), capture_output=True, text=True, check=True)
        huellas.add(r.stdout.strip())
    caso.observar(len(huellas))
    assert len(huellas) == 1
