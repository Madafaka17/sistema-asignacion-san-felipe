"""M12. Reproducibilidad condicionada: mismos resultados con las mismas semillas, entre procesos
y frente a las ejecuciones registradas del experimento (resultados_crudos_v1.csv)."""
from __future__ import annotations

import csv
import os
import subprocess
import sys
from pathlib import Path

from core.conflicts import build_conflict_pairs
from core.fitness import evaluate
from generador_sanfelipe import TURNO_MIN, construir_instancia
from metodos import resolver_ag, resolver_ple, resolver_tabu, resolver_voraz

COMP = "Reproducibilidad (semillas y entorno)"
RAIZ = Path(__file__).resolve().parents[2]
from rutas import SANFELIPE as SANF  # noqa: E402  (experimentos/sanfelipe o el nombre anterior)


def _registro():
    return {(r["metodo"], int(r["n"]), int(r["instancia"]), int(r["semilla"])): float(r["F"])
            for r in csv.DictReader(open(SANF / "resultados_crudos_v1.csv", encoding="utf8")) if r["F"] != ""}


_SCRIPT = (
    "import sys; sys.path[:0] = [r'{raiz}', r'{gen}', r'{poc}'];"
    "from generador_sanfelipe import construir_instancia; from metodos import resolver_ag;"
    "i, m = construir_instancia(28, 103); print(resolver_ag(i, m.t_min, 3))"
)


def test_m12_01_ag_igual_entre_procesos(caso):
    caso.definir("M12-01", COMP, "Reproducibilidad entre procesos", "AG n = 28, instancia 103, semilla 3; "
                 "PYTHONHASHSEED = 0, 7 y 99", 1, "El cromosoma final no depende del proceso ni de la semilla de hash")
    script = _SCRIPT.format(raiz=RAIZ, gen=SANF, poc=RAIZ / "experimentos" / "poc_cap3")
    salidas = set()
    for hs in ("0", "7", "99"):
        r = caso.cronometrar(subprocess.run, [sys.executable, "-c", script], env=dict(os.environ, PYTHONHASHSEED=hs),
                             capture_output=True, text=True, check=True)
        salidas.add(r.stdout.strip())
    caso.observar(len(salidas))
    assert len(salidas) == 1


def test_m12_02_doce_corridas_registradas(caso):
    caso.definir("M12-02", COMP, "Reproducción de datos registrados (DESVIACIONES.md)",
                 "4 candidatos en 14-101, 28-103 y 56-102; semilla 3 para tabú y AG", 0.0,
                 "Las 12 corridas de control reproducen exactamente la aptitud registrada en v1")
    reg = _registro()
    peor, n_corridas = 0.0, 0
    for n, s in ((14, 101), (28, 103), (56, 102)):
        inst, meta = construir_instancia(n, s)
        pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
        cromosomas = {
            ("Voraz", 0): resolver_voraz(inst, meta.t_min),
            ("PLE", 0): resolver_ple(inst, pares, float(TURNO_MIN))[0],
            ("Tabu", 3): resolver_tabu(inst, pares, meta.t_min, 3)[0],
            ("AG", 3): caso.cronometrar(resolver_ag, inst, meta.t_min, 3),
        }
        for (metodo, semilla), crom in cromosomas.items():
            f = evaluate(crom, inst, pares).fitness
            peor = max(peor, abs(f - reg[(metodo, n, s, semilla)]))
            n_corridas += 1
    caso.observar(peor, tolerancia=1e-9)
    assert peor <= 1e-9 and n_corridas == 12


def test_m12_03_ple_reproduce_registro(caso):
    caso.definir("M12-03", COMP, "Reproducción de datos registrados", "PLE en las 15 instancias oficiales (v1)", 0.0,
                 "La PLE (CBC 2.10.3, un hilo) reproduce la aptitud registrada en todas las instancias")
    reg = _registro()
    peor = 0.0
    for n in (7, 14, 28, 56, 112):
        for s in (101, 102, 103):
            inst, meta = construir_instancia(n, s)
            pares = build_conflict_pairs(inst.services_with_options(), meta.t_min)
            crom, _ = caso.cronometrar(resolver_ple, inst, pares, float(TURNO_MIN))
            peor = max(peor, abs(evaluate(crom, inst, pares).fitness - reg[("PLE", n, s, 0)]))
    caso.observar(peor, tolerancia=1e-9)
    assert peor <= 1e-9
