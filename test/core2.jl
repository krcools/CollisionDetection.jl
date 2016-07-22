using FixedSizeArrays
CD = CollisionDetection


@test CD.fitsinbox([1,1,1],1.2,[0,0,0],1,2.21) == true
@test CD.fitsinbox([1,1,1],1.2,[0,0,0],1,2.19) == false
@test CD.fitsinbox([-1,-1],1.2,[0,0],1,2.21) == true
