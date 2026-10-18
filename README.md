# TraitTables

A DataFrame-shaped table written in the trait world, the table half of TraitReport's form (t) (`../TraitReport/README.md`). Decided in session 26 (`../writeup/decisions.md`: "TraitTables and TraitCSV"); first version in session 27.

- **`Column{T}`** (`src/TableCore.jl`): `nrows(c)`, `cell(c, i)`; `T = eltype(Self)`. Every `Vector` conforms by a family declaration; a user's column type conforms by its own methods (the test's `Fill`); a reader's columns conform through a subtrait (TraitCSV's `CSVColumn <: Column`).
- **`Table`:** names and `Vector{Column}` columns, that is `Vector{Dynamic{Column}}`. A new schema compiles nothing; each column's code (summaries, row selection, sorting, conversion to `Float64`) runs in workers compiled per column type, the key.
- **Missing cells** (session 30): a column of `Union{Missing, T}` cells conforms like any `Vector`. Summaries count missing cells and leave them out; `floats(t, name)` refuses a missing cell with a message that names the fix (`skipmissing = true`).
- **The ordinary layer** (`src/TraitTables.jl`): `table("x" => v, …)`, `t["x"]`, `size`, printing, `summary_text`, `floats(t, name; skipmissing)`, `numericnames(t)`.
- **The proposed storage of DataFrames itself:** `Vector{Dynamic{Column}}` in place of `Vector{AbstractVector}`, adoptable one function at a time behind DataFrames' API.

Tests: `julia --project=. -e 'using Pkg; Pkg.test()'` (24).

The fair baseline without traits is `../TraitReport/PlainTables`; it has every feature above.
