# `core/` — núcleo Python del algoritmo genético (archivos originales)

**Estos son los archivos con los que se ejecutó el experimento del Anexo E.** Llegaron
en el paquete del repositorio del núcleo de la sesión 8 (`paquete_repositorio.zip`,
7/10/2026), entregado por el autor el 4/11/2026, y sus huellas SHA-256 son las
registradas el 6/10/2026 en
[`experimentos/sanfelipe/registro_protocolo.txt`](../experimentos/sanfelipe/registro_protocolo.txt)
(compruébelo con la orden de abajo o con el paso P01 de la prueba de humo). Sustituyen
a la reimplementación que este repositorio publicó el 17/10/2026 mientras faltaban.

```bash
cd experimentos/sanfelipe
grep -E '^[0-9a-f]{64}' registro_protocolo.txt \
  | sed 's#experimentos/sintetico_sanfelipe/##; s#  experimentos/poc_cap3/#  ../poc_cap3/#; s#  core/#  ../../core/#' \
  | sha256sum -c
```

| Módulo | Contenido |
|---|---|
| `domain.py` | `AdmissibleTriple`, `Service`, `Instance` (ec. 1 a 3 y 15) |
| `conflicts.py` | Γ ordenado (`build_conflict_pairs`) e índice de conducción (`build_driving_time_index`) |
| `fitness.py` | F(X), J(X), Φ(X) y E(X) (`evaluate`, `FitnessBreakdown`, `_loss_components`) |
| `repair.py` | reparación aleatoria acotada (`repair`) y reparación dirigida por prioridad (`repair_targeted`, `build_conflict_index`) |
| `scheduler.py` | `GAConfig`, `ScheduleResult`, `_make_operators` y `run` sobre PyGAD 3.7.0 |

Pruebas: [`tests/test_core.py`](../tests/test_core.py) (9 pruebas previas) y
[`pruebas/nucleo/`](../pruebas/nucleo/README.md) (100 casos del Anexo I); corrida paso a
paso del capítulo IV: [`pruebas/corrida/`](../pruebas/corrida/README.md); prueba de humo
con MySQL: [`pruebas/humo/`](../pruebas/humo/) y [`docs/MANUAL_COMPILACION.md`](../docs/MANUAL_COMPILACION.md).
Dependencias con huellas: [`requirements.lock`](../requirements.lock). El `requirements.txt`
de la raíz de este repositorio es el del esqueleto inicial (`src/`), no el del núcleo.

El sistema (`paquetes/dominio`, `servidor`, `cliente`) usa su propio núcleo en Dart; esta
carpeta es el núcleo de referencia de la tesis.

---

A continuación se conserva, sin cambios, el README original del repositorio del núcleo
(en inglés; las rutas `tests/` y `examples/` corresponden a `tests/test_core.py` y
`examples/` de este repositorio).

## Scheduling GA — core module (README original)

