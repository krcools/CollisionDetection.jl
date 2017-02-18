using CollisionDetection
using CompScienceMeshes
using JLD

m = meshsphere(1.0, 0.2)
@show numcells(m)

centroid(ch) = cartesian(meshpoint(ch, [1,1]/3))

ctrs = [centroid(simplex(cellvertices(m,i))) for i in 1:numcells(m)]
rads = [maximum(norm(v-ctrs[i]) for v in cellvertices(m,i)) for i in eachindex(ctrs)]
tree = Octree(ctrs, rads)

fn = joinpath(@__FILE__,"..","center_sizes.jld")
save(fn,
    "ctrs", ctrs,
    "rads", rads)
