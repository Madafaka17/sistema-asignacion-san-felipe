"""Genera el conjunto mínimo controlado de la prueba de humo (bd/semilla_humo.sql).

Se ejecuta una sola vez, al preparar la prueba; la prueba de humo carga el archivo SQL
estático resultante y no vuelve a llamar al generador. Usa, sin modificarlo, el
generador registrado del experimento (experimentos/sintetico_sanfelipe/
generador_sanfelipe.py) con una semilla disjunta de las del experimento.

    python -m pruebas.humo.generar_semilla

DATOS SINTÉTICOS: no son registros de la Empresa de Transportes y Turismo San Felipe S.A.C.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ))
# experimentos/sanfelipe/ en el repositorio del sistema; sintetico_sanfelipe/ en el registro.
_EXPERIMENTO = RAIZ / "experimentos" / "sanfelipe"
sys.path.insert(0, str(_EXPERIMENTO if _EXPERIMENTO.is_dir() else RAIZ / "experimentos" / "sintetico_sanfelipe"))

from generador_sanfelipe import (ASIENTOS, IDA_MIN, NOMBRE_RUTA, TURNO_MIN,  # noqa: E402
                                 construir_instancia)

from persistencia.canonico import huella_instancia, sha256  # noqa: E402
from pruebas.humo.integridad import semillas_reservadas  # noqa: E402

CONFIG = RAIZ / "config" / "humo.json"


def _num(x: float) -> str:
    if round(x, 2) != x:
        raise ValueError(f"valor con más de dos decimales: {x}")
    return f"{x:.2f}"


def _txt(s: str) -> str:
    if "'" in s or ";" in s or "\\" in s:
        raise ValueError(f"texto no admitido en la semilla: {s!r}")
    return f"'{s}'"


def _insert(tabla: str, columnas: list[str], filas: list[list[str]]) -> str:
    cuerpo = ",\n".join("  (" + ", ".join(f) + ")" for f in filas)
    return f"INSERT INTO {tabla} ({', '.join(columnas)}) VALUES\n{cuerpo};"


def construir_sql(cfg: dict) -> tuple[str, object, dict]:
    sem_inst = cfg["semillas"]["instancia"]
    sem_ag = cfg["semillas"]["algoritmo_genetico"]
    n = cfg["conjunto_minimo"]["servicios"]
    id_turno = cfg["conjunto_minimo"]["id_turno"]
    reservadas = semillas_reservadas(RAIZ)
    if sem_inst in reservadas["SEMILLAS_INSTANCIA"] or sem_ag in reservadas["SEMILLAS_METODO"]:
        raise SystemExit("las semillas de la prueba de humo coinciden con las del experimento registrado")

    inst, meta = construir_instancia(n, sem_inst)
    if dict(sorted(inst.weights.items())) != dict(sorted(cfg["pesos"].items())):
        raise SystemExit("los pesos de config/humo.json no coinciden con los del generador")

    base = {}
    for u in meta.unidades:
        if u in meta.conductor_fijo:
            base[u] = {meta.conductor_fijo[u]}
        else:
            base[u] = {c for (_sid, uu, c, _t, _d) in meta.oculta if uu == u}

    def tipo(u: str, c: str) -> str:
        if meta.conductor_fijo.get(u) == c:
            return "habitual"
        return "plantilla" if c in base[u] else "reemplazo"

    nr = inst.norm_refs
    bloques = [
        _insert("turno", ["id_turno", "origen_datos", "semilla_generador", "duracion_min", "t_min", "b_retraso",
                          "b_reprogramacion", "b_tiempo_muerto", "b_desequilibrio"],
                [[str(id_turno), _txt("sintetico"), str(sem_inst), _num(float(TURNO_MIN)), _num(meta.t_min),
                  _num(nr["delay"]), _num(nr["reschedule"]), _num(nr["idle"]), _num(nr["workload"])]]),
        _insert("ruta", ["id_ruta", "nombre", "ida_min"],
                [[_txt(r), _txt(NOMBRE_RUTA[r]), _num(float(IDA_MIN[r]))] for r in sorted(IDA_MIN)]),
        _insert("conductor", ["id_conductor", "id_turno", "conduccion_previa_min", "limite_conduccion_min"],
                [[_txt(c), str(id_turno), _num(inst.driving_time_prior[c]), _num(inst.driving_time_limit[c])]
                 for c in meta.conductores]),
        _insert("unidad", ["id_unidad", "id_turno", "asientos", "conductor_habitual"],
                [[_txt(u), str(id_turno), str(ASIENTOS),
                  _txt(meta.conductor_fijo[u]) if u in meta.conductor_fijo else "NULL"] for u in meta.unidades]),
        _insert("autorizacion", ["id_unidad", "id_conductor", "tipo"],
                [[_txt(u), _txt(c), _txt(tipo(u, c))] for u in meta.unidades for c in sorted(meta.autorizados[u])]),
        _insert("servicio", ["id_servicio", "id_turno", "orden", "id_ruta", "unidad_en_cola", "salida_nominal_min",
                             "prioridad", "alternativa_comprometida"],
                [[_txt(s.service_id), str(id_turno), str(i), _txt(meta.ruta[s.service_id]),
                  _txt(meta.unidad_en_cola[s.service_id]), _num(meta.salida_nominal[s.service_id]), str(s.priority),
                  "NULL" if s.baseline_alt is None else str(s.baseline_alt)]
                 for i, s in enumerate(inst.services)]),
        _insert("alternativa", ["id_servicio", "indice", "id_unidad", "id_conductor", "codigo_salida", "inicio_min",
                                "duracion_min"],
                [[_txt(s.service_id), str(j), _txt(a.vehicle_id), _txt(a.driver_id), _txt(a.departure_alt_id),
                  _num(a.start_time), _num(a.duration)]
                 for s in inst.services for j, a in enumerate(s.admissible)]),
    ]
    conteos = {"alternativa": sum(len(s.admissible) for s in inst.services),
               "autorizacion": sum(len(meta.autorizados[u]) for u in meta.unidades),
               "conductor": len(meta.conductores), "corrida": 0, "programacion": 0, "ruta": len(IDA_MIN),
               "servicio": len(inst.services), "turno": 1, "unidad": len(meta.unidades)}
    pct = 100.0 * n / cfg["conjunto_minimo"]["turno_referencia_servicios"]
    encabezado = [
        "-- Conjunto mínimo controlado para la prueba de humo.",
        "-- DATOS SINTÉTICOS: no son registros de la Empresa de Transportes y Turismo San Felipe S.A.C.",
        "-- Generado por pruebas/humo/generar_semilla.py con el generador registrado",
        "-- experimentos/sintetico_sanfelipe/generador_sanfelipe.py, sin modificarlo:",
        f"-- n = {n} servicios, semilla {sem_inst} (el experimento usa las semillas "
        f"{', '.join(map(str, reservadas['SEMILLAS_INSTANCIA']))}).",
        f"-- {n} servicios = {pct:.2f} % del turno de referencia de "
        f"{cfg['conjunto_minimo']['turno_referencia_servicios']} servicios.",
        "-- US.. son unidades y CS.. conductores ficticios; no hay datos personales.",
    ]
    return "\n".join(encabezado) + "\n\n" + "\n\n".join(bloques) + "\n", inst, conteos


def main() -> None:
    cfg = json.loads(CONFIG.read_text(encoding="utf8"))
    sql, inst, conteos = construir_sql(cfg)
    destino = RAIZ / cfg["conjunto_minimo"]["archivo"]
    destino.write_bytes(sql.encode("utf8"))
    cfg["conjunto_minimo"]["sha256"] = sha256(sql.encode("utf8"))
    cfg["conjunto_minimo"]["conteos"] = conteos
    cfg["conjunto_minimo"]["huella_instancia"] = huella_instancia(inst)
    CONFIG.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding="utf8")
    print(json.dumps(cfg["conjunto_minimo"], indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