Genetic-algorithm core (chromosome encoding, fitness, crossover/mutation with
repair) for the integrated vehicle–driver–departure scheduling problem of
**Empresa de Transportes y Turismo San Felipe S.A.C.** This is the code
referenced by Section 2.8 ("Genetic algorithm specification and
implementation") of the IJIEM article draft and by the corresponding chapter
of the thesis. It gives the domain logic, mathematical model, and algorithm
an executable, testable implementation, closing the correspondence chain
from Table 1's notation to a running program.

**Scope.** This repository holds only the genetic-algorithm core: encoding,
fitness evaluation, and the crossover/mutation/repair operators. The
presentation layer, the validation/business-logic layer, and the MySQL
persistence layer (Figures 1, 2, 4, 5) are specified elsewhere in the thesis
and are out of scope here — `core/` takes an `Instance` and returns a
`ScheduleResult`, with no I/O, no database access, and no UI dependency, so
it can be called from that business-logic layer without modification.

## Repository layout

```
core/
  domain.py      Instance / Service / AdmissibleTriple — pure data (Table 1, Eq. 1)
  conflicts.py    Conflict-pair set (Eq. 3) and driving-time index (Eq. 4)
  fitness.py      Chromosome type, FitnessBreakdown, evaluate() (Eq. 9-12)
  repair.py       Bounded greedy constraint repair (Section 2.6)
  scheduler.py    GAConfig, ScheduleResult, run() — wires the above into PyGAD
examples/
  illustrative_instance.py   Synthetic 20-service/6-vehicle/6-driver fixture (NOT company data)
  run_demo.py                 Runs the GA on that fixture and prints a full report
tests/
  test_core.py    9 unit/regression/reproducibility tests (pytest)
```

## Requirements

Python 3.11+. Runtime dependencies are pinned in `requirements.txt`
(`pygad==3.7.0`, `numpy==2.4.4`); test-only dependencies are in
`requirements-dev.txt` (`pytest==9.1.1`).

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
```

## Quickstart

```bash
python3 -m pytest tests/ -v      # 9 tests, no network/DB required
python3 examples/run_demo.py     # runs the GA on the illustrative instance, prints the report below
```

`run_demo.py` is the only place in this repository that prints anything or
depends on wall-clock time; `core/` itself is a pure function of its inputs.

## Method specification: equation → pseudocode → code

Each formalized step of the algorithm is implemented as a small,
independently callable, unit-tested component. No component performs I/O;
each is exercised directly by `tests/test_core.py` without a database, a UI,
or PyGAD itself.

| Step | Equation (article, Section 2.8) | Pseudocode (article, Algorithm 1) | Code |
|---|---|---|---|
| Chromosome encoding | Eq. (9): α(s) ∈ A_s for every s with A_s ≠ ∅ | `chromosomes <- ...  // Eq. (9)` | `core/domain.py: Instance.services_with_options`, gene space built in `core/scheduler.py: run` |
| Conflict-pair set | Eq. (3), realized count Eq. (10): V(α) | `pairs <- BuildConflictPairs(services)  // Eq. (3)` | `core/conflicts.py: build_conflict_pairs` |
| Driving-time excess | Eq. (4), excess Eq. (11): e_c(α) | `Evaluate(...)  // Eq. (10)-(12)` | `core/fitness.py: _driving_time_excess`, `build_driving_time_index` in `core/conflicts.py` |
| Loss components | Eq. (8): J(X), via z_delay, z_reschedule, z_idle, z_workload | (inside `Evaluate`) | `core/fitness.py: _loss_components` |
| Scalarized fitness | Eq. (12): fit(α) = −(M·Φ(α) + Σ e_c(α) + J(α)) | `fitness[chromosome] <- Evaluate(...)  // Eq. (10)-(12)` | `core/fitness.py: evaluate` |
| Selection | tournament, Section 2.6 | `parents <- TournamentSelect(...)` | `parent_selection_type="tournament"` in `core/scheduler.py: run` (delegated to PyGAD) |
| Crossover + repair | uniform crossover, Section 2.6; repair, Section 2.6 | `offspring <- Repair(UniformCrossover(parents), pairs)` | `core/scheduler.py: _make_operators.crossover_with_repair`, `core/repair.py: repair` |
| Mutation + repair | Section 2.6 | `offspring <- Repair(Mutate(...), pairs)` | `core/scheduler.py: _make_operators.mutation_with_repair`, `core/repair.py: repair` |
| Elitism + population loop | Section 2.6 | `population <- Elitism(...)` | `keep_elitism=...` in `core/scheduler.py: run` (delegated to PyGAD [4]) |
| Result / DB-topology mapping | assignment (service, vehicle, driver, departure alternative) persisted into the SCHEDULES table of Figure 5 | `RETURN chromosome ...` | `core/scheduler.py: ScheduleResult.assignments` |

The class diagram of Figure 6 (`../uml_en/6_class.puml` in the article
sources) is the structural view of this same table: `ConflictBuilder`,
`FitnessEvaluator`, and `RepairOperator` are the classes that realize the
equations above, `SchedulingGA` is `core/scheduler.py: run`, and
`ScheduleResult` is this module's only output — exactly what the
business-logic layer of Figure 4 persists via Figure 5.

## Complexity

Conflict-pair construction groups admissible triples by shared resource
(vehicle or driver) before comparing pairs, so it costs O(nk) for n = |S|
services and k = max_s |A_s| in the typical case, and O((nk)²) only in the
worst case where every triple shares one resource. Each fitness evaluation
is then O(|conflict pairs| + nk): one fixed pass over the precomputed
conflict pairs and one fixed pass over the services. A full run is therefore
O(G·P·(|conflict pairs| + nk)) for G generations and population size P,
dominated by fitness evaluation rather than by selection, crossover, or
repair. This was checked empirically by timing `build_conflict_pairs` and a
full fitness evaluation on instances scaled from 10 to 160 services at fixed
population/generation counts: wall-clock time grew approximately linearly,
consistent with the typical-case analysis rather than the worst case.

## Reproducibility

Every stochastic step (initial population, crossover, mutation, repair) is
seeded from `GAConfig.random_seed`; `tests/test_core.py:
test_ga_run_is_reproducible_for_a_fixed_seed` runs the GA twice with the
same config and asserts both the returned chromosome and the full
generation-by-generation fitness trace are identical.

Getting this right surfaced one real implementation bug, kept here as
documentation of the failure mode rather than only as a fixed line: the
conflict-pair set was first built as a Python `set` of string-keyed tuples
and returned by iterating it directly. Python randomizes string-hash values
per process (`PYTHONHASHSEED`), so the *iteration order* of that set — and
therefore the order `repair()` visits conflicts in — silently depended on
the interpreter's hash seed rather than only on `GAConfig.random_seed`. Two
runs with an identical configured seed, launched as separate processes,
could converge to different chromosomes. The fix is the one-line change in
`core/conflicts.py: build_conflict_pairs` from returning the set (or a
`frozenset`) to returning `tuple(sorted(pairs))`; `test_core.py:
test_conflict_pairs_are_deterministically_ordered` is the regression test.
The failure mode is generic to any repair or greedy procedure that iterates
a hash-based collection, which is why it is documented here rather than
treated as a one-off fix.

## Illustrative example (not company data)

`examples/illustrative_instance.py` generates — from a fixed seed,
independent of the GA's own `random_seed` — a synthetic instance of 20
services, 6 vehicles, and 6 drivers over an 8-hour shift, with two of the
six drivers given a driving-time limit tight enough to be binding. It exists
only to verify the implementation end to end and to illustrate the
chromosome encoding; it is **not** San Felipe's operational data, which
remains `[TO BE OBTAINED FROM COMPANY DATA]` per Section 2.2 of the article,
and the weights/normalization references it uses stand in for the
`[TO BE CALIBRATED]` values of Section 2.5. `python3 examples/run_demo.py`
runs the GA on this fixture (population 10, 60 generations, seed 42) and
prints the full breakdown; as executed for this submission it returns a
feasible schedule (zero conflict violations, no driver over its limit) from
generation 0, improving loss from an initial 1.1108 to a stable 0.8385 by
generation 11 (fitness improving from −1.1108 to −0.8385), unchanged for the
remaining 49 generations. This run verifies that the implementation searches
and converges as specified; it is not evidence about San Felipe's actual
operational performance, which requires the company data and protocol of
Sections 2.2 and 2.9 of the article.

## Testing

```bash
python3 -m pytest tests/ -v
```

Nine tests cover: conflict detection on overlapping vs. disjoint resources
and the minimum-transition gap; deterministic conflict-pair ordering (the
regression test for the bug above); driving-time excess only when a driver
is over limit; that conflicts are penalized ahead of loss in the fitness
(Eq. 12's intent); that repair never increases the number of violations it
is asked to fix; that a service with no admissible option is excluded from
the chromosome and reported separately (Eq. 5); and end-to-end
reproducibility of a full `run()` call. All nine pass with no network or
database access.

## Out of scope

The presentation layer, the validation/business-logic layer proper
(Section 2.4's operating-rule checks upstream of this module), MySQL
persistence (Figure 5), and any UI are not part of this repository. Real
instance data, final GAConfig values (population, generations, crossover/
mutation probabilities, elitism fraction), and the comparison against manual
scheduling, a greedy heuristic, and an integer-programming reference all
remain `[TO BE OBTAINED FROM COMPANY DATA]` / `[TO BE CALIBRATED]` per
Sections 2.2, 2.5, and 2.9 of the article — this module is the implementation
those sections call, not a substitute for the experimental protocol itself.
