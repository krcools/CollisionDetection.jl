module CollisionDetection

using Compat

export Octree
export boxes, fitsinbox, boudingbox, boxesoverlap
export searchtree


include("octree.jl")
include("searcheq.jl")

end # module
