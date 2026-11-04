"""Runs the genetic algorithm of core/scheduler.py on the illustrative
synthetic instance and prints the result. This script -- not core/ -- is
where printing and other I/O belong.

    python3 examples/run_demo.py
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.scheduler import GAConfig, run
from examples.illustrative_instance import build_instance


def main() -> None:
    instance = build_instance()
    # A small population/generation budget is used here on purpose, so the
    # generation-by-generation trace below stays short enough to read in
    # full. Section 2.9's protocol uses the thesis's larger proposed
    # ranges (50-100 population, 100-200 generations) for the real,
    # company-data comparison.
    config = GAConfig(
        population_size=10,
        num_generations=60,
        random_seed=42,
    )

    t0 = time.perf_counter()
    result = run(instance, config)
    elapsed = time.perf_counter() - t0

    b = result.breakdown
    print("=== Illustrative synthetic instance (NOT company data) ===")
    print(f"Services with admissible options: {len(result.services)}")
    print(f"Services with no admissible option (u_s = 1, Eq. 5): "
          f"{len(instance.uncovered_services())}")
    print(f"Generations: {config.num_generations}  Population: {config.population_size}  "
          f"Seed: {config.random_seed}")
    print(f"Wall-clock time: {elapsed:.3f} s")
    print()
    print("--- Best chromosome found (alpha, Eq. 9) ---")
    for s, idx in zip(result.services, result.chromosome):
        a = s.admissible[idx]
        print(f"  {s.service_id}: option {idx} -> vehicle={a.vehicle_id} "
              f"driver={a.driver_id} start={a.start_time:.0f} dur={a.duration:.0f}")
    print()
    print("--- Feasibility (Eq. 10-11) ---")
    print(f"  Conflict violations V(alpha):      {b.conflict_violations}")
    print(f"  Drivers over their limit:          {b.overlimit_drivers}")
    print(f"  Total driving-time excess:         {b.driving_time_excess:.1f}")
    print(f"  Feasible (alpha corresponds to X in F): {b.is_feasible}")
    print()
    print("--- Loss components (Eq. 8) ---")
    print(f"  delay={b.delay:.1f}  reschedule={b.reschedule}  "
          f"idle={b.idle:.1f}  workload_spread={b.workload_spread:.2f}")
    print(f"  J(alpha) = {b.loss:.4f}")
    print()
    print(f"--- Fitness (Eq. 12): {b.fitness:.4f} ---")
    print()
    print("--- Convergence (best fitness per generation) ---")
    hist = result.best_fitness_by_generation
    shown = set(range(0, min(len(hist), 16))) | set(range(0, len(hist), 10)) | {len(hist) - 1}
    for g in sorted(shown):
        marker = "  (final)" if g == len(hist) - 1 else ""
        print(f"  gen {g:3d}: {hist[g]:.4f}{marker}")


if __name__ == "__main__":
    main()
