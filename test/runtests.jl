module MyPkgTests

using Base.Test
using ImmutableArrays

import CollisionDetection
CD = CollisionDetection


@test CD.childsector([1,1,1],[0,0,0]) == 7
@test CD.childsector([-1,1,-1],[0,0,0]) == 2

@test CD.childcentersize!([0.,0.,0.], 1., 3) == ([0.5,0.5,-0.5], 0.5)
@test CD.childcentersize!([0.,0.,0.], 2., 7) == ([1.0,1.0,1.0], 1.0)

end
