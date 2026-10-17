"""Verificación del generador antes de ejecutar el experimento (PROTOCOLO.md, regla 1).

No ejecuta ningún candidato. Comprueba, para las 15 instancias oficiales, que:
  * la programación oculta tiene cero incumplimientos según el validador independiente;
  * cada servicio tiene entre 2 y 5 alternativas admisibles;
  * el generador es determinista (dos construcciones con la misma semilla coinciden).
Además resume cada instancia en resumen_instancias.csv.
"""
from __future__ import annotations

import csv
import math
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))
sys.path.insert(0, str(AQUI.parent / "poc_cap3"))
sys.path.insert(0, str(AQUI.parents[1]))

from core.conflicts import build_conflict_pairs  # noqa: E402
from generador_sanfelipe import construir_instancia  # noqa: E402
from validador import contar_incumplimientos  # noqa: E402

TAMANOS = [7, 14, 28, 56, 112]
SEMILLAS_INSTANCIA = [101, 102, 103]


def resumen(n, semilla):
    inst, meta = construir_instancia(n, semilla)
    inst2, meta2 = construir_instancia(n, semilla)
    assert inst == inst2 and meta.oculta == meta2.oculta, "generador no determinista"
    servs = inst.services_with_options()
    assert len(servs) == n == len(inst.services)
    tam = [len(s.admissible) for s in servs]
    assert all(2 <= k <= 5 for k in tam), f"alternativas fuera de [2, 5]: {tam}"
    viol = contar_incumplimientos(meta.opcion_oculta, servs, inst, meta.t_min)
    assert viol == 0, f"programación oculta con {viol} incumplimientos"
    pares = build_conflict_pairs(servs, min_transition=meta.t_min)
    tar = sum(1 for r in meta.ruta.values() if r == "TAR")
    return {
        "n": n, "instancia": semilla,
        "unidades_activas": len(meta.unidades),
        "conductores": len(meta.conductores),
        "unidades_con_conductor_fijo": len(meta.conductor_fijo),
        "servicios_Tarapoto": tar, "servicios_Moyobamba": n - tar,
        "alternativas_media": round(sum(tam) / n, 2),
        "log10_combinaciones": round(sum(math.log10(k) for k in tam), 2),
        "pares_en_conflicto": len(pares),
        "servicios_comprometidos": sum(1 for s in servs if s.baseline_alt is not None),
        "incumplimientos_programacion_oculta": viol,
    }


def main():
    filas = [resumen(n, s) for n in TAMANOS for s in SEMILLAS_INSTANCIA]
    with open(AQUI / "datos" / "resumen_instancias.csv", "w", newline="", encoding="utf8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(filas[0]))
        w.writeheader()
        w.writerows(filas)
    for f in filas:
        print(f)
    print("OK: 15 instancias factibles por construcción, 2 a 5 alternativas por servicio, deterministas")


if __name__ == "__main__":
    main()
