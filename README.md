# CollisionDetection

A package for the log(N) retrieval of colliding objects

[![Build Status](https://travis-ci.org/krcools/CollisionDetection.svg?branch=master)](https://travis-ci.org/krcools/CollisionDetection) [![codecov](https://codecov.io/gh/krcools/WiltonInts84.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/krcools/WiltonInts84.jl)


Contains an nd-tree data structure for the storage of objects of finite extent (i.e. not just points). Objects
inserted in the tree will only descend as long as they fit the box they are assigned too. The main purpose of
this tree is to enable logarithmic complexity collision detection. Applications are e.g. the implementation of
graph algorithms, testing if a point is inside a boundary.

Usage

```julia
using CollisionDetection
using StaticArrays

n = 100
centers = 2 .* [rand(SVector{3,Float64}) for i in 1:n] .- 1
radii = [0.1*rand() for i in 1:n]

tree = Octree(centers, radii)
```

To detect colliding objects in a tree, both a bounding box and a collision predicate are required. The bounding box is given by a centre and half the size of the side of the box. The predicate takes an index and returns true or false depending on whether the i-th object stored in the tree collides with the target.

```julia
# Given an index, is the corresponding ball eligible?
pred(i) = all(centers[i].+radii[i] .> 0)
# Bounding box in the (center,halfside) format supplied for effiency
bb = @SVector[0.5, 0.5, 0.5], 0.5
# collect the iterator of admissible indices
ids = collect(searchtree(pred, tree, bb))
```

In this example `ids` will contain the indices of objects touching the (+,+,+) octant.
