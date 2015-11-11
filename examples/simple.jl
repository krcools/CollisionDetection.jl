using Base.Test
reload("CollisionDetection"); CD = CollisionDetection
CD.childsector([-1,-1,-1],[0,0,0])

@test CD.childcentersize!([0.,0.,0.], 1., 3) == ([0.5,0.5,-0.5], 0.5)

Pkg.test("CollisionDetection")