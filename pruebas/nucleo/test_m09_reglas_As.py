"""M09. Reglas de construcción de las alternativas admisibles A_s (cola por destino, conductor habitual,
reemplazos autorizados, ventanas de salida y límites), tal como las implementa el generador sintético
del caso (experimentos/sanfelipe/generador_sanfelipe.py). Datos sintéticos, no de la empresa."""
from __future__ import annotations

from collections import defaultdict

from generador_sanfelipe import (DEMORAS, ESTANCIA, HOLGURA_LIMITE, IDA_MIN, TURNO_MIN, construir_instancia)
from validador import contar_incumplimientos

COMP = "Reglas de construcción de A_s (ec. 1; generador del caso)"
OFICIALES = [(n, s) for n in (7, 14, 28, 56, 112) for s in (101, 102, 103)]
_CACHE: dict = {}


def _inst(n, s):
    if (n, s) not in _CACHE:
        _CACHE[(n, s)] = construir_instancia(n, s)
    return _CACHE[(n, s)]


def _contar(caso, funcion):
    errores = 0
    for n, s in OFICIALES:
        inst, meta = caso.cronometrar(_inst, n, s)
        errores += funcion(inst, meta)
    return errores


def test_m09_01_tamano_de_A_s(caso):
    caso.definir("M09-01", COMP, "Valores límite de |A_s| (2 y 5)", "15 instancias oficiales (651 servicios)", 0,
                 "Cada servicio tiene entre 2 y 5 alternativas admisibles")
    e = _contar(caso, lambda i, m: sum(1 for s in i.services if not 2 <= len(s.admissible) <= 5))
    caso.observar(e)
    assert e == 0


def test_m09_02_regla_de_la_cola(caso):
    caso.definir("M09-02", COMP, "Regla de negocio: cola por destino", "15 instancias oficiales", 0,
                 "A_s usa la unidad que corresponde por la cola y, a lo sumo, una unidad siguiente; la opción "
                 "de referencia es la unidad en cola a la hora nominal")
    def errores(inst, meta):
        e = 0
        for s, h in zip(inst.services, meta.opcion_oculta):
            unidades = {a.vehicle_id for a in s.admissible}
            u0 = meta.unidad_en_cola[s.service_id]
            e += int(u0 not in unidades or len(unidades) > 2)
            ref = s.admissible[h]
            e += int(ref.vehicle_id != u0 or ref.start_time != meta.salida_nominal[s.service_id])
        return e
    e = _contar(caso, errores)
    caso.observar(e)
    assert e == 0


def test_m09_03_unidad_siguiente_en_terminal(caso):
    caso.definir("M09-03", COMP, "Regla de negocio: la unidad siguiente está en la terminal",
                 "15 instancias oficiales", 0,
                 "La unidad alternativa no está en viaje en la hora nominal del servicio")
    def errores(inst, meta):
        ocupada = defaultdict(list)
        for _sid, u, _c, t0, d in meta.oculta:
            ocupada[u].append((t0, t0 + d))
        e = 0
        for s in inst.services:
            t0 = meta.salida_nominal[s.service_id]
            for u in {a.vehicle_id for a in s.admissible} - {meta.unidad_en_cola[s.service_id]}:
                e += sum(1 for a, b in ocupada[u] if a <= t0 < b)
        return e
    e = _contar(caso, errores)
    caso.observar(e)
    assert e == 0


def test_m09_04_conductor_habitual(caso):
    caso.definir("M09-04", COMP, "Regla de negocio: conductor fijo de la unidad", "15 instancias oficiales", 0,
                 "Las unidades con conductor fijo lo usan en la programación de referencia y figura primero entre sus autorizados")
    def errores(inst, meta):
        e = sum(1 for _sid, u, c, _t, _d in meta.oculta if u in meta.conductor_fijo and c != meta.conductor_fijo[u])
        e += sum(1 for u, c in meta.conductor_fijo.items() if meta.autorizados[u][0] != c)
        return e
    e = _contar(caso, errores)
    caso.observar(e)
    assert e == 0


