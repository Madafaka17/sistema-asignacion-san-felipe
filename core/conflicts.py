"""Construction of the conflict-pair set (Eq. 3) and the per-driver
cumulative driving-time constraint (Eq. 4).

Both are precomputed once per Instance, independently of any chromosome,
and then reused by every fitness evaluation -- this is what keeps a single
evaluation close to linear in the instance size instead of quadratic (see
the complexity discussion in the article, Section 2.8).
"""
from __future__ import annotations

from collections import defaultdict
from itertools import combinations

from .domain import AdmissibleTriple, Instance, Service


def _intervals_overlap(a: AdmissibleTriple, b: AdmissibleTriple, min_transition: float) -> bool:
    """True if using both a and b back-to-back on the SAME resource would
    violate the minimum transition requirement tau^min (Table 1), i.e. the
    two intervals [start, start+duration], expanded by tau^min on each
    side, intersect.
    """
    a_end = a.start_time + a.duration
    b_end = b.start_time + b.duration
    return not (a_end + min_transition <= b.start_time or b_end + min_transition <= a.start_time)


def build_conflict_pairs(
    services: tuple[Service, ...],
    min_transition: float = 0.0,
) -> tuple[tuple[tuple[str, int], tuple[str, int]], ...]:
    """Build the conflict-pair set of Eq. (3):

        script-C = { ((s,a),(t,b)) : a in A_s, b in A_t, s != t,
                      a and b share a vehicle or a driver,
                      and cannot both be executed given tau^min }

    Returned as a tuple, sorted, of ((service_id, option_index),
    (service_id, option_index)) pairs, each stored once with the
    lexicographically smaller (service_id, option_index) first. The
    result is deduplicated with a set during construction but converted
    to a SORTED tuple before being returned: Python randomizes string
    hash values per process (PYTHONHASHSEED), so iterating a set of
    string-keyed tuples directly would silently make `repair`'s
    resampling order -- and therefore the exact solution the genetic
    algorithm converges to -- depend on the interpreter's hash seed
    rather than only on `GAConfig.random_seed`. Sorting here is what
    makes the fixed seed actually reproduce the same run.

    Built by grouping candidate triples per vehicle and per driver first
    (O(n*k) where n = number of services, k = max |A_s|), so only triples
    that already share a resource are ever compared pairwise, rather than
    comparing all O(n^2 k^2) triple pairs across the whole instance.
    """
    by_vehicle: dict[str, list[tuple[str, int, AdmissibleTriple]]] = defaultdict(list)
    by_driver: dict[str, list[tuple[str, int, AdmissibleTriple]]] = defaultdict(list)

    for s in services:
        for idx, a in enumerate(s.admissible):
            by_vehicle[a.vehicle_id].append((s.service_id, idx, a))
            by_driver[a.driver_id].append((s.service_id, idx, a))

    pairs: set[tuple[tuple[str, int], tuple[str, int]]] = set()
    for grouped in (by_vehicle, by_driver):
        for _resource_id, entries in grouped.items():
            for (sid1, i1, a1), (sid2, i2, a2) in combinations(entries, 2):
                if sid1 == sid2:
                    continue  # different alternatives of the SAME service are never both selected
                if _intervals_overlap(a1, a2, min_transition):
                    key1, key2 = (sid1, i1), (sid2, i2)
                    if key2 < key1:
                        key1, key2 = key2, key1
                    pairs.add((key1, key2))
    return tuple(sorted(pairs))


def build_driving_time_index(
    services: tuple[Service, ...],
) -> dict[str, list[tuple[str, int, float]]]:
    """Index, per driver, the (service_id, option_index, duration d_sa) of
    every admissible triple that would assign that driver -- used to
    evaluate the left-hand side of Eq. (4), H_c0 + sum_{a: c(a)=c} d_sa *
    x_sa, in O(services assigned to c) rather than O(|S|) per driver.
    """
    idx: dict[str, list[tuple[str, int, float]]] = defaultdict(list)
    for s in services:
        for opt_i, a in enumerate(s.admissible):
            idx[a.driver_id].append((s.service_id, opt_i, a.duration))
    return idx
