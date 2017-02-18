module CollisionDetection

export Octree
export boxes, fitsinbox, boudingbox, boxesoverlap
#export childcentersize
export searchtree


include("octree.jl")
include("searcheq.jl")

end # module
