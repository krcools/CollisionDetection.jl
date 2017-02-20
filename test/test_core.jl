CD = CollisionDetection

@test CD.childsector([1,1,1],[0,0,0]) == 7
@test CD.childsector([-1,1,-1],[0,0,0]) == 2

@test CD.childsector([-1,1,-1,1],[0,0,0,0]) == 10
@test CD.childsector([1,1],[0,0]) == 3

@test CD.childcentersize(SVector(0.,0.,0.), 1., 3) == (SVector(0.5,0.5,-0.5), 0.5)
@test CD.childcentersize(SVector(0.,0.,0.), 2., 7) == (SVector(1.0,1.0,1.0), 1.0)

@test CD.childcentersize(SVector(1.,1.,1.,1.), 2., 9) == (SVector(2.,0.,0.,2.), 1.)

d, n = 3, 200
data = SVector{d,Float64}[rand(SVector{d,Float64}) for i in 1:n]
radii = abs.(rand(n))
tree = CD.Octree(data, radii)

@test length(tree) == n

println("Testing allways true iterator")
sz = 0
for box in CD.boxes(tree)
    sz += length(box)
end
@test sz == n

println("Testing allways false iterator")
sz = 0
for box in CD.boxes(tree, (c,s)->false)
    sz += length(box.data)
end
@test sz == 0

println("Testing query for box in sector [7,0]")
sz = 0
for box in CD.boxes(tree, (c,s)->CD.fitsinbox([1,1,1]/8,0,c,s))
    sz += length(box)
end
@show sz

T = Float64
P = SVector{2,T}
n = 40000
data = P[rand(P) for i in 1:n]
radii = abs(rand(T,n))
tree = CD.Octree(data, radii)

println("Testing allways true iterator [2D]")
sz = 0
for box in CD.boxes(tree)
    sz += length(box)
end
@test sz == n

println("Testing allways false iterator [2D]")
sz = 0
for box in CD.boxes(tree, (c,s)->false)
    sz += length(box.data)
end
@test sz == 0

println("Testing query for box in sector [7,0], [2D]")
sz = 0
for box in CD.boxes(tree, (c,s)->CD.fitsinbox([1,1]/8,0,c,s))
    sz += length(box)
end
@show sz
