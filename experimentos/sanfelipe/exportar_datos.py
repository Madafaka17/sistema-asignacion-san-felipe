"""Exporta las 15 instancias sintéticas a CSV legibles (carpeta datos/).

DATOS SINTÉTICOS: no son registros de la Empresa de Transportes y Turismo San
Felipe. Los identificadores US01, US02... (unidades) y CS01, CS02... (conductores)
son ficticios y no corresponden a placas, personas ni a los códigos V001/C001 del
libro de captura.
"""
from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
sys.path.insert(0, str(AQUI.parents[1]))

from generador_sanfelipe import ASIENTOS, NOMBRE_RUTA, construir_instancia, hhmm  # noqa: E402

TAMANOS = [7, 14, 28, 56, 112]
SEMILLAS_INSTANCIA = [101, 102, 103]
DATOS = AQUI / "datos"


def main():
    DATOS.mkdir(exist_ok=True)
    tablas = defaultdict(list)
    for n in TAMANOS:
        for sem in SEMILLAS_INSTANCIA:
            inst, meta = construir_instancia(n, sem)
            carga = defaultdict(float)
            for _, u, c, t, d in meta.oculta:
                carga[c] += d
            for s, oculta in zip(inst.services, meta.opcion_oculta):
                sid = s.service_id
                tablas["servicios"].append({
                    "n": n, "instancia": sem, "servicio": sid, "ruta": NOMBRE_RUTA[meta.ruta[sid]],
                    "salida_nominal_min": meta.salida_nominal[sid], "salida_nominal_hora": hhmm(meta.salida_nominal[sid]),
                    "duracion_viaje_redondo_min": s.admissible[0].duration, "prioridad": s.priority,
                    "unidad_que_corresponde": meta.unidad_en_cola[sid],
                    "alternativa_comprometida": "" if s.baseline_alt is None else s.baseline_alt,
                    "numero_alternativas": len(s.admissible)})
                for j, a in enumerate(s.admissible):
                    tablas["alternativas"].append({
                        "n": n, "instancia": sem, "servicio": sid, "alternativa": j,
                        "unidad": a.vehicle_id, "conductor": a.driver_id,
                        "salida_min": a.start_time, "salida_hora": hhmm(a.start_time),
                        "demora_min": a.start_time - meta.salida_nominal[sid], "duracion_min": a.duration,
                        "unidad_que_corresponde": int(a.vehicle_id == meta.unidad_en_cola[sid]),
                        "conductor_fijo_de_la_unidad": int(meta.conductor_fijo.get(a.vehicle_id) == a.driver_id),
                        "comprometida": int(s.baseline_alt == j),
                        "programacion_oculta": int(oculta == j)})
            for u in meta.unidades:
                tablas["unidades"].append({
                    "n": n, "instancia": sem, "unidad": u, "asientos": ASIENTOS,
                    "conductor_fijo": meta.conductor_fijo.get(u, ""),
                    "conductores_autorizados": ";".join(meta.autorizados[u])})
            fijo_de = {c: u for u, c in meta.conductor_fijo.items()}
            for c in meta.conductores:
                tablas["conductores"].append({
                    "n": n, "instancia": sem, "conductor": c, "unidad_fija": fijo_de.get(c, ""),
                    "conduccion_previa_min": inst.driving_time_prior[c],
                    "limite_conduccion_min": inst.driving_time_limit[c],
                    "carga_programacion_oculta_min": carga[c]})
    for nombre, filas in tablas.items():
        with open(DATOS / f"{nombre}.csv", "w", newline="", encoding="utf8") as fh:
            w = csv.DictWriter(fh, fieldnames=list(filas[0]))
            w.writeheader()
            w.writerows(filas)
        print(nombre, len(filas), "filas")


if __name__ == "__main__":
    main()
