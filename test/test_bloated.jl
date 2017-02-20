#using FixedSizeArrays
CD = CollisionDetection


@test CD.fitsinbox([1,1,1],1.2,[0,0,0],1,2.21) == true
@test CD.fitsinbox([1,1,1],1.2,[0,0,0],1,2.19) == false
@test CD.fitsinbox([-1,-1],1.2,[0,0],1,2.21) == true

d, n = 2, 9
data = SVector{d,Float64}[2*rand(SVector{d,Float64}) for i in 1:n]  # create the list of points for the tree test
push!(data,SVector(2.0,2.0))        # The is the the top right corner
push!(data,SVector(0.0,0.0))        # This is the lower left corner
push!(data, SVector(0.90,0.5))      # This point is at the edgre of sector(0) (-,-)
radii = abs.(zeros(n+2))           # We set raduis for all points to zero to test if they fill in sectors as well
push!(radii,0.2)                  # Now only the test point has a raduis
tree = CD.Octree(data, radii)     # Create an Octree with normal (ratio=1) so that means the point is unmovable to child sector
@test tree.rootbox.data[1]==n+3   # Now we test if the test point is the only unmovable (it should be)
tree = CD.Octree(data, radii,1.2) # We create a new tree but with wider boxes to include points at sectors edge
@test in(n+3,tree.rootbox.children[1].data)==true # now the point should be located at sector zero (+1) of the direct child
push!(data, SVector(0.90,0.5))      # now we add another point but with slightly fatter raduis than the ratio 1.2
push!(radii,0.26)
tree = CD.Octree(data, radii,1.2)
@test in(n+4,tree.rootbox.children[1].data)==false # Now it should go to the child sector
@test tree.rootbox.data[1]==n+4                    # but will be definatly the only one in top level,
