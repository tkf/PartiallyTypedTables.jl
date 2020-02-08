using BenchmarkTools
using DataFrames
using PartiallyTypedTables: partiallytyped
using Tables

# Monkey patch!
Tables.rows(df::DataFrames.AbstractDataFrame) = eachrow(df)

function filtered_sum(rows)
    s = 0.0
    for r in rows
        if r.a > 3
            s += r.b
        end
    end
    return s
end

SUITE = BenchmarkGroup()

n = 1_000_000
df = DataFrame(a = randn(n), b = randn(n))

SUITE["none"] = @benchmarkable filtered_sum($(eachrow(df)))
SUITE["partial"] = @benchmarkable filtered_sum($(partiallytyped(df, :a)))
SUITE["full"] = @benchmarkable filtered_sum($(Tables.rows(DataFrames.columntable(df))))
