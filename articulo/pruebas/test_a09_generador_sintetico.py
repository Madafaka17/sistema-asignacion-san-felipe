"""A09. Reglas del generador sintético del caso de Soritor (generador_sintetico.py). Datos sintéticos."""
from __future__ import annotations

import generador_sintetico as G
from generador_sintetico import construir_instancia
from utilidades import metricas

COMP = "Generador sintético del caso (generador_sintetico.py)"
TAMANOS = (7, 14, 28, 56, 112, 224)
SEMILLAS = range(101, 121)


def _todas(caso):
    """Las 120 instancias del experimento publicado; mide la latencia del generador en cada construcción."""
    for n in TAMANOS:
        for s in SEMILLAS:
            yield n, s, *caso.cronometrar(construir_instancia, n, s)


def test_a09_01_misma_semilla_misma_instancia(caso):
    caso.definir("A09-01", COMP, "Reproducibilidad con semilla fija", "n = 56, semilla 107; dos construcciones", True,
                 "La misma semilla produce la misma instancia y la misma descripción")
    a = caso.cronometrar(construir_instancia, 56, 107)
    b = caso.cronometrar(construir_instancia, 56, 107)
    caso.observar(a == b)
    assert a == b and construir_instancia(56, 108) != a


def test_a09_02_tamano_y_programacion_oculta_factible(caso):
    caso.definir("A09-02", COMP, "Datos construidos (120 instancias)", "n ∈ {7, …, 224}; semillas 101 a 120", 0,
                 "Cada instancia tiene n servicios y su programación oculta no tiene conflictos ni excesos (oráculo)")
    errores = 0
    for n, s, inst, d in _todas(caso):
        servicios = inst.servicios_con_opciones()
        errores += int(len(servicios) != n)
        errores += metricas(list(d.opcion_oculta), inst, d.transicion)["incumplimientos"]
    caso.observar(errores)
    assert errores == 0


def test_a09_03_alternativas_y_opcion_oculta(caso):
    caso.definir("A09-03", COMP, "Regla de negocio: alternativas por servicio", "120 instancias", 0,
                 "Cada servicio tiene entre 1 y 5 alternativas, incluye la de la programación oculta (unidad en cola, "
                 "conductor oculto y salida nominal) y todas duran lo mismo")
    errores = 0
    for n, s, inst, d in _todas(caso):
        oculta = {sid: (u, c, t) for sid, u, c, t, _ in d.oculta}
        for serv, k in zip(inst.servicios_con_opciones(), d.opcion_oculta):
            a = serv.alternativas[k]
            errores += int(not 1 <= len(serv.alternativas) <= G.ALTERNATIVAS[1])
            errores += int((a.vehiculo, a.conductor, a.inicio) != oculta[serv.id])
            errores += int(len({x.duracion for x in serv.alternativas}) != 1)
    caso.observar(errores)
    assert errores == 0


def test_a09_04_duracion_ruta_y_turno(caso):
    caso.definir("A09-04", COMP, "Regla de negocio: viaje redondo dentro del turno",
                 "120 instancias; ida MOY 30 min, TAR 150 min; estancia 20 a 40 min; turno 600 min", 0,
                 "Duración = 2 × ida + estancia; demora de 0, 10 o 20 min; la alternativa termina dentro del turno")
    errores = 0
    for n, s, inst, d in _todas(caso):
        for serv in inst.servicios_con_opciones():
            ruta = d.ruta[serv.id]
            for a in serv.alternativas:
                estancia = a.duracion - 2 * G.IDA_MIN[ruta]
                errores += int(not G.ESTANCIA[0] <= estancia <= G.ESTANCIA[1])
                errores += int(a.inicio - d.salida_nominal[serv.id] not in G.DEMORAS)
                errores += int(a.inicio < 0 or a.inicio + a.duracion > G.TURNO_MIN)
    caso.observar(errores)
    assert errores == 0


def test_a09_05_unidades_y_conductores_autorizados(caso):
    caso.definir("A09-05", COMP, "Regla de negocio: unidad en cola o siguiente y conductor autorizado", "120 instancias", 0,
                 "Las alternativas usan la unidad en cola o la siguiente libre, con un conductor autorizado para esa "
                 "unidad")
    errores = 0
    for n, s, inst, d in _todas(caso):
        for serv in inst.servicios_con_opciones():
            unidades = {a.vehiculo for a in serv.alternativas}
            errores += int(d.unidad_en_cola[serv.id] not in unidades or len(unidades) > 2)
            errores += sum(1 for a in serv.alternativas if a.conductor not in d.autorizados[a.vehiculo])
    caso.observar(errores)
    assert errores == 0


