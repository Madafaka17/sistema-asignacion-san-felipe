"""A small, fully synthetic planning instance used ONLY to verify that the
genetic algorithm in core/ is implemented correctly and to illustrate the
chromosome encoding end to end.

This is NOT San Felipe's operational data. Real instances -- fleet size,
driver count, service volume, durations, admissible triples -- are
[TO BE OBTAINED FROM COMPANY DATA] per Table 1 and Section 2.2 of the
article; the comparison protocol for those instances is Section 2.9.

The instance is generated, not hand-typed, from a fixed random seed so
that it stays a reproducible fixture (calling `build_instance()` twice
always returns the same instance) while being large and contested enough
-- more services than vehicles or drivers, over a single shift -- that a
random initial population is not already sitting on the optimum, so a
genuine, visible convergence trajectory can be reported instead of an
immediate coincidental match.

Time unit: minutes after 06:00 on the planning day (an 8-hour, 480-minute
shift), matching Section 2.3's "common time unit" requirement.
"""
from __future__ import annotations

import random

from core.domain import AdmissibleTriple, Instance, Service

SHIFT_MINUTES = 480
N_SERVICES = 20
N_VEHICLES = 6
N_DRIVERS = 6
GENERATION_SEED = 7  # fixes the INSTANCE, independent of the GA's own random_seed (GAConfig)


def build_instance(seed: int = GENERATION_SEED) -> Instance:
    rng = random.Random(seed)
    vehicles = [f"V{i+1}" for i in range(N_VEHICLES)]
    drivers = [f"D{i+1}" for i in range(N_DRIVERS)]

    # Stratified nominal start times: one per (SHIFT_MINUTES / N_SERVICES)
    # slot, lightly jittered, so services spread across the shift instead
    # of clustering by chance -- a fairer, still-contested test case.
    slot = SHIFT_MINUTES / N_SERVICES
    nominal_starts = [max(0.0, i * slot + rng.uniform(-0.25, 0.25) * slot) for i in range(N_SERVICES)]
    rng.shuffle(nominal_starts)

    services = []
    for i in range(N_SERVICES):
        sid = f"S{i+1}"
        nominal_start = nominal_starts[i]
        duration = rng.uniform(30, 75)

        n_options = rng.choice([2, 2, 3, 3, 4])
        seen = set()
        options = []
        for h in range(n_options):
            v = rng.choice(vehicles)
            c = rng.choice(drivers)
            jitter = rng.uniform(-15, 15) if h > 0 else 0.0
            start = max(0.0, min(SHIFT_MINUTES - duration, nominal_start + jitter))
            key = (v, c)
            # avoid two admissible options for the SAME service on the
            # identical (vehicle, driver) pair -- not physically meaningful
            if key in seen:
                continue
            seen.add(key)
            options.append(AdmissibleTriple(
                service_id=sid, vehicle_id=v, driver_id=c,
                departure_alt_id=f"h{h}", start_time=round(start, 1), duration=round(duration, 1),
            ))
        if not options:  # pragma: no cover - practically unreachable with 4x4 resources
            v, c = rng.choice(vehicles), rng.choice(drivers)
            options.append(AdmissibleTriple(sid, v, c, "h0", round(nominal_start, 1), round(duration, 1)))

        baseline_alt = rng.randrange(len(options)) if rng.random() < 0.4 else None
        services.append(Service(sid, priority=rng.randint(1, 3), admissible=tuple(options), baseline_alt=baseline_alt))

    # Deliberately tight limits for two of the four drivers, so the driving
    # time constraint (Eq. 4 / Eq. 11) is a real, binding consideration and
    # not a formality every candidate satisfies automatically.
    driving_time_limit = {"D1": 260.0, "D2": 440.0, "D3": 260.0, "D4": 440.0, "D5": 440.0, "D6": 440.0}
    driving_time_prior = {d: 0.0 for d in drivers}

    return Instance(
        services=tuple(services),
        driving_time_prior=driving_time_prior,
        driving_time_limit=driving_time_limit,
        # Illustrative weights/normalization only -- Eq. (8)'s w_j, b_j are
        # [TO BE CALIBRATED] per Section 2.5; equal weights and
        # instance-derived scales stand in for that calibration here.
        weights={"delay": 0.25, "reschedule": 0.25, "idle": 0.25, "workload": 0.25},
        norm_refs={"delay": 60.0, "reschedule": float(N_SERVICES), "idle": 240.0, "workload": 120.0},
    )
