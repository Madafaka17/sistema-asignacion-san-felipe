"""Prueba de reasignación ante incidencias de despacho (PROTOCOLO.md).

    python3 reasignacion.py ejecutar [v1|v2]   # -> escenarios_<var>.csv y resultados_crudos_<var>.csv
    python3 reasignacion.py analizar [v1|v2]   # -> resumen_<var>.json (y la tabla en pantalla)

v1: alternativas admisibles del modelo (secciones 1 a 7 del protocolo).
v2: regla de contingencia de la sección 8.2, definida después de observar v1.

Usa sin cambios el generador del caso San Felipe, el algoritmo genético v1 y la
regla voraz de experimentos/poc_cap3, core/fitness.py y el validador
independiente. Las instancias son sintéticas: no son datos de la empresa.
"""
from __future__ import annotations

import csv
import json
import platform
import statistics
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI.parent / "sanfelipe"))
sys.path.insert(0, str(AQUI.parent / "poc_cap3"))
sys.path.insert(0, str(AQUI.parents[1]))

import numpy  # noqa: E402
import pygad  # noqa: E402

from core.conflicts import build_conflict_pairs  # noqa: E402
from core.domain import AdmissibleTriple, Instance, Service  # noqa: E402
from core.fitness import evaluate  # noqa: E402
from generador_sanfelipe import TURNO_MIN, construir_instancia  # noqa: E402
from metodos import resolver_ag, resolver_voraz  # noqa: E402
from validador import contar_incumplimientos  # noqa: E402

TAMANOS = [28, 56, 112]
SEMILLAS_INSTANCIA = [101, 102, 103]
SEMILLAS_AG = list(range(1, 11))
MINUTO_INCIDENCIA = 300.0
DEMORA_MIN = 60.0
INCIDENCIAS = ["I1_averia", "I2_ausencia", "I3_demora"]
NOMBRE = {"I1_averia": "Avería de unidad", "I2_ausencia": "Ausencia de conductor",
          "I3_demora": "Demora en ruta"}

DEMORAS_CONTINGENCIA = (0, 10, 20, 30)


def _archivos(var):
    sufijo = "" if var == "v1" else f"_{var}"
    return (AQUI / f"escenarios{sufijo}.csv", AQUI / f"resultados_crudos{sufijo}.csv", AQUI / f"resumen{sufijo}.json")

CAMPOS_ESC = ["n", "instancia", "incidencia", "recurso", "efecto", "iniciados", "pendientes",
              "afectados", "sin_alternativa", "con_alternativa", "conductores_al_limite"]
CAMPOS = ["n", "instancia", "incidencia", "metodo", "semilla", "tiempo_s", "valida", "phi", "validador",
          "pendientes", "afectados", "sin_alternativa", "cubiertos", "cambios_obligados",
          "cambios_adicionales", "cambios_total", "retraso_min", "F"]


def _choca(ini, fin, ocupados, t_min):
    return any(not (fin + t_min <= a or b + t_min <= ini) for a, b in ocupados)


def _mayor(conteo, candidatos=None):
    items = [(k, v) for k, v in conteo.items() if candidatos is None or k in candidatos]
    return min(items, key=lambda kv: (-kv[1], kv[0]))[0] if items else None


