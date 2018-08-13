module CollisionDetection

using Compat
using LinearAlgebra

export Octree
export boxes, fitsinbox, boudingbox, boxesoverlap
export searchtree, find


include("octree.jl")
include("searcheq.jl")

end # module
