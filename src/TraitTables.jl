"""
    TraitTables

A DataFrame-shaped table written in the trait world (`TableCore`): named columns kept as
`Vector{Column}` (each column with its attribute, `Dynamic` by default), so that a new schema compiles nothing, while each column's code runs
compiled per column type. This module is the ordinary layer: building tables from vectors,
indexing by name, printing.
"""
module TraitTables
using TraitWorld

include("TableCore.jl")
using .TableCore
export Table, Column, nrows, cell, ncol, nrow, colnames, column, addcolumn!, select, rows, head, sortby,
       floats, ColSummary, describe, summary_text, numericnames

"A table from `name => vector` pairs (the vectors are kept, not copied)."
function table(pairs::Pair...)
    t = TableCore.emptytable()
    for (name, v) in pairs
        TableCore.addcolumn!(t, String(name), v)
    end
    return t
end
TableCore.Table(pairs::Pair...) = table(pairs...)

Base.getindex(t::Table, name::AbstractString) = TableCore.column(t, String(name))
Base.getindex(t::Table, name::Symbol) = TableCore.column(t, String(name))
Base.size(t::Table) = (TableCore.nrow(t), TableCore.ncol(t))
Base.propertynames(t::Table) = Tuple(Symbol.(t.names))
TableCore.select(t::Table, names::AbstractString...) = TableCore.select(t, String[names...])

function Base.show(io::IO, ::MIME"text/plain", t::Table)
    nr, nc = size(t)
    println(io, nr, "×", nc, " Table")
    nc == 0 && return
    shown = min(nr, 8)
    cells = [[TableCore.cellstring(t.cols[k], i)::String for i in 1:shown] for k in 1:nc]
    w = [max(length(t.names[k]), maximum(length, cells[k]; init = 0)) for k in 1:nc]
    println(io, join((rpad(t.names[k], w[k]) for k in 1:nc), "  "))
    for i in 1:shown
        println(io, join((rpad(cells[k][i], w[k]) for k in 1:nc), "  "))
    end
    nr > shown && print(io, "⋮ (", nr - shown, " more rows)")
end
"""
    floats(t, name; skipmissing = false)

Column `name` as `Float64`s. A missing cell is an error, unless `skipmissing` leaves such cells out.
"""
TableCore.floats(t::Table, name::AbstractString; skipmissing::Bool = false) =
    TableCore.floats(compiled_for(TableCore.column(t, String(name))), skipmissing)::Vector{Float64}
"The names of the columns whose cells are numbers (missing cells allowed)."
numericnames(t::Table) = String[s.name for s in TableCore.describe(t) if s.numeric]

Base.show(io::IO, t::Table) = print(io, size(t, 1), "×", size(t, 2), " Table(", join(t.names, ", "), ")")

"Per column one line: for numbers mean, sample standard deviation, min, max and sum; otherwise the distinct cells; missing cells counted."
function summary_text(t::Table)
    io = IOBuffer()
    for s in TableCore.describe(t)
        if s.numeric
            print(io, rpad(s.name, 6), " mean ", round(s.mean; digits = 4), "  std ", round(s.std; digits = 4),
                  "  min ", s.min, "  max ", s.max, "  sum ", round(s.sum; digits = 4))
        else
            print(io, rpad(s.name, 6), " ", s.eltype, ", ", s.ndistinct, " distinct of ", s.n)
        end
        println(io, s.nmissing > 0 ? string("  missing ", s.nmissing) : "")
    end
    return String(take!(io))
end

# a precompile workload: the cell types a reader produces, and the table's operations
TraitWorld.@workload begin
    t = table("x" => [0.5, 1.5, 2.5], "n" => [3, 1, 2], "s" => ["b", "a", "c"])
    summary_text(t)
    sprint(show, MIME"text/plain"(), t)
    sprint(show, MIME"text/plain"(), sortby(t, "n"))
    head(select(t, "x", "s"), 2)
    floats(t, "x"); floats(t, "n")
    floats(t, colnames(t)[1])
    m = table("a" => Union{Missing,Float64}[1.0, missing, 2.0], "b" => Union{Missing,Int}[missing, 1, 2],
              "c" => Union{Missing,String}["x", missing, "y"])
    summary_text(m)
    floats(m, "a"; skipmissing = true)
    numericnames(m)
end

end
