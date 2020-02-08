module TestPartiallyTypedTables

import Tables
using DataFrames: DataFrame, DataFrames
using PartiallyTypedTables: partiallytyped
using Test

# Monkey patch!
Tables.rows(df::DataFrames.AbstractDataFrame) = eachrow(df)

@testset begin
    df = DataFrame(a = [1, 3], b = [2.0, 4.0], c = [:a, :b], d = [nothing, nothing])
    @test map(row -> (row.a, row.b), partiallytyped(df, :a)) == [(1, 2), (3, 4)]

    demo(itr) = (first(itr).a, first(itr).b, first(itr).c, first(itr).d)
    @test @inferred(demo(partiallytyped(df, :a, :b, :c, :d))) == (1, 2.0, :a, nothing)
end

end  # module
