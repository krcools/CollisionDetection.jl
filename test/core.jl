CD = CollisionDetection

@test CD.childsector([1,1,1],[0,0,0]) == 7
@test CD.childsector([-1,1,-1],[0,0,0]) == 2

@test CD.childcentersize([0.,0.,0.], 1., 3) == ([0.5,0.5,-0.5], 0.5)
@test CD.childcentersize([0.,0.,0.], 2., 7) == ([1.0,1.0,1.0], 1.0)

d, n = 3, 200
data = rand(d,n)
radii = abs(rand(n))
tree = CD.Octree(data, radii)

@test length(tree) == n

println("Testing allways true iterator")
sz = 0
for box in CD.boxes(tree)
    sz += length(box.data)
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
    #println("Adding ", length(box.data), " contributions.")
    sz += length(box.data)
end
@show sz
