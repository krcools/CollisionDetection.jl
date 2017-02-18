using CollisionDetection
using FixedSizeArrays
using JLD
using Base.Test

fn = joinpath(@__FILE__,"..","center_sizes.jld")
d = load(fn)
ctrs = d["ctrs"]
rads = d["rads"]

tree = Octree(ctrs, rads)

# extract all the triangles that (potentially) intersect octant (+,+,+)
pred(i) = all(ctrs[i].+rads[i] .> 0)
bb = Vec(0.5, 0.5, 0.5), 0.5
ids = collect(searchtree(pred, tree, bb))

@test length(ids) == 154

# using MATLAB
# A = [c[i] for i in 1:3, c in ctrs].'
# @mput A rads
# @matlab begin
#     plot3(A[:,1],A[:,2],A[:,3],".")
# end
#
# B = [ctrs[j][i] for i in 1:3, j in ids].'
# @mput B
# @matlab begin
#     hold("on")
#     plot3(B[:,1],B[:,2],B[:,3],"or")
# end
