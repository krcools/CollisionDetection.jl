module MyPkgTests

using Base.Test
using FixedSizeArrays
import CollisionDetection

include("test_core.jl")
include("test_bloated.jl")
include("test_searcheq.jl")

end # module
