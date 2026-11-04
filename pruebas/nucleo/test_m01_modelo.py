"""M01. Modelo de datos y codificación del cromosoma (ecuaciones 1, 2, 3 y 15 de la tesis)."""
from __future__ import annotations

import copy

from core.domain import Instance, Service
from core.scheduler import GAConfig, run
from utilidades import alt, instancia_aleatoria

COMP = "Modelo y codificación (ec. 1, 2, 3 y 15)"


def _instancia_con_vacios():
    servicios = (
        Service("S1", 1, (alt("S1", "V1", "C1", "h0", 0, 60), alt("S1", "V2", "C2", "h1", 10, 60))),
        Service("S2", 1, ()),
        Service("S3", 2, (alt("S3", "V1", "C2", "h0", 200, 60),)),
        Service("S4", 3, ()),
    )
    return Instance(services=servicios, driving_time_prior={}, driving_time_limit={})


def test_m01_01_servicios_con_opciones(caso):
    caso.definir("M01-01", COMP, "Partición de equivalencia (A_s vacío / no vacío)",
                 "4 servicios; A_S2 = A_S4 = ∅", ["S1", "S3"],
                 "Solo los servicios con A_s ≠ ∅ forman genes del cromosoma, en su orden original")
    inst = _instancia_con_vacios()
    obs = [s.service_id for s in caso.cronometrar(inst.services_with_options)]
    caso.observar(obs, margen=0 if obs == ["S1", "S3"] else 1)
    assert obs == ["S1", "S3"]


def test_m01_02_servicios_sin_cobertura(caso):
    caso.definir("M01-02", COMP, "Partición de equivalencia (u_s = 1)",
                 "4 servicios; A_S2 = A_S4 = ∅", ["S2", "S4"],
                 "Los servicios con A_s = ∅ se informan aparte como no cubiertos (u_s = 1, sec. 3.1.2)")
    obs = [s.service_id for s in caso.cronometrar(_instancia_con_vacios().uncovered_services)]
    caso.observar(obs, margen=0 if obs == ["S2", "S4"] else 1)
    assert obs == ["S2", "S4"]


def test_m01_03_genes_en_dominio(caso):
    caso.definir("M01-03", COMP, "Propiedad sobre 20 instancias aleatorias con servicios vacíos",
                 "n = 12, |A_s| ∈ {0..3}, AG P = 8, G = 5", 0,
                 "Longitud del cromosoma = |S'| y cada gen α(s) ∈ {0, …, |A_s| − 1} (ec. 15)")
    fuera = 0
    for semilla in range(20):
        inst = instancia_aleatoria(semilla, n=12, k_max=3, con_vacios=True)
        res = caso.cronometrar(run, inst, GAConfig(population_size=8, num_generations=5, random_seed=semilla))
        servicios = inst.services_with_options()
        fuera += int(len(res.chromosome) != len(servicios))
        fuera += sum(1 for s, g in zip(servicios, res.chromosome) if not 0 <= g < len(s.admissible))
    caso.observar(fuera)
    assert fuera == 0


def test_m01_04_instancia_sin_opciones(caso):
    caso.definir("M01-04", COMP, "Valor límite (estructura vacía, tamaño 0)",
                 "2 servicios, ambos con A_s = ∅", "cromosoma () y sin historial",
                 "El núcleo no falla con una instancia sin genes y devuelve un resultado vacío controlado")
    inst = Instance(services=(Service("S1", 1, ()), Service("S2", 1, ())),
                    driving_time_prior={}, driving_time_limit={})
    res = caso.cronometrar(run, inst, GAConfig(population_size=4, num_generations=3))
    obs = (res.chromosome, res.best_fitness_by_generation, res.breakdown.feasibility_violations)
    caso.observar(str(obs), margen=0 if obs == ((), (), 0) else 1)
    assert obs == ((), (), 0)


def test_m01_05_asignaciones_coinciden_con_cromosoma(caso):
    caso.definir("M01-05", COMP, "Consistencia de la salida (ScheduleResult)",
                 "instancia aleatoria n = 10, AG P = 10, G = 10", 0,
                 "Cada asignación devuelta corresponde a la tripleta elegida por el gen (unidad, conductor, salida)")
    inst = instancia_aleatoria(7, n=10)
    res = caso.cronometrar(run, inst, GAConfig(population_size=10, num_generations=10, random_seed=7))
    asign = res.assignments()
    errores = 0
    for s, g in zip(res.services, res.chromosome):
        a = s.admissible[g]
        fila = asign[s.service_id]
        errores += int((fila["vehicle_id"], fila["driver_id"], fila["departure_alt_id"], fila["start_time"])
                       != (a.vehicle_id, a.driver_id, a.departure_alt_id, a.start_time))
    caso.observar(errores)
    assert errores == 0 and len(asign) == len(res.services)


def test_m01_06_entrada_no_se_modifica(caso):
    caso.definir("M01-06", COMP, "Ausencia de efectos secundarios",
                 "instancia aleatoria n = 10 copiada antes de ejecutar el AG", 0,
                 "El núcleo no sobrescribe los datos de entrada (la instancia queda idéntica)")
    inst = instancia_aleatoria(11, n=10)
    antes = copy.deepcopy(inst)
    caso.cronometrar(run, inst, GAConfig(population_size=10, num_generations=10, random_seed=11))
    diferencias = int(inst != antes)
    caso.observar(diferencias)
    assert diferencias == 0
