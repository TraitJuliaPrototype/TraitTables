using Test, TraitTables, TraitWorld

# a column type of the user's own: a constant column, conforming by its own methods
struct Fill; x::Float64; n::Int; end
Base.eltype(::Type{Fill}) = Float64                # the trait's equation T = eltype(Self)
TraitTables.nrows(f::Fill) = f.n
TraitTables.cell(f::Fill, i::Int) = f.x
@implement Column Fill

@testset "TraitTables" begin
    t = TraitTables.table("x" => [0.5, 1.5, 2.5], "n" => [3, 1, 2], "s" => ["b", "a", "c"])
    @test size(t) == (3, 3) && colnames(t) == ["x", "n", "s"]
    @test t.cols isa Vector{Column} && all(c -> c isa Column, t.cols)   # each column kept as it was added
    d = describe(t)
    @test d[1].numeric && d[1].mean == 1.5 && d[1].sum == 4.5 && d[1].eltype == "Float64"
    @test d[2].numeric && d[2].min == 1.0 && d[2].eltype == "Int64"
    @test !d[3].numeric && d[3].ndistinct == 3
    s = sortby(t, "n")
    @test floats(s, "x") == [1.5, 2.5, 0.5] && floats(s, "n") == [1.0, 2.0, 3.0]
    @test colnames(select(t, "s", "x")) == ["s", "x"]
    @test size(head(t, 2)) == (2, 3)
    @test occursin("3×3 Table", sprint(show, MIME"text/plain"(), t))
    # the user's column type joins a table and runs the table's code
    addcolumn!(t, "f", Fill(2.0, 3))
    @test describe(t)[4].mean == 2.0
    @test floats(sortby(t, "s"), "f") == [2.0, 2.0, 2.0]
    @test_throws DimensionMismatch addcolumn!(t, "g", [1.0])
    @test_throws ArgumentError column(t, "nope")
    @test occursin("mean 1.5", summary_text(t))
end

@testset "TraitTables: missing cells" begin
    m = TraitTables.table("a" => Union{Missing,Float64}[1.0, missing, 3.0], "b" => Union{Missing,Int}[missing, missing, 2],
                          "c" => Union{Missing,String}["x", missing, "x"], "d" => [missing, missing, missing])
    d = describe(m)
    @test d[1].numeric && d[1].mean == 2.0 && d[1].nmissing == 1 && d[1].eltype == "Union{Missing, Float64}"
    @test d[1].std ≈ sqrt(2.0) && d[1].sum == 4.0
    @test d[2].numeric && d[2].min == 2.0 && d[2].nmissing == 2 && isnan(d[2].std)
    @test !d[3].numeric && d[3].ndistinct == 1 && d[3].nmissing == 1
    @test !d[4].numeric && d[4].eltype == "Missing" && d[4].nmissing == 3
    @test floats(m, "a"; skipmissing = true) == [1.0, 3.0]
    e = try; floats(m, "a"); nothing; catch e; e; end
    @test e isa ArgumentError && occursin("skipmissing", e.msg)          # the message names the fix
    @test numericnames(m) == ["a", "b"]
    @test occursin("missing 1", summary_text(m))
    @test floats(sortby(m, "a"), "a"; skipmissing = true) == [1.0, 3.0]
end

# a column's code is compiled for the column's type: the table's loops hand each column over as the wrapper
# `compiled_for(c)`, whose code is compiled for the object's type (traits §7.4, §7.6); the user's own column type
# gets its own instances, at `Compiled{Fill}`
"Whether `f` holds code compiled for an argument of type `T` first."
compiled_at(f, T) = any(mi -> mi !== nothing && isdefined(mi, :cache) && mi.specTypes <: Tuple{typeof(f), T, Vararg},
                        [mi for m in methods(f) for mi in Base.specializations(m)])
@testset "TraitTables: a column's code per column type" begin
    t = TraitTables.table("x" => [1.0, 2.0, 3.0])
    addcolumn!(t, "f", Fill(2.0, 3))
    @test describe(t)[2].mean == 2.0 && floats(t, "f") == [2.0, 2.0, 2.0] && size(sortby(t, "f")) == (3, 2)
    TC = TraitTables.TableCore
    W = Compiled{Fill}
    @test compiled_at(TC.summarize, W) && compiled_at(TC.floats, W) && compiled_at(TC.take, W) &&
          compiled_at(TC.sortperm_col, W)
    # the results are the plain call's: a `Vector{Float64}` column stays one
    @test sortby(t, "f")["x"] isa Vector{Float64} && TC.take(compiled_for([1.5, 2.5]), [2]) isa Vector{Float64}
end
