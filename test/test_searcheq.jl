#using CollisionDetection
#using StaticArrays
#using JLD2
#using Test

fn = normpath(joinpath(dirname(@__FILE__),"center_sizes.jld2"))
d = JLD2.jldopen(fn,"r")

tmp = d["ctrs"]
ctrs = [SVector(q...) for q in tmp]
rads = d["rads"]

tree = CD.Octree(ctrs, rads)

# extract all the triangles that (potentially) intersect octant (+,+,+)
pred(i) = all(ctrs[i].+rads[i] .> 0)
bb = SVector(0.5, 0.5, 0.5), 0.5
ids = collect(CD.searchtree(pred, tree, bb))
@test length(ids) == 178
