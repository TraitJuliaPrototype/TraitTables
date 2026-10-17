using Test, TraitTables, TraitWorld

# a column type of the user's own: a constant column, conforming by its own methods
struct Fill; x::Float64; n::Int; end
TraitTables.nrows(f::Fill) = f.n
TraitTables.cell(f::Fill, i::Int) = f.x
@implement Column Fill

@testset "TraitTables" begin
    t = TraitTables.table("x" => [0.5, 1.5, 2.5], "n" => [3, 1, 2], "s" => ["b", "a", "c"])
    @test size(t) == (3, 3) && colnames(t) == ["x", "n", "s"]
    @test t.cols isa Vector{Dynamic{Column}}
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