def escenario(inst, meta, tipo, ampliar=False):
    """Construye la instancia de reasignación (sección 4 del protocolo; con
    ampliar=True, la regla de contingencia de la sección 8.2)."""
    aprobada = {s.service_id: s.admissible[meta.opcion_oculta[i]] for i, s in enumerate(inst.services)}
    iniciados = [s for s in inst.services if aprobada[s.service_id].start_time < MINUTO_INCIDENCIA]
    pendientes = [s for s in inst.services if aprobada[s.service_id].start_time >= MINUTO_INCIDENCIA]
    por_unidad = Counter(aprobada[s.service_id].vehicle_id for s in pendientes)
    por_conductor = Counter(aprobada[s.service_id].driver_id for s in pendientes)

    ocup_v, ocup_c = defaultdict(list), defaultdict(list)
    previa = defaultdict(float)
    for s in iniciados:
        a = aprobada[s.service_id]
        ocup_v[a.vehicle_id].append((a.start_time, a.start_time + a.duration))
        ocup_c[a.driver_id].append((a.start_time, a.start_time + a.duration))
        previa[a.driver_id] += a.duration

    fuera_v, fuera_c = set(), set()
    if tipo == "I1_averia":
        recurso = _mayor(por_unidad)
        fuera_v.add(recurso)
        efecto = "unidad fuera de servicio"
    elif tipo == "I2_ausencia":
        recurso = _mayor(por_conductor)
        fuera_c.add(recurso)
        efecto = "conductor ausente"
    else:
        en_curso = {aprobada[s.service_id].vehicle_id: aprobada[s.service_id] for s in iniciados
                    if aprobada[s.service_id].start_time + aprobada[s.service_id].duration > MINUTO_INCIDENCIA}
        recurso = _mayor(por_unidad, set(en_curso))
        if recurso is not None:
            a = en_curso[recurso]
            fin = a.start_time + a.duration
            ocup_v[a.vehicle_id].append((fin, fin + DEMORA_MIN))
            ocup_c[a.driver_id].append((fin, fin + DEMORA_MIN))
            previa[a.driver_id] += DEMORA_MIN
            efecto = f"viaje en curso +{DEMORA_MIN:.0f} min (conductor {a.driver_id})"
        else:
            recurso = _mayor(por_unidad)
            ocup_v[recurso].append((MINUTO_INCIDENCIA, MINUTO_INCIDENCIA + DEMORA_MIN))
            efecto = f"unidad detenida {DEMORA_MIN:.0f} min"

    limite = inst.driving_time_limit
    al_limite = {c for c in meta.conductores if previa.get(c, 0.0) >= limite.get(c, float("inf"))}

    servicios, afectados, sin_alt = [], [], []
    for s in pendientes:
        ap = aprobada[s.service_id]
        alts = [a for a in s.admissible
                if a.vehicle_id not in fuera_v and a.driver_id not in fuera_c
                and a.driver_id not in al_limite
                and not _choca(a.start_time, a.start_time + a.duration, ocup_v[a.vehicle_id], meta.t_min)
                and not _choca(a.start_time, a.start_time + a.duration, ocup_c[a.driver_id], meta.t_min)]
        base = alts.index(ap) if ap in alts else None
        if base is None and ampliar:
            existentes = {(a.vehicle_id, a.driver_id, a.start_time) for a in alts}
            for u in meta.unidades:
                if u in fuera_v:
                    continue
                for c in meta.autorizados[u]:
                    if c in fuera_c or c in al_limite:
                        continue
                    for dm in DEMORAS_CONTINGENCIA:
                        ini = meta.salida_nominal[s.service_id] + dm
                        fin = ini + ap.duration
                        if fin > TURNO_MIN or (u, c, ini) in existentes:
                            continue
                        if _choca(ini, fin, ocup_v[u], meta.t_min) or _choca(ini, fin, ocup_c[c], meta.t_min):
                            continue
                        alts.append(AdmissibleTriple(s.service_id, u, c, f"x{len(alts)}", float(ini), float(ap.duration)))
                        existentes.add((u, c, ini))
        if base is None:
            afectados.append(s.service_id)
        if not alts:
            sin_alt.append(s.service_id)
        servicios.append(Service(s.service_id, s.priority, tuple(alts), base))

    nb = sum(1 for s in servicios if s.baseline_alt is not None)
    inst2 = Instance(
        services=tuple(servicios),
        driving_time_prior={c: previa.get(c, 0.0) for c in meta.conductores},
        driving_time_limit=dict(limite),
        weights=dict(inst.weights),
        norm_refs={"delay": 60.0, "reschedule": float(max(1, nb)),
                   "idle": 60.0 * len(meta.unidades), "workload": 60.0},
    )
    info = {"recurso": recurso, "efecto": efecto, "iniciados": len(iniciados), "pendientes": len(pendientes),
            "afectados": len(afectados), "sin_alternativa": len(sin_alt),
            "con_alternativa": len(pendientes) - len(sin_alt), "conductores_al_limite": len(al_limite)}
    return inst2, aprobada, info


def medir(crom, inst2, aprobada, t_min):
    servs = inst2.services_with_options()
    pares = build_conflict_pairs(servs, min_transition=t_min)
    b = evaluate(crom, inst2, pares)
    val = contar_incumplimientos(crom, servs, inst2, t_min)
    obligados = adicionales = 0
    retraso = 0.0
    for s, g in zip(servs, crom):
        a = s.admissible[g]
        if s.baseline_alt is None:
            obligados += 1
        elif g != s.baseline_alt:
            adicionales += 1
        retraso += max(0.0, a.start_time - aprobada[s.service_id].start_time)
    phi = b.conflict_violations + b.overlimit_drivers
    return {"valida": int(phi == 0 and val == 0), "phi": phi, "validador": val, "cubiertos": len(servs),
            "cambios_obligados": obligados, "cambios_adicionales": adicionales,
            "cambios_total": obligados + adicionales, "retraso_min": round(retraso, 1), "F": b.fitness}


