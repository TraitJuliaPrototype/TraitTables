# TableCore: the trait module. A table is named columns kept as dynamic values,
# `Vector{Dynamic{Column}}`, so that a new schema compiles nothing, while each column's code
# (summaries, row selection, sorting) runs in workers compiled per column type, the key:
#   - `Column{T}`: what table code reads from a column. Every `Vector` conforms; a reader's own
#     column type conforms by a supertrait (TraitCSV's `CSVColumn <: Column`);
#   - `Table`: names and columns, the columns of any conforming types.
# This is the storage proposed for DataFrames itself, `Vector{Dynamic{Column}}` in place of
# `Vector{AbstractVector}` (decisions.md, session 26).
@trait_module module TableCore
using TraitWorld
export Column, nrows, cell, Table, emptytable, ncol, nrow, colnames, colindex, column, addcolumn!,
       select, rows, head, sortby, floats, ColSummary, summarize, describe, cellstring

# --- the trait --------------------------------------------------------------------------------

"A column: its number of rows and its cells by index; `T` is the cell type."
@trait Column{T} begin
    T = eltype(Self)
    nrows(c::Column)::Int
    cell(c::Column{T}, i::Int)::T
end
@implement Column A where {A <: Vector} begin
    nrows(c) = length(c)
    cell(c, i) = c[i]
end

# --- the table ----------------------------------------------------------------------------------

"Named columns of equal length, each of any type conforming to `Column` (a `Vector{Dynamic{Column}}`)."
struct Table
    names::Vector{String}
    cols::Vector{Column}
end

emptytable() = Table(String[], Column[])
ncol(t::Table) = length(t.cols)
nrow(t::Table) = isempty(t.cols) ? 0 : nrows(t.cols[1])::Int     # one dispatch, on the first column
colnames(t::Table) = copy(t.names)
function colindex(t::Table, name::String)
    k = findfirst(==(name), t.names)
    k === nothing && throw(ArgumentError("no column \"$name\"; the columns are $(join(t.names, ", "))"))
    return k
end
column(t::Table, name::String) = t.cols[colindex(t, name)]

"Add column `c`, of any conforming type, under `name`. The column is kept as it is, not copied."
function addcolumn!(t::Table, name::String, c::Column)
    name in t.names && throw(ArgumentError("a column \"$name\" exists already"))
    isempty(t.cols) || nrows(c) == nrow(t) ||
        throw(DimensionMismatch("column \"$name\" has $(nrows(c)) rows, the table $(nrow(t))"))
    push!(t.names, name)
    push!(t.cols, Dynamic{Column}(c))
    return t
end

"The columns `names`, in that order; the columns are shared, not copied."
select(t::Table, names::Vector{String}) = Table(copy(names), Column[t.cols[colindex(t, n)] for n in names])

# --- row selection: a worker per column type builds the new column --------------------------------

"Cells `idx` of a column, as a new column of the same cell type."
take(c::Column, idx::Vector{Int}) = Dynamic{Column}([cell(c, i) for i in idx])

"The rows `idx`, in that order, as a new table."
rows(t::Table, idx::Vector{Int}) = Table(copy(t.names), Column[take(c, idx)::Dynamic{Column} for c in t.cols])
head(t::Table, n::Int) = rows(t, collect(1:min(n, nrow(t))))

"The permutation that sorts a column."
function sortperm_col(c::Column)
    v = [cell(c, i) for i in 1:nrows(c)]
    return sortperm(v)
end
"The table sorted by column `name`."
sortby(t::Table, name::String) = rows(t, sortperm_col(column(t, name))::Vector{Int})

# --- numbers and summaries ------------------------------------------------------------------------

"A column of numbers as `Float64`s, for plotting and statistics."
function floats(c::Column)
    n = nrows(c)
    v = Vector{Float64}(undef, n)
    for i in 1:n
        v[i] = Float64(cell(c, i))
    end
    return v
end
floats(t::Table, name::String) = floats(column(t, name))::Vector{Float64}

"A column's summary: for numbers, mean, sample standard deviation, min, max and sum; otherwise the number of distinct cells."
struct ColSummary
    name::String
    eltype::String
    n::Int
    numeric::Bool
    mean::Float64
    std::Float64
    min::Float64
    max::Float64
    sum::Float64
    ndistinct::Int
end

function numsummary(c::Column, name::String, n::Int, T::String)
    s = 0.0
    lo, hi = Inf, -Inf
    for i in 1:n
        x = Float64(cell(c, i))
        s += x
        lo = min(lo, x)
        hi = max(hi, x)
    end
    m = s / n
    q = 0.0
    for i in 1:n
        q += (Float64(cell(c, i)) - m)^2
    end
    return ColSummary(name, T, n, true, m, n > 1 ? sqrt(q / (n - 1)) : NaN, lo, hi, s, 0)
end
othersummary(c::Column, name::String, n::Int, T::String) =
    ColSummary(name, T, n, false, NaN, NaN, NaN, NaN, NaN, length(Set(cell(c, i) for i in 1:n)))

"A column's summary, compiled per column type."
function summarize(c::Column, name::String)
    n = nrows(c)
    x = n == 0 ? nothing : cell(c, 1)
    T = string(typeof(x))
    n == 0 && return ColSummary(name, "", 0, false, NaN, NaN, NaN, NaN, NaN, 0)
    return x isa Real ? numsummary(c, name, n, T)::ColSummary : othersummary(c, name, n, T)::ColSummary
end

"Every column's summary (one dispatch per column)."
describe(t::Table) = ColSummary[summarize(t.cols[k], t.names[k])::ColSummary for k in eachindex(t.cols)]

"A cell as text, for printing."
cellstring(c::Column, i::Int) = string(cell(c, i))

end
