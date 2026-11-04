"""M06. Mecanismo de reparación (sección 3.4): reparación dirigida (diseño de la tesis) y
reparación aleatoria acotada (modo por defecto del ejemplo ilustrativo del README)."""
from __future__ import annotations

import random

from core.conflicts import build_conflict_pairs
from core.domain import Service
from core.fitness import evaluate
from core.repair import build_conflict_index, repair, repair_targeted
from core.domain import Instance
from generador_sanfelipe import construir_instancia
from utilidades import alt, cromosoma_aleatorio, instancia_aleatoria

COMP = "Reparación de restricciones (sec. 3.4.9)"


def _dirigida(servicios, x, previo=None, limite=None):
    pares = build_conflict_pairs(servicios)
    return repair_targeted(x, servicios, build_conflict_index(servicios, pares), previo or {}, limite or {})


def _par(prio1, prio2, inicio2=50):
    return (
        Service("S1", prio1, (alt("S1", "V1", "C1", "h0", 0, 100), alt("S1", "V2", "C2", "h1", 0, 100))),
        Service("S2", prio2, (alt("S2", "V1", "C1", "h0", inicio2, 100), alt("S2", "V3", "C3", "h1", 200, 100))),
    )


def test_m06_01_conserva_mayor_prioridad(caso):
    caso.definir("M06-01", COMP, "Regla de prioridad", "S1 (prioridad 3) y S2 (prioridad 1) en conflicto; X = (0, 0)",
                 (0, 1), "Se conserva el servicio de mayor prioridad y se reubica el otro")
    obs = caso.cronometrar(_dirigida, _par(3, 1), (0, 0))
    caso.observar(obs, margen=0 if obs == (0, 1) else 1)
    assert obs == (0, 1)


def test_m06_02_prioridad_invertida(caso):
    caso.definir("M06-02", COMP, "Regla de prioridad", "S1 (prioridad 1) y S2 (prioridad 3) en conflicto; X = (0, 0)",
                 (1, 0), "Al invertir las prioridades se reubica S1")
    obs = caso.cronometrar(_dirigida, _par(1, 3), (0, 0))
    caso.observar(obs, margen=0 if obs == (1, 0) else 1)
    assert obs == (1, 0)


def test_m06_03_empate_conserva_inicio_temprano(caso):
    caso.definir("M06-03", COMP, "Valor límite: empate de prioridad", "prioridades iguales; S1 inicia en 0, S2 en 50",
                 (0, 1), "Con igual prioridad se conserva el servicio que inicia antes")
    obs = caso.cronometrar(_dirigida, _par(2, 2), (0, 0))
    caso.observar(obs, margen=0 if obs == (0, 1) else 1)
    assert obs == (0, 1)


def test_m06_04_conflicto_sin_alternativa_queda_como_incidencia(caso):
    caso.definir("M06-04", COMP, "Partición: conflicto irreparable", "S1 y S2 con una sola alternativa que se cruza",
                 1, "Sin alternativa admisible no se fuerza una asignación inválida: el conflicto queda (Φ = 1)")
    servicios = (Service("S1", 2, (alt("S1", "V1", "C1", "h0", 0, 100),)),
                 Service("S2", 1, (alt("S2", "V1", "C1", "h0", 50, 100),)))
    inst = Instance(servicios, {}, {})
    x = caso.cronometrar(_dirigida, servicios, (0, 0))
    phi = evaluate(x, inst, build_conflict_pairs(servicios)).feasibility_violations
    caso.observar(phi)
    assert x == (0, 0) and phi == 1


def test_m06_05_alivia_conductor_sobre_limite(caso):
    caso.definir("M06-05", COMP, "Partición: exceso de conducción", "S1 con C1 (límite 50) o C2 (sin límite); X = (0,)",
                 (1,), "Un conductor sobre su límite se alivia moviendo el servicio a una alternativa dentro del límite")
    servicios = (Service("S1", 1, (alt("S1", "V1", "C1", "h0", 0, 100), alt("S1", "V2", "C2", "h1", 0, 100))),)
    obs = caso.cronometrar(_dirigida, servicios, (0,), {"C1": 0.0}, {"C1": 50.0})
    caso.observar(obs, margen=0 if obs == (1,) else 1)
    assert obs == (1,)


def test_m06_06_dirigida_es_determinista(caso):
    caso.definir("M06-06", COMP, "Determinismo", "instancia oficial n = 56, semilla 102; 50 cromosomas × 3 repeticiones",
                 0, "La reparación dirigida no usa números aleatorios: repetirla da el mismo cromosoma")
    inst, meta = construir_instancia(56, 102)
    servicios = inst.services_with_options()
    pares = build_conflict_pairs(servicios, meta.t_min)
    indice = build_conflict_index(servicios, pares)
    rng = random.Random(4)
    distintos = 0
    for _ in range(50):
        x = cromosoma_aleatorio(servicios, rng)
        salidas = {caso.cronometrar(repair_targeted, x, servicios, indice, inst.driving_time_prior,
                                    inst.driving_time_limit) for _ in range(3)}
        distintos += len(salidas) - 1
    caso.observar(distintos)
    assert distintos == 0


