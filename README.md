# TraitTables

A DataFrame-shaped table written in the trait world, the table half of TraitReport's form (t) (`../TraitReport/README.md`). Decided in session 26 (`../writeup/decisions.md`: "TraitTables and TraitCSV"); first version in session 27.

## On the unified build (branch `unified`, W-104)

This branch follows the design under "traits are abstract types" on Julia's unified build (`julia-unified`, branch `unified`), with TraitWorld's branch `unified`. The sections below describe the earlier build (branch `main`).

- `Column{T}` by the family `@implement Column{T} Vector{T} where {T}`; a table keeps its columns in a `Vector{Column}`, each as it was added (the earlier `Kept{Column}` is gone: a container typed by a trait holds members plain, traits §8.1); the table's loops cast a column with `compiled_for`.
- Tests: `julia --project=. -e 'using Pkg; Pkg.test()'` on `julia-unified`: 24 pass (2026-11-08, `unified` f90d152208; `experiments/unification/stack/logs/w104-slice1-TraitTables.log`).

- **`Column{T}`** (`src/TableCore.jl`): `nrows(c)`, `cell(c, i)`; `T = eltype(Self)`. Every `Vector` conforms by a family declaration; a user's column type conforms by its own methods (the test's `Fill`); a reader's columns conform through a subtrait (TraitCSV's `CSVColumn <: Column`).
- **`Table`:** names and `Vector{Column}` columns, that is `Vector{Kept{Column}}`, each column with its attribute (`Dynamic` by default at `addcolumn!`). A new schema compiles nothing unless the caller casts a column; each column's code (summaries, row selection, sorting, conversion to `Float64`) runs in workers compiled per column type, the key.
- **Missing cells** (session 30): a column of `Union{Missing, T}` cells conforms like any `Vector`. Summaries count missing cells and leave them out; `floats(t, name)` refuses a missing cell with a message that names the fix (`skipmissing = true`).
- **The ordinary layer** (`src/TraitTables.jl`): `table("x" => v, …)`, `t["x"]`, `size`, printing, `summary_text`, `floats(t, name; skipmissing)`, `numericnames(t)`.
- **The proposed storage of DataFrames itself:** `Vector{Column}` in place of `Vector{AbstractVector}`, adoptable one function at a time behind DataFrames' API.

Tests: `julia --project=. -e 'using Pkg; Pkg.test()'` (24).

The fair baseline without traits is `../TraitReport/PlainTables`; it has every feature above.
