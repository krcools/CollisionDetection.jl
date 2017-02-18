module MyPkgTests

using Base.Test
#using ImmutableArrays

import CollisionDetection

include("core.jl")
include("core2.jl")
include("test_searcheq.jl")

end # module