def test_m09_05_reemplazos_autorizados(caso):
    caso.definir("M09-05", COMP, "Regla de negocio: pares unidad–conductor autorizados", "15 instancias oficiales", 0,
                 "Todo conductor de A_s está autorizado para la unidad; cada unidad tiene 1 o 2 reemplazos además de su base")
    def errores(inst, meta):
        e = sum(1 for s in inst.services for a in s.admissible if a.driver_id not in meta.autorizados[a.vehicle_id])
        for u, lista in meta.autorizados.items():
            base = [meta.conductor_fijo[u]] if u in meta.conductor_fijo else \
                sorted({c for _sid, uu, c, _t, _d in meta.oculta if uu == u})
            extra = [c for c in lista if c not in base]
            e += int(not 1 <= len(extra) <= 2) + int(len(set(lista)) != len(lista))
        return e
    e = _contar(caso, errores)
    caso.observar(e)
    assert e == 0


def test_m09_06_ventana_de_salida(caso):
    caso.definir("M09-06", COMP, "Valores límite de la ventana", "demoras {0, 10, 20} min; turno de 600 min", 0,
                 "Cada salida es la nominal más 0, 10 o 20 min y el viaje termina dentro del turno")
    def errores(inst, meta):
        e = 0
        for s in inst.services:
            t0 = meta.salida_nominal[s.service_id]
            for a in s.admissible:
                e += int(a.start_time - t0 not in DEMORAS) + int(a.start_time + a.duration > TURNO_MIN)
        return e
    e = _contar(caso, errores)
    caso.observar(e)
    assert e == 0


def test_m09_07_duracion_del_viaje_redondo(caso):
    caso.definir("M09-07", COMP, "Regla de negocio: duración por ruta", "Moyobamba 30 min, Tarapoto 150 min de ida",
                 0, "Todas las alternativas de un servicio tienen la misma duración, 2·ida + estancia (20–40 min)")
    def errores(inst, meta):
        e = 0
        for s in inst.services:
            ida = IDA_MIN[meta.ruta[s.service_id]]
            duraciones = {a.duration for a in s.admissible}
            d = next(iter(duraciones))
            e += int(len(duraciones) != 1) + int(not 2 * ida + ESTANCIA[0] <= d <= 2 * ida + ESTANCIA[1])
        return e
    e = _contar(caso, errores)
    caso.observar(e)
    assert e == 0


def test_m09_08_factible_por_construccion(caso):
    caso.definir("M09-08", COMP, "Oráculo: validador independiente", "programación de referencia de las 15 instancias",
                 0, "La programación de referencia oculta no tiene cruces ni excesos (existe solución factible)")
    e = _contar(caso, lambda i, m: contar_incumplimientos(m.opcion_oculta, i.services_with_options(), i, m.t_min))
    caso.observar(e)
    assert e == 0


def test_m09_09_holgura_del_limite(caso):
    caso.definir("M09-09", COMP, "Valores límite de la holgura (20 y 120 min)", "15 instancias oficiales", 0,
                 "El límite de cada conductor deja entre 20 y 120 min sobre su carga de referencia")
    def errores(inst, meta):
        carga = defaultdict(float)
        for _sid, _u, c, _t, d in meta.oculta:
            carga[c] += d
        return sum(1 for c in meta.conductores
                   if not HOLGURA_LIMITE[0] <= inst.driving_time_limit[c] - carga[c] <= HOLGURA_LIMITE[1])
    e = _contar(caso, errores)
    caso.observar(e)
    assert e == 0


def test_m09_10_generador_determinista(caso):
    caso.definir("M09-10", COMP, "Reproducibilidad", "dos construcciones por instancia oficial", 0,
                 "La misma semilla produce la misma instancia y la misma programación de referencia")
    distintas = 0
    for n, s in OFICIALES:
        a, ma = caso.cronometrar(construir_instancia, n, s)
        b, mb = construir_instancia(n, s)
        distintas += int(a != b or ma.oculta != mb.oculta)
    caso.observar(distintas)
    assert distintas == 0


def test_m09_11_proporcion_comprometida(caso):
    caso.definir("M09-11", COMP, "Prueba estadística (binomial, 3σ)", "651 servicios; p = 0.40", 0.40,
                 "La proporción de servicios con salida comprometida es la declarada en el protocolo")
    total = comprometidos = 0
    for n, s in OFICIALES:
        inst, _ = caso.cronometrar(_inst, n, s)
        total += len(inst.services)
        comprometidos += sum(1 for x in inst.services if x.baseline_alt is not None)
    p = comprometidos / total
    tolerancia = 3 * (0.4 * 0.6 / total) ** 0.5
    caso.observar(round(p, 4), tolerancia=round(tolerancia, 4))
    assert abs(p - 0.40) <= tolerancia
