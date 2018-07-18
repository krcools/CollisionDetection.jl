using StaticArrays

module MyPkgTests

using LinearAlgebra
using Test
using StaticArrays
using JLD2
import CollisionDetection

include("test_core.jl")
include("test_bloated.jl")
include("test_searcheq.jl")

end # module
