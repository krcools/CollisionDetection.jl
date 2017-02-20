"""
    searchtree(pred, tree, bb)

Return an iterator that returns indices stores in tree that correspond to objects for which the supplied predicate holds.

`pred` takes an integer an returns true is the corresponding object stores in `tree` collides with the target object. `bb` is a bounding box containing the target. This bounding box is used for effiently excluding entire branches of the tree.
"""
function searchtree(pred, tree::Octree, bb)
    ct, st = bb
    box_pred = (c,s) ->  boxesoverlap(c, s, ct, st)
    box_it = boxes(tree, box_pred)
    Compat.Iterators.filter(pred, Compat.Iterators.flatten(box_it))
end
