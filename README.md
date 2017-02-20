# CollisionDetection

Contains an nd-tree data structure for the storage of objects of finite extent (i.e. not just points). Objects
inserted in the tree will only descend as long as they fit the box they are assigned too. The main purpose of
this tree is to enable logarithmic complexity collision detection. Applications are e.g. the implementation of
graph algorithms, testing if a point is inside a boundary.

Usage

```julia
using CollisionDetection
using FixedSizeArrays

n = 100
p = [Vec(rand(),rand(),rand()) for i in 1:n]
r = [0.1*rand() for i in 1:n]

tree = Octree(p,r)
```