def test_m06_07_dirigida_no_aumenta_phi(caso):
    caso.definir("M06-07", COMP, "Propiedad (4 000 aleatorios + 750 en instancias oficiales)",
                 "cromosomas uniformes; n = 10 aleatorias y n = 7…112 oficiales", 0,
                 "Φ(reparado) ≤ Φ(original): la reparación dirigida nunca agrega incumplimientos")
    rng = random.Random(1)
    aumentos = 0
    casos = []
    for semilla in range(400):
        inst = instancia_aleatoria(semilla, n=10, k_max=4)
        casos += [(inst, 0.0)] * 10
    for n in (7, 14, 28, 56, 112):
        for s in (101, 102, 103):
            inst, meta = construir_instancia(n, s)
            casos += [(inst, meta.t_min)] * 50
    cache = {}
    for inst, t_min in casos:
        if id(inst) not in cache:
            servicios = inst.services_with_options()
            pares = build_conflict_pairs(servicios, t_min)
            cache[id(inst)] = (servicios, pares, build_conflict_index(servicios, pares))
        servicios, pares, indice = cache[id(inst)]
        x = cromosoma_aleatorio(servicios, rng)
        antes = evaluate(x, inst, pares).feasibility_violations
        y = caso.cronometrar(repair_targeted, x, servicios, indice, inst.driving_time_prior, inst.driving_time_limit)
        aumentos += int(evaluate(y, inst, pares).feasibility_violations > antes)
    caso.observar(aumentos, margen=aumentos)
    assert aumentos == 0 and len(casos) == 4750


def test_m06_08_aleatoria_genes_validos_y_reproducible(caso):
    caso.definir("M06-08", COMP, "Dominio y reproducibilidad", "400 instancias aleatorias; rng con semilla 0 dos veces",
                 0, "La reparación aleatoria devuelve genes en A_s, no toca servicios con |A_s| = 1 y se repite con la misma semilla")
    errores = 0
    for semilla in range(400):
        inst = instancia_aleatoria(semilla, n=10, k_max=4)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios)
        x = cromosoma_aleatorio(servicios, random.Random(semilla))
        y1 = caso.cronometrar(repair, x, servicios, pares, random.Random(0))
        y2 = repair(x, servicios, pares, random.Random(0))
        errores += int(y1 != y2)
        errores += sum(1 for s, g in zip(servicios, y1) if not 0 <= g < len(s.admissible))
        errores += sum(1 for s, g0, g1 in zip(servicios, x, y1) if len(s.admissible) == 1 and g0 != g1)
    caso.observar(errores)
    assert errores == 0


def test_m06_09_aleatoria_resuelve_caso_construido(caso):
    caso.definir("M06-09", COMP, "Caso construido (prueba original del README)",
                 "3 servicios con 2 opciones; X = (0, 0, 0), máx. 10 pasadas", 0,
                 "La reparación aleatoria resuelve el caso de referencia del README")
    servicios = tuple(
        Service(f"S{i}", 1, (alt(f"S{i}", "V1", "D1", "h0", t, 60), alt(f"S{i}", f"V{i + 3}", f"D{i + 3}", "h1", t, 60)))
        for i, t in ((1, 0), (2, 30), (3, 45)))
    pares = build_conflict_pairs(servicios)
    y = caso.cronometrar(repair, (0, 0, 0), servicios, pares, random.Random(0), max_passes=10)
    phi = evaluate(y, Instance(servicios, {}, {}), pares).feasibility_violations
    caso.observar(phi)
    assert phi == 0


def test_m06_10_aleatoria_no_es_monotona(caso):
    caso.definir("M06-10", COMP, "Caracterización (4 000 casos aleatorios)", "rng con semilla 0; n = 10, |A_s| ≤ 4",
                 "> 0 aumentos",
                 "La reparación aleatoria acotada NO garantiza Φ(reparado) ≤ Φ(original); por eso la configuración "
                 "de la tesis (resolver_ag) usa la reparación dirigida")
    rng = random.Random(1)
    aumentos, total = 0, 0
    for semilla in range(400):
        inst = instancia_aleatoria(semilla, n=10, k_max=4)
        servicios = inst.services_with_options()
        pares = build_conflict_pairs(servicios)
        for _ in range(10):
            x = cromosoma_aleatorio(servicios, rng)
            antes = evaluate(x, inst, pares).feasibility_violations
            y = caso.cronometrar(repair, x, servicios, pares, random.Random(0))
            aumentos += int(evaluate(y, inst, pares).feasibility_violations > antes)
            total += 1
    caso.observar(f"{aumentos} de {total} ({100 * aumentos / total:.1f} %)", margen=None)
    assert aumentos > 0
