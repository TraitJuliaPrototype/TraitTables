# TraitTables

A table shaped like a DataFrame, written with traits. A table holds named columns of any types that join the trait `Column`, in a `Vector{Column}`. This is the storage proposed for DataFrames itself: `Vector{Column}` in place of `Vector{AbstractVector}`, adoptable one function at a time behind DataFrames' API. TraitCSV reads into it, and TraitReport uses both.

## The package

- **`TableCore`** (`src/TableCore.jl`): the trait module (`@trait_module`).
  - `@trait Column{T}`: `nrows(c)::Int`, `cell(c, i)::T`, with `T = eltype(Self)`.
  - Members: every `Vector`, by the family `@implement Column{T} Vector{T} where {T}`. A user's column type joins by its own membership (the tests' `Fill`); a reader's columns join through a subtrait (TraitCSV's `CSVColumn <: Column`).
  - `Table`: names and columns, `Vector{Column}`, each column kept as it was added.
  - The table's functions: `emptytable`, `ncol`, `nrow`, `colnames`, `colindex`, `column`, `addcolumn!`, `select`, `rows`, `head`, `sortby`, `floats`, `ColSummary`, `summarize`, `describe`, `cellstring`.
- **`TraitTables`** (`src/TraitTables.jl`): the ordinary layer. `table("x" => v, …)`, `t["x"]`, `size`, printing, `summary_text`, `floats(t, name; skipmissing)`, `numericnames(t)`.

**Missing cells.** A column of `Union{Missing, T}` cells is a member like any `Vector`. Summaries count missing cells and leave them out. `floats(t, name)` refuses a missing cell with a message that names the fix (`skipmissing = true`).

**The baseline without traits** is `../TraitReport/PlainTables`, with the same features.

## How it uses the design

- `Column` erases nothing by default (no `@default_dynamic`). A new schema compiles nothing in the table's own loops; each column's code (summaries, row selection, sorting, conversion to `Float64`) is compiled per column type.
- The loops hand each column over as the wrapper, `compiled_for(c)`, where they want the column's own code (`rows`, `sortby`, `describe`, `floats`). In a session the wrapper is made for the column's type, and the call runs code compiled for it. In a trimmed build the wrapper's constructor branches over the column types the program uses; a plain call there would run one copy at `Column`, where the cells are known only as `Any`. The build does not yet carry the branches on to the call that takes the wrapper where the program has more than three column types: the design repository's open issue 242.
- `eltype` of the wrapper is its column's, so a new column made from it (`take`, the rows of `sortby`) has the column's cell type: a `Vector{Float64}` column stays one. The table keeps its columns as they were added; no box is made.
- The tests check that the user's own column type gets its own compiled instances of the table's column code, at `Compiled{Fill}` (`test/runtests.jl`).

## Running

From the workspace root:

```sh
source env.sh
julia-next/julia --project=TraitTables -e 'using Pkg; Pkg.test()'
```

## Results

The current numbers, each against plain Julia or Python, are in the design repository's `writeup/design/evidence.md`. The suites' last results are in its `writeup/state.md` §3.

- Tests: `julia --project=. -e 'using Pkg; Pkg.test()'` on `julia-unified`: 24 pass (2026-11-08, `unified` f90d152208; `experiments/implementation/stack/logs/w104-slice1-TraitTables.log`).
- Tests on `julia-next`: 26 pass in 3 testsets (2026-11-18, `next` 02139b2168, TraitWorld 3e64ede; `experiments/implementation/w156/logs/after-tables.log`).

## The design

- The design: the design repository's `writeup/reference/` (traits, facts, compiler, lowering).
- The lessons of the ports: `writeup/intro/porting.md`.