def test_a09_06_tamano_de_la_plantilla(caso):
    caso.definir("A09-06", COMP, "Regla de negocio: conductores por unidad", "120 instancias; razón 44/37", 0,
                 "Número de conductores = max(unidades, round(unidades × 44 / 37))")
    errores = 0
    for n, s, inst, d in _todas(caso):
        m = len(d.unidades)
        errores += int(len(d.conductores) != max(m, round(m * G.CONDUCTORES_LISTA / G.UNIDADES_ACTIVAS_DIA)))
    caso.observar(errores)
    assert errores == 0


def test_a09_07_plantilla_de_la_empresa(caso, monkeypatch):
    caso.definir("A09-07", COMP, "Partición: variante CONDUCTORES_EMPRESA (52 conductores para 56 unidades)",
                 "n = 112, semillas 101 a 110", 0, "Con la lista de la empresa, conductores = max(unidades, "
                 "round(unidades × 52 / 56))")
    monkeypatch.setattr(G, "CONDUCTORES_LISTA", 52)
    monkeypatch.setattr(G, "UNIDADES_ACTIVAS_DIA", 56)
    errores = 0
    for s in range(101, 111):
        inst, d = caso.cronometrar(G.construir_instancia, 112, s)
        m = len(d.unidades)
        errores += int(len(d.conductores) != max(m, round(m * 52 / 56)))
        errores += metricas(list(d.opcion_oculta), inst, d.transicion)["incumplimientos"]
    caso.observar(errores)
    assert errores == 0


def test_a09_08_limites_de_conduccion(caso):
    caso.definir("A09-08", COMP, "Regla de negocio: holgura del límite", "120 instancias; holgura 20 a 120 min", 0,
                 "Límite de cada conductor = carga en la programación oculta + holgura entera entre 20 y 120 min; "
                 "sin conducción previa")
    errores = 0
    for n, s, inst, d in _todas(caso):
        carga = {c: 0.0 for c in d.conductores}
        for _, _, c, _, dur in d.oculta:
            carga[c] += dur
        for c in d.conductores:
            h = inst.limite_conduccion[c] - carga[c]
            errores += int(not (G.HOLGURA_LIMITE[0] <= h <= G.HOLGURA_LIMITE[1] and h == int(h)))
            errores += int(inst.conduccion_previa[c] != 0.0)
    caso.observar(errores)
    assert errores == 0


def test_a09_09_proporcion_comprometida(caso):
    caso.definir("A09-09", COMP, "Prueba estadística (binomial, 3σ)", "120 instancias (8820 servicios); p = 0.40",
                 "0.40 ± 3σ", "La proporción de servicios con salida comprometida es la declarada")
    total = comprometidos = 0
    for n, s, inst, d in _todas(caso):
        for serv in inst.servicios_con_opciones():
            total += 1
            comprometidos += int(serv.comprometida is not None)
    p = comprometidos / total
    sigma = (0.4 * 0.6 / total) ** 0.5
    caso.observar(round(p, 4), tolerancia=round(3 * sigma, 4), margen=abs(p - 0.4))
    assert abs(p - G.PROPORCION_COMPROMETIDA) <= 3 * sigma


def test_a09_10_pesos_y_referencias(caso):
    caso.definir("A09-10", COMP, "Revisión de valores declarados", "120 instancias",
                 "pesos 0.25; referencias 60, max(1, comprometidos), 60 × unidades, 60",
                 "Pesos iguales y referencias de normalización de J según el número de compromisos y de unidades")
    errores = 0
    for n, s, inst, d in _todas(caso):
        nb = sum(1 for x in inst.servicios if x.comprometida is not None)
        errores += int(set(inst.pesos.values()) != {0.25})
        errores += int(inst.referencias != {"retraso": 60.0, "reprogramacion": float(max(1, nb)),
                                            "tiempo_muerto": 60.0 * len(d.unidades), "desequilibrio": 60.0})
    caso.observar(errores)
    assert errores == 0
