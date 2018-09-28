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


N = 100
using DelimitedFiles
buf = readdlm(joinpath(@__DIR__,"assets","ctrs.csv"))
ctrs = vec(collect(reinterpret(SVector{3,Float64}, buf')))
rads = vec(readdlm(joinpath(@__DIR__,"assets","rads.csv")))

tree = CD.Octree(ctrs, rads)
pred(i) = all(ctrs[i] .+ rads[i] .> 0)
bb = @SVector[0.5, 0.5, 0.5], 0.5
ids = collect(CD.searchtree(pred, tree, bb))

@show ids
ids2 = findall(i -> all(ctrs[i]+rads[i] .> 0), 1:N)
@test length(ids2) == length(ids)
@test sort(ids2) == sort(ids)
@test ids == [26, 46, 54, 93, 34, 94, 75, 23, 86, 57, 44, 40, 67, 73, 77, 80]
