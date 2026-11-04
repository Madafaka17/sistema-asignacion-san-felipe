"""Unit tests for core/. Run with:  python3 -m pytest tests/ -v

These exercise the pure domain logic directly -- no PyGAD, no randomness
beyond what a test explicitly seeds -- plus one end-to-end reproducibility
check of the full GA loop.
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.conflicts import build_conflict_pairs, build_driving_time_index
from core.domain import AdmissibleTriple, Instance, Service
from core.fitness import evaluate
from core.repair import repair
from core.scheduler import GAConfig, run


def opt(sid, v, c, h, start, duration):
    return AdmissibleTriple(sid, v, c, h, float(start), float(duration))


def test_conflict_detected_for_overlapping_same_vehicle():
    services = (
        Service("S1", 1, (opt("S1", "V1", "D1", "h0", 0, 60),)),
        Service("S2", 1, (opt("S2", "V1", "D2", "h0", 30, 60),)),  # overlaps S1 on V1
    )
    pairs = build_conflict_pairs(services)
    assert pairs == ((("S1", 0), ("S2", 0)),)


def test_no_conflict_for_disjoint_resources_and_times():
    services = (
        Service("S1", 1, (opt("S1", "V1", "D1", "h0", 0, 60),)),
        Service("S2", 1, (opt("S2", "V2", "D2", "h0", 0, 60),)),  # different vehicle AND driver
    )
    assert build_conflict_pairs(services) == ()


def test_no_conflict_when_transition_gap_respected():
    services = (
        Service("S1", 1, (opt("S1", "V1", "D1", "h0", 0, 60),)),
        Service("S2", 1, (opt("S2", "V1", "D1", "h0", 65, 60),)),  # 5-min gap after S1 ends at 60
    )
    assert build_conflict_pairs(services, min_transition=5.0) == ()
    assert build_conflict_pairs(services, min_transition=10.0) != ()


def test_conflict_pairs_are_deterministically_ordered():
    # Regression test for the hash-seed reproducibility bug found while
    # building the illustrative instance: build_conflict_pairs must return
    # a stable order independent of PYTHONHASHSEED, since `repair` walks
    # this sequence and its choices depend on the order it sees pairs in.
    services = tuple(
        Service(f"S{i}", 1, (opt(f"S{i}", "V1", "D1", "h0", i * 10, 60),))
        for i in range(6)
    )
    first = build_conflict_pairs(services)
    second = build_conflict_pairs(services)
    assert first == second
    assert list(first) == sorted(first)


def test_driving_time_excess_only_when_over_limit():
    a = opt("S1", "V1", "D1", "h0", 0, 100)
    b = opt("S2", "V2", "D1", "h0", 200, 100)
    services = (Service("S1", 1, (a,)), Service("S2", 1, (b,)))
    instance = Instance(
        services=services,
        driving_time_prior={"D1": 0.0},
        driving_time_limit={"D1": 150.0},   # 100 + 100 = 200 > 150 -> excess 50
    )
    conflict_pairs = build_conflict_pairs(instance.services_with_options())
    result = evaluate((0, 0), instance, conflict_pairs)
    assert result.overlimit_drivers == 1
    assert result.driving_time_excess == 50.0
    assert not result.is_feasible

    instance_ok = Instance(
        services=services,
        driving_time_prior={"D1": 0.0},
        driving_time_limit={"D1": 250.0},   # 200 <= 250 -> no excess
    )
    result_ok = evaluate((0, 0), instance_ok, conflict_pairs)
    assert result_ok.overlimit_drivers == 0
    assert result_ok.driving_time_excess == 0.0
    assert result_ok.is_feasible


def test_fitness_heavily_penalizes_conflicts_over_loss():
    services = (
        Service("S1", 1, (opt("S1", "V1", "D1", "h0", 0, 60), opt("S1", "V2", "D2", "h1", 0, 60))),
        Service("S2", 1, (opt("S2", "V1", "D1", "h0", 30, 60), opt("S2", "V3", "D3", "h1", 30, 60))),
    )
    instance = Instance(services=services, driving_time_prior={}, driving_time_limit={},
                        weights={"idle": 1.0}, norm_refs={"idle": 60.0})
    conflict_pairs = build_conflict_pairs(instance.services_with_options())
    infeasible = evaluate((0, 0), instance, conflict_pairs, big_m=1000.0)  # both option 0 -> shares V1,D1
    feasible = evaluate((0, 1), instance, conflict_pairs, big_m=1000.0)    # disjoint resources
    assert infeasible.conflict_violations == 1
    assert feasible.conflict_violations == 0
    assert feasible.fitness > infeasible.fitness


def test_repair_does_not_increase_violations():
    services = (
        Service("S1", 1, (opt("S1", "V1", "D1", "h0", 0, 60), opt("S1", "V4", "D4", "h1", 0, 60))),
        Service("S2", 1, (opt("S2", "V1", "D1", "h0", 30, 60), opt("S2", "V5", "D5", "h1", 30, 60))),
        Service("S3", 1, (opt("S3", "V1", "D1", "h0", 45, 60), opt("S3", "V6", "D6", "h1", 45, 60))),
    )
    conflict_pairs = build_conflict_pairs(services)
    assert len(conflict_pairs) > 0  # sanity: this crafted instance does have conflicts to fix

    rng = random.Random(0)
    bad = (0, 0, 0)  # all share V1/D1 with overlapping windows -> maximally conflicting

    def count_violations(chrom):
        selected = {s.service_id: idx for s, idx in zip(services, chrom)}
        return sum(
            1 for (sid1, i1), (sid2, i2) in conflict_pairs
            if selected.get(sid1) == i1 and selected.get(sid2) == i2
        )

    before = count_violations(bad)
    fixed = repair(bad, services, conflict_pairs, rng, max_passes=10)
    after = count_violations(fixed)
    assert after <= before
    assert after == 0  # this crafted 2-option case is fully repairable


def test_uncovered_service_excluded_from_ga_and_reported_separately():
    services = (
        Service("S1", 1, (opt("S1", "V1", "D1", "h0", 0, 60),)),
        Service("S2", 1, ()),  # A_s empty -> u_s = 1 (Eq. 5), never a gene
    )
    instance = Instance(services=services, driving_time_prior={}, driving_time_limit={})
    assert [s.service_id for s in instance.services_with_options()] == ["S1"]
    assert [s.service_id for s in instance.uncovered_services()] == ["S2"]


def test_ga_run_is_reproducible_for_a_fixed_seed():
    services = tuple(
        Service(
            f"S{i}", 1,
            (
                opt(f"S{i}", f"V{i % 3}", f"D{i % 3}", "h0", (i * 37) % 400, 45),
                opt(f"S{i}", f"V{(i + 1) % 3}", f"D{(i + 1) % 3}", "h1", (i * 37 + 10) % 400, 45),
            ),
        )
        for i in range(10)
    )
    instance = Instance(
        services=services,
        driving_time_prior={f"D{i}": 0.0 for i in range(3)},
        driving_time_limit={f"D{i}": 300.0 for i in range(3)},
        weights={"idle": 0.5, "workload": 0.5},
        norm_refs={"idle": 100.0, "workload": 50.0},
    )
    config = GAConfig(population_size=8, num_generations=15, random_seed=123)

    r1 = run(instance, config)
    r2 = run(instance, config)
    assert r1.chromosome == r2.chromosome
    assert r1.best_fitness_by_generation == r2.best_fitness_by_generation


if __name__ == "__main__":
    import pytest
    raise SystemExit(pytest.main([__file__, "-v"]))
