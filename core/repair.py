"""Reparación dirigida (sección 3.4.9).

REIMPLEMENTACIÓN (2026-10-17); ver core/README.md. Sigue los mismos pasos que
paquetes/dominio/lib/src/optimizacion/reparacion.dart, el núcleo Dart del
sistema.

La ecuación (1) ya excluye los recursos no disponibles o no habilitados, por lo
que la reparación solo atiende los conflictos de Γ y el límite de conducción:

1. Para cada conflicto, en el orden de los genes, se conserva el servicio de mayor
   prioridad p_s (en empate, el de inicio más temprano) y el otro se reasigna a la
   primera alternativa, en orden de hora de salida, que no genere un conflicto y
   mantenga a su conductor dentro del límite; si no existe, se intenta reasignar
   el servicio conservado.
2. Para cada conductor que supera su límite se reasigna uno de sus servicios con
   el mismo criterio, empezando por el de menor prioridad (en empate, el de
   inicio más tardío).
3. Se repite hasta que no haya cambios, con un máximo de cinco pasadas.

Lo que no puede resolverse queda en el cromosoma, penalizado por M. Es
determinista: el mismo cromosoma da siempre el mismo resultado.
"""
from __future__ import annotations

import math

from .conflicts import conflict_index

MAX_PASSES = 5
_TOL = 1e-9


class _Estado:
    def __init__(self, instance, services, chromosome, index):
        self.inst = instance
        self.servs = services
        self.crom = [int(g) for g in chromosome]
        self.index = index
        self.orden_alt = [sorted(range(len(s.admissible)), key=lambda a, s=s: (s.admissible[a].start_time, a))
                          for s in services]
        self.carga = {}
        for i in range(len(self.crom)):
            a = self.elegida(i)
            self.carga[a.driver_id] = self.carga.get(a.driver_id, 0.0) + a.duration

    def elegida(self, i):
        return self.servs[i].admissible[self.crom[i]]

    def conservar_y_mover(self, i, j):
        pi, pj = self.servs[i].priority, self.servs[j].priority
        if pi != pj:
            return (i, j) if pi > pj else (j, i)
        ti, tj = self.elegida(i).start_time, self.elegida(j).start_time
        if ti != tj:
            return (i, j) if ti < tj else (j, i)
        return i, j

    def excede(self, c):
        limite = self.inst.driving_time_limit.get(c, math.inf)
        return self.inst.driving_time_prior.get(c, 0.0) + self.carga.get(c, 0.0) > limite + _TOL

    def _cabe(self, i, k):
        actual, cand = self.elegida(i), self.servs[i].admissible[k]
        carga = self.carga.get(cand.driver_id, 0.0)
        if cand.driver_id == actual.driver_id:
            carga -= actual.duration
        total = self.inst.driving_time_prior.get(cand.driver_id, 0.0) + carga + cand.duration
        return total <= self.inst.driving_time_limit.get(cand.driver_id, math.inf) + _TOL

    def _choca(self, i, k):
        return any(j != i and self.crom[j] == b for j, b in self.index.get((i, k), ()))

    def reasignar(self, i):
        actual = self.elegida(i)
        for k in self.orden_alt[i]:
            if k == self.crom[i] or not self._cabe(i, k) or self._choca(i, k):
                continue
            cand = self.servs[i].admissible[k]
            self.carga[actual.driver_id] -= actual.duration
            self.carga[cand.driver_id] = self.carga.get(cand.driver_id, 0.0) + cand.duration
            self.crom[i] = k
            return True
        return False

    def siguiente_conflicto(self, i, desde):
        js = [j for j, b in self.index.get((i, self.crom[i]), ()) if j >= desde and self.crom[j] == b]
        return min(js) if js else None


def repair(chromosome, instance, conflict_pairs=None, index=None, max_passes=MAX_PASSES):
    """Cromosoma reparado (lista nueva; el de entrada no se modifica)."""
    services = instance.services_with_options()
    if index is None:
        index = conflict_index(conflict_pairs)
    e = _Estado(instance, services, chromosome, index)
    conductores = sorted(instance.driving_time_limit)
    for _ in range(max_passes):
        cambios = False
        # Paso 1: los pares (i, j), i < j, en el orden de los genes y con el estado vigente.
        for i in range(len(e.crom)):
            desde = i + 1
            while (j := e.siguiente_conflicto(i, desde)) is not None:
                conservar, mover = e.conservar_y_mover(i, j)
                if e.reasignar(mover) or e.reasignar(conservar):
                    cambios = True
                desde = j + 1
        # Paso 2: conductores por encima de su límite.
        for c in conductores:
            while e.excede(c):
                suyos = [i for i in range(len(e.crom)) if e.elegida(i).driver_id == c]
                suyos.sort(key=lambda i: (e.servs[i].priority, -e.elegida(i).start_time, -i))
                if not any(e.reasignar(i) for i in suyos):
                    break
                cambios = True
        if not cambios:
            break
    return e.crom
