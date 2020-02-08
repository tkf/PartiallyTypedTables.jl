module PartiallyTypedTables

import Tables
using ArgCheck: @argcheck

_typed(x) = getfield(x, :typed)
_rest(x) = getfield(x, :rest)

struct PartiallyTypedRowIterator{names,types,Typed<:NamedTuple{names,types},Rest}
    typed::Typed
    rest::Rest
end

_zip(tuples::NTuple{N,Any}...) where {N} = ntuple(i -> map(t -> t[i], tuples), N)

# Convince `julia` that all arguments are non-`nothing` when passed through:
@inline allsomethings(xs...) = _allsomethings((), xs...)
@inline _allsomethings(ys) = ys
# @inline _allsomethings(_, ::Nothing, xs...) = nothing
@inline function _allsomethings(ys, x, xs...)
    x === nothing && return nothing
    return _allsomethings((ys..., x), xs...)
end

_value(::Val{x}) where {x} = x

function Base.iterate(itr::PartiallyTypedRowIterator{names}, prev = nothing) where {names}
    if prev === nothing
        ys0 = map(iterate, Tuple(_typed(itr)))
        y = iterate(_rest(itr))
    else
        (typed_states, rest_state) = prev
        ys0 = map(iterate, Tuple(_typed(itr)), typed_states)
        y = iterate(_rest(itr), rest_state)
    end
    ys = allsomethings(ys0...)
    ys === nothing && return nothing
    y === nothing && return nothing
    typed = foldl(_zip(map(Val, names), ys); init = NamedTuple()) do typed, (name, (x, _))
        merge(typed, (; _value(name) => x))
    end
    state = (map(last, ys), y[2])
    return PartiallyTypedRow(typed, y[1]), state
end

eltypes(::Type{Tuple{}}) = Tuple{}
eltypes(::Type{T}) where {H,T<:Tuple{H,Vararg{Any}}} =
    Base.tuple_type_cons(eltype(H), eltypes(Base.tuple_type_tail(T)))

function Base.eltype(
    ::Type{PartiallyTypedRowIterator{names,types,Typed,Rest}},
) where {names,types,Typed,Rest}
    rtypes = eltypes(types)
    r = eltype(Rest)
    if isconcretetype(r)
        return PartiallyTypedRow{names,rtypes,NamedTuple{names,rtypes},r}
    else
        return PartiallyTypedRow{names,rtypes,NamedTuple{names,rtypes},<:r}
    end
end

Base.IteratorEltype(
    ::Type{PartiallyTypedRowIterator{names,types,Typed,Rest}},
) where {names,types,Typed,Rest} = Base.HasEltype()

Base.length(itr::PartiallyTypedRowIterator) = length(_rest(itr))

Base.IteratorSize(
    ::Type{PartiallyTypedRowIterator{names,types,Typed,Rest}},
) where {names,types,Typed,Rest} = Base.HasLength()
# TODO: "merge" `typed`

struct PartiallyTypedRow{names,types,Typed<:NamedTuple{names,types},Rest}
    typed::Typed
    rest::Rest
end

function Base.getproperty(row::PartiallyTypedRow, name::Symbol)
    haskey(_typed(row), name) && return _typed(row)[name]
    return getproperty(_rest(row), name)
end

function partiallytyped(table, names::Symbol...)
    @argcheck Tables.rowaccess(table)
    @argcheck Tables.columnaccess(table)
    columns = Tables.columns(table)
    return PartiallyTypedRowIterator(
        (; (n => getproperty(columns, n) for n in names)...),
        Tables.rows(table),
    )
end

end # module