def ejecutar(var):
    escenarios, crudos, _ = _archivos(var)
    with open(escenarios, "w", newline="", encoding="utf8") as fe, \
            open(crudos, "w", newline="", encoding="utf8") as fr:
        we = csv.DictWriter(fe, fieldnames=CAMPOS_ESC)
        wr = csv.DictWriter(fr, fieldnames=CAMPOS)
        we.writeheader()
        wr.writeheader()
        for n in TAMANOS:
            for s_inst in SEMILLAS_INSTANCIA:
                inst, meta = construir_instancia(n, s_inst)
                for tipo in INCIDENCIAS:
                    inst2, aprobada, info = escenario(inst, meta, tipo, ampliar=(var == "v2"))
                    we.writerow({"n": n, "instancia": s_inst, "incidencia": tipo} | info)
                    comunes = {"n": n, "instancia": s_inst, "incidencia": tipo, "pendientes": info["pendientes"],
                               "afectados": info["afectados"], "sin_alternativa": info["sin_alternativa"]}

                    # Sin reasignar: la programación aprobada de los servicios no afectados.
                    servs = inst2.services_with_options()
                    sin_base = [s for s in servs if s.baseline_alt is None]
                    if sin_base:
                        fila = {"metodo": "Sin reasignar", "semilla": 0, "tiempo_s": 0.0, "valida": 0,
                                "phi": "", "validador": "", "cubiertos": len(servs) - len(sin_base),
                                "cambios_obligados": 0, "cambios_adicionales": 0, "cambios_total": 0,
                                "retraso_min": 0.0, "F": ""}
                    else:
                        crom = tuple(s.baseline_alt for s in servs)
                        fila = {"metodo": "Sin reasignar", "semilla": 0, "tiempo_s": 0.0} | medir(crom, inst2, aprobada, meta.t_min)
                    if info["afectados"] > 0:
                        fila["valida"] = 0
                    wr.writerow(comunes | fila)

                    t0 = time.perf_counter()
                    crom = resolver_voraz(inst2, meta.t_min)
                    t = time.perf_counter() - t0
                    wr.writerow(comunes | {"metodo": "Voraz", "semilla": 0, "tiempo_s": round(t, 6)}
                                | medir(crom, inst2, aprobada, meta.t_min))

                    for sem in SEMILLAS_AG:
                        t0 = time.perf_counter()
                        crom = resolver_ag(inst2, meta.t_min, sem)
                        t = time.perf_counter() - t0
                        wr.writerow(comunes | {"metodo": "AG", "semilla": sem, "tiempo_s": round(t, 6)}
                                    | medir(crom, inst2, aprobada, meta.t_min))
                    fr.flush()
                    print(f"n={n} inst={s_inst} {tipo}: {info}", flush=True)


def _media(xs):
    return round(statistics.fmean(xs), 2) if xs else None


def analizar(var):
    escenarios, crudos, resumen_json = _archivos(var)
    filas = list(csv.DictReader(open(crudos, encoding="utf8")))
    esc = list(csv.DictReader(open(escenarios, encoding="utf8")))
    resumen = {"entorno": {"python": platform.python_version(), "pygad": pygad.__version__,
                           "numpy": numpy.__version__, "plataforma": platform.platform()},
               "escenarios": len(esc), "por_metodo": {}, "por_tamano": {}, "por_incidencia": {}}

    def agrega(sub):
        out = {}
        for m in ("Sin reasignar", "Voraz", "AG"):
            fm = [f for f in sub if f["metodo"] == m]
            if not fm:
                continue
            val = [f for f in fm if f["valida"] == "1"]
            out[m] = {
                "ejecuciones": len(fm),
                "validas_pct": round(100.0 * len(val) / len(fm), 1),
                "afectados_media": _media([float(f["afectados"]) for f in fm]),
                "sin_alternativa_media": _media([float(f["sin_alternativa"]) for f in fm]),
                "cambios_adicionales_media": _media([float(f["cambios_adicionales"]) for f in fm]),
                "cambios_total_media": _media([float(f["cambios_total"]) for f in fm]),
                "retraso_min_media": _media([float(f["retraso_min"]) for f in fm]),
                "tiempo_s_media": _media([float(f["tiempo_s"]) for f in fm]),
                "tiempo_s_max": round(max(float(f["tiempo_s"]) for f in fm), 3),
            }
        return out

    resumen["por_metodo"] = agrega(filas)
    for n in TAMANOS:
        resumen["por_tamano"][str(n)] = agrega([f for f in filas if f["n"] == str(n)])
    for tipo in INCIDENCIAS:
        resumen["por_incidencia"][tipo] = agrega([f for f in filas if f["incidencia"] == tipo])
    resumen["escenarios_detalle"] = {
        "pendientes_media_por_n": {str(n): _media([float(e["pendientes"]) for e in esc if e["n"] == str(n)]) for n in TAMANOS},
        "afectados_media_por_n": {str(n): _media([float(e["afectados"]) for e in esc if e["n"] == str(n)]) for n in TAMANOS},
        "sin_alternativa_total": sum(int(e["sin_alternativa"]) for e in esc),
        "conductores_al_limite_total": sum(int(e["conductores_al_limite"]) for e in esc),
    }
    resumen["variante"] = var
    resumen_json.write_text(json.dumps(resumen, ensure_ascii=False, indent=2), encoding="utf8")
    print(json.dumps(resumen, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in ("ejecutar", "analizar"):
        sys.exit(__doc__)
    var = sys.argv[2] if len(sys.argv) == 3 else "v1"
    if var not in ("v1", "v2"):
        sys.exit(__doc__)
    ejecutar(var) if sys.argv[1] == "ejecutar" else analizar(var)
