# CollisionDetection

A package for the log(N) retrieval of colliding objects

[![Build Status](https://travis-ci.org/krcools/CollisionDetection.svg?branch=master)](https://travis-ci.org/krcools/CollisionDetection)

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

To detect colliding objects in a tree, both a bounding box and a collision predicate are required. The bounding box is given by a centre and half the size of the side of the box. The predicate takes an index and returns true or false depending on whether the i-th object stored in the tree collides with the target.

```julia
pred(i) = all(ctrs[i].+rads[i] .> 0)
bb = SVector(0.5, 0.5, 0.5), 0.5
ids = collect(searchtree(pred, tree, bb))
```

In this example `ids` will contain the indices of objects touching the (+,+,+) octant.
