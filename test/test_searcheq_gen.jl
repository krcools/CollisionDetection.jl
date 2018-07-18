# using CollisionDetection
# using CompScienceMeshes
# using JLD2

m = meshsphere(1.0, 0.2)
@show numcells(m)

#centroid(ch) = cartesian(meshpoint(ch, [1,1]/3))

#ctrs = [centroid(simplex(cellvertices(m,i))) for i in 1:numcells(m)]
ctrs = cartesian.(center.(chart.(m,cells(m))))
#rads = [maximum(norm(v-ctrs[i]) for v in cellvertices(m,i)) for i in eachindex(ctrs)]
rads = [maximum(norm(v-ctrs[i]) for v in vertices(m,c)) for (i,c) in enumerate(cells(m))];
tree = Octree(ctrs, rads)

fn = joinpath(@__FILE__,"..","center_sizes.jld2")
JLD2.@save fn ctrs rads
# save(fn,
#     "ctrs", ctrs,
#     "rads", rads)
