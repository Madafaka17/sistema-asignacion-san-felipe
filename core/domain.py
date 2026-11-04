"""Domain model for the integrated vehicle-driver-departure scheduling
problem of Sections 2.3-2.5 of the article.

Pure data structures only. No I/O, no persistence, no printing: this module
(and the rest of `core/`) is the "core" in the sense used throughout the
project -- it must be usable, and unit-testable, without a database, a UI,
or a network connection. Persistence (Figure 5 / Section 2.7) and
presentation are strictly the responsibility of code outside `core/`.

Notation follows Table 1 and Equations (1)-(8) of the article:
  S            set of services, s in S
  V            set of vehicles, v in V
  C            set of drivers, c in C            (NOT the conflict set)
  H_s          admissible departure alternatives for service s, h in H_s
  A_s          admissible triples (v, c, h) for service s, A_s <= V x C x H_s
  t_sh, d_sh   start time and duration of service s under alternative h
  H_c0, H_cmax prior driving time / limit for driver c in the control period
  script-C     conflict-pair set of Eq. (3) -- written `conflict_pairs`
               below to keep it visually distinct from the driver set C
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass(frozen=True)
class AdmissibleTriple:
    """One element a = (v, c, h) of A_s (Eq. 1): a fully admissible
    (vehicle, driver, departure-alternative) combination already filtered,
    upstream of this module, for capacity, compatibility/eligibility
    (K_svc), resource availability (E_v, E_c), and the operating-interval
    condition of Section 2.3. This module does not re-derive admissibility;
    it only searches over A_s as supplied.
    """
    service_id: str
    vehicle_id: str
    driver_id: str
    departure_alt_id: str      # h in H_s
    start_time: float          # t_sh, in a common time unit (Section 2.3)
    duration: float            # d_sh, same time unit


@dataclass(frozen=True)
class Service:
    """A service s in S together with its admissible-triple set A_s.
    `baseline_alt` is the index into `admissible` used as the committed /
    approved reference for the delay and rescheduling criteria of Section
    2.5 (the article names the concept -- "the original committed
    departure", "an approved schedule" -- without fixing a symbol for it;
    `baseline_alt` is this module's explicit binding of that concept).
    """
    service_id: str
    priority: int
    admissible: tuple[AdmissibleTriple, ...]   # A_s, possibly empty
    baseline_alt: Optional[int] = None         # index into `admissible`, or None


@dataclass(frozen=True)
class Instance:
    """A planning instance: the sets and parameters of Table 1 needed by
    the genetic algorithm, already assembled and validated (Figure 3's
    validation loop; Section 2.3's admissibility conditions).
    """
    services: tuple[Service, ...]                      # S
    driving_time_prior: dict[str, float]                # H_c0, by driver id
    driving_time_limit: dict[str, float]                # H_cmax, by driver id
    weights: dict[str, float] = field(default_factory=dict)   # w_j, Eq. (8)
    norm_refs: dict[str, float] = field(default_factory=dict)  # b_j, Eq. (8)

    def services_with_options(self) -> tuple[Service, ...]:
        """Services with a nonempty A_s: the only services a chromosome
        (Eq. 9) can encode. A service with A_s = (emptyset) cannot be
        represented as a gene and is reported directly through u_s = 1
        (Eq. 5) by the caller, upstream of the genetic algorithm -- see
        `uncovered_services`.
        """
        return tuple(s for s in self.services if len(s.admissible) > 0)

    def uncovered_services(self) -> tuple[Service, ...]:
        """Services with A_s = (emptyset): necessarily u_s = 1 in Eq. (5),
        independently of any assignment decision. The genetic algorithm
        never sees these; they are a modeling fact, not a search outcome.
        """
        return tuple(s for s in self.services if len(s.admissible) == 0)
