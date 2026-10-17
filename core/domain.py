"""Estructuras de datos de una instancia del problema (sección 3.1.2).

REIMPLEMENTACIÓN (2026-10-17). El módulo original con el que se ejecutó el
experimento del Anexo E no se conserva; este archivo se escribió a partir del
capítulo III y de la interfaz que usa experimentos/sanfelipe. Su huella SHA-256
no es la registrada en experimentos/sanfelipe/registro_protocolo.txt (ver
core/README.md).

Una instancia es un turno: cada servicio s tiene su conjunto de alternativas
admisibles A_s (ecuación 1), ya filtrado por disponibilidad, licencia, turno,
cola y pares autorizados. Las decisiones del modelo se limitan a elegir una
alternativa por servicio (ecuaciones 2, 3 y 15).
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class AdmissibleTriple:
    """Alternativa a = (v, c, h) de un servicio, con su hora de inicio t_{s,a} y
    su duración d_{s,a} en minutos del turno."""
    service_id: str
    vehicle_id: str
    driver_id: str
    slot_id: str
    start_time: float
    duration: float

    @property
    def end_time(self) -> float:
        return self.start_time + self.duration


@dataclass(frozen=True)
class Service:
    """Servicio s con su prioridad p_s, sus alternativas A_s y, si tenía una
    programación comprometida b(s), el índice de esa alternativa en A_s (base de
    Ret y R en la ecuación 8)."""
    service_id: str
    priority: int = 1
    admissible: tuple[AdmissibleTriple, ...] = ()
    baseline_alt: int | None = None


@dataclass(frozen=True)
class Instance:
    """Turno a programar.

    driving_time_prior: conducción previa H_c^0 de cada conductor (min).
    driving_time_limit: límite H_c^máx de cada conductor en el periodo (min).
    weights: w_j de J con las claves delay, reschedule, idle y workload.
    norm_refs: referencias b_j con las mismas claves.
    """
    services: tuple[Service, ...]
    driving_time_prior: dict = field(default_factory=dict)
    driving_time_limit: dict = field(default_factory=dict)
    weights: dict = field(default_factory=dict)
    norm_refs: dict = field(default_factory=dict)

    def services_with_options(self) -> tuple[Service, ...]:
        """S' = {s ∈ S : A_s ≠ ∅}: los servicios que el cromosoma codifica."""
        return tuple(s for s in self.services if s.admissible)

    def services_without_options(self) -> tuple[Service, ...]:
        """Servicios con A_s = ∅, que se reportan como incidencias."""
        return tuple(s for s in self.services if not s.admissible)
