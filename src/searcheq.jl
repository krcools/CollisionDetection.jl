@inline function _overlapsbounds(lower, upper, querylower, queryupper)
    @inbounds for d in eachindex(querylower)
        lower[d] <= queryupper[d] || return false
        upper[d] >= querylower[d] || return false
    end
    return true
end

"""
    searchtree(pred, tree, bb)

Return an iterator over indices stored in `tree` for which the supplied
predicate holds.

`pred` receives an integer index and returns `true` when the corresponding
object should be included. `bb` is the query bounding box; it is used to
exclude non-overlapping branches and object bounds before evaluating `pred`.

The query bounds are a filter, not merely a hint.
"""
function searchtree(pred, tree::Octree, bb)
    ct, st = bb
    box_pred = (c,s) ->  boxesoverlap(c, s * tree.expanding_ratio, ct, st)
    box_it = boxes(tree, box_pred)
    query_lower = ct .- st
    query_upper = ct .+ st
    candidate_it = Compat.Iterators.flatten(box_it)
    Compat.Iterators.filter(candidate_it) do id
        _overlapsbounds(tree.lowers[id], tree.uppers[id], query_lower, query_upper) &&
            pred(id)
    end
end

struct SearchTreeVisitor{T,P,F,C,S,L,U}
    tree::T
    predicate::P
    callback::F
    querycenter::C
    queryst::S
    querylower::L
    queryupper::U
end

function (visitor::SearchTreeVisitor)(id)
    visitor.predicate(id) || return false
    return visitor.callback(id) === true
end

struct CombinedSearchTreeVisitor{T,F,C,S,L,U}
    tree::T
    callback::F
    querycenter::C
    queryst::S
    querylower::L
    queryupper::U
end

function (visitor::CombinedSearchTreeVisitor)(id)
    return visitor.callback(id) === true
end

function _visitsearchtree!(visitor::V, box, center, halfsize) where {V}
    boxesoverlap(
        center,
        halfsize * visitor.tree.expanding_ratio,
        visitor.querycenter,
        visitor.queryst,
    ) || return false

    for id in box.data
        _overlapsbounds(
            visitor.tree.lowers[id],
            visitor.tree.uppers[id],
            visitor.querylower,
            visitor.queryupper,
        ) && visitor(id) && return true
    end

    for sector in 0:(length(box.children) - 1)
        childcenter, childhalfsize = childcentersize(center, halfsize, sector)
        _visitsearchtree!(
            visitor,
            box.children[sector + 1],
            childcenter,
            childhalfsize,
        ) && return true
    end
    return false
end

"""
    foreachsearchtree(f, tree, bb, pred) -> stopped

Apply `f` to every stored object whose bounds intersect `bb` and for which
`pred` returns `true`. Return `true` when `f` returns `true` and traversal
stops; otherwise return `false` after exhausting the search.

The callback must return the singleton `true` to stop traversal; other truthy
values are treated as `false`. With a `do` block, the callback comes first:
`foreachsearchtree(tree, bb, pred) do id ... end`.
"""
function foreachsearchtree(f, tree::Octree, bb, pred)
    ct, st = bb
    visitor = SearchTreeVisitor(tree, pred, f, ct, st, ct .- st, ct .+ st)
    return _visitsearchtree!(visitor, tree.rootbox, tree.center, tree.halfsize)
end

"""
    foreachsearchtree(visitor, tree, bb) -> stopped

Apply `visitor` to every stored object whose bounds intersect `bb`.
The visitor may perform object-level filtering and processing; return the
singleton `true` to stop traversal early. Other truthy values are treated as
`false`. Return `false` when traversal is exhausted.
"""
function foreachsearchtree(visitor, tree::Octree, bb)
    ct, st = bb
    state = CombinedSearchTreeVisitor(tree, visitor, ct, st, ct .- st, ct .+ st)
    return _visitsearchtree!(state, tree.rootbox, tree.center, tree.halfsize)
end

"""
    anysearchtree(pred, tree, bb) -> Bool

Return `true` when at least one stored object whose bounds intersect `bb`
is accepted by `pred`. Stop traversal after the first accepted object.
"""
function anysearchtree(pred, tree::Octree, bb)
    return foreachsearchtree(tree, bb, pred) do _
        true
    end
end
