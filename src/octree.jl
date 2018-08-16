    
mutable struct Box
    data::Vector{Int}
    children::Vector{Box}
end

Box() = Box(Int[], Box[])

"""
T: type of the coordinates
P: type of the points stored in the Octree.
"""
mutable struct Octree{T,P}
    center::P
    halfsize::T
    rootbox::Box

    points::Vector{P}
    radii::Vector{T}
    expanding_ratio::Float64 # This will add the expanding ratio of boxes

    splitcount::Int
    minhalfsize::T
end

"""
  boundingbox(v)

Compute the bounding cube/square for a Array of Point. The return values
are the center of the bounding box and the half size of the cube.
"""
function boundingbox(v::Vector{P}) where {P}
  #P are points values (x,y) in 2D or (x,y,z) in 3D
  ll = minimum(v)
  ur = maximum(v)
  #ll => LowerLeft
  #up => UpperRight
  c = (ll + ur)/2
  s = maximum(ur - c)
  #c => centre
  #s => biggest half width, i.e in 2D distance between points result in a rectangular
  #    (so we pick the bigger value here to form a rectangular later)
  return c, s
end


"""
Predicate used for iteration over an Octree. Returns true if two boxes
specified by their centers and halfsizes overlap. More carefull investigation
of the objects within is required to assess collision. False positives are possible.

    boxesoverlap(c1, hs1, c2, hs2)
"""
function boxesoverlap(c1, hs1, c2, hs2)

    tol = sqrt(eps(typeof(hs1)))
    # Checking the type of the problem domain 2D or 3D? and making sure the boxes are from same domain
    dim = length(c1)
    @assert dim == length(c2)
    #Note: I have fixed the condition, now it works for 3D and 2D
    hs = hs1 + hs2
    for i in 1 : dim
        if abs(c1[i] - c2[i]) > hs + tol
            return false
        end
    end

    return true
end

function Octree(points::Vector, radii::Vector{T}, expanding_ratio=1.0, splitcount = 10,  minhalfsize = zero(T)) where {T}

    n_points = length(points)
    n_dims = length(eltype(points))

    # compute the bounding box taking into account
    # the radius of the objects to be inserted
    radius =  maximum(radii)

	@assert !isempty(points)
	ll = points[1]
	ur = points[1]
	for i in 2:length(points)
		ll = min.(ll, points[i])
		ur = max.(ur, points[i])
	end

	ll = ll .- radius
	ur = ur .+ radius

    #ll = minimum(points) - radius
    #ur = maximum(points) + radius

    center = (ll + ur) / 2
    halfsize = maximum(ur - center)

    # if the minimal box size is not specified,
    # make a reasonable guess
    if minhalfsize == 0
        #TODO generalise
        minhalfsize = 0.1 * halfsize * (splitcount / n_points)^(1/3)
    end

    # Create an empty octree
    rootbox = Box()
    tree = Octree(center, halfsize, rootbox, points, radii, expanding_ratio, splitcount, minhalfsize)

    # populate
    for id in 1:n_points

        point, radius = points[id], radii[id]
        insert!(tree, tree.rootbox, center, halfsize, point, radius, id)

    end

    return tree

end

"""
  Octree(points)

Insert zero radius objects at positions `points` in an Octree
"""
Octree(points) = Octree(points, zeros(eltype(eltype(points)), length(points)))



"""
    childsector(point, center) -> sector

Computes the sector w.r.t. `center` that contains  point. Sector is an Int
that encodes the position of point along each axis in its bit representation
"""
function childsector(point, center)
  # in Case of 3D the Octant they are numbered as follows (+,+,+)->7, (+,+,-)->3, (+,-,+)->5, (+,-,-)->1
  #(-,+,+)->6, (-,+,-)->2, (-,-,+)->4, (-,-,-)->0
  #For 2D (-,-)->0, (-,+)->1, (+,-)->2, (+,+)->3
	sct = 0
	r = point - center
	for (i,x) in enumerate(r)
		if x > zero(x)
			sct |= (1 << (i-1))
		end
	end

	return sct # because Julia has 1-based indexing
end

isleaf(node) = isempty(node.children)


"""
    fitsinbox(pos, radius, center, halfsize) -> true/fasle

Finds out if the object with position (pos) and (raduis) fits inside the box.
It uses the box dimension (centre, and halfsize(w/2)) to do the comparsion
"""
function fitsinbox(pos, radius, center, halfsize)

	for i in 1:length(pos)
		(pos[i] - radius < center[i] - halfsize) && return false
		(pos[i] + radius > center[i] + halfsize) && return false
	end
# the code judege by comapring with the box lower left point and uper right point
	return true
end
"""
  itsinbox(Opj_c, Obj_rad, box_c, box_hf, ratio) -> true/fasle

  Finds out if the object with center position (Opj_c) and (Obj_rad) fits inside the box.
  It uses the box dimension (box_c, and box_hf(w/2)) to do the comparsion
  ratio is relative to box half width, so if you want to be just within the box
  then ratio =1, if the boundaries of the object is slightly bigger and you still
  want to include them make ratio bigger ex:1.2
"""
function fitsinbox(Opj_c, Obj_rad, box_c, box_hf, ratio)
  for i in 1:length(Opj_c)
		(Opj_c[i] - Obj_rad < box_c[i] - (box_hf*ratio)) && return false
		(Opj_c[i] + Obj_rad > box_c[i] + (box_hf*ratio)) && return false
	end
# the code judege by comapring with the box lower left point and uper right point
	return true

end





"""
  childcentersize(center, halfsize, sector) -> center, halfsize

Computes the center and halfsize of the child of the input box
that resides in octant `sector`
"""
@generated function childcentersize(center, halfsize, sector)
  D = length(center)
  xp1 = :(halfsize = halfsize / 2)
  xp2 = Expr(:call, center)
  for d in 1:D
    push!(xp2.args, :(center[$d] + (sector & (1 << $(d-1)) == 0 ? -halfsize : +halfsize)))
  end
  xp = quote
    $xp1
    return $xp2, halfsize
  end
  #@show xp
  #xp
end



"""
insert!(tree, box, center, halfsize, point, radius, id)

tree:     the tree in which to insert
box:      the box in which to try insertion
center:   center of the box
halfsize: 0.5 times the length of the box side
point:    the point at which to insert
radius:   the radius of the item to insert
id:       a unique id that identifies the inserted item uniquely
"""
function insert!(tree, box, center::P, halfsize::T, point::P, radius::T, id) where {T,P}

    # if not saturated: insert here
    # if saturated and not internal : create children and redistribute
    # if saturated and internal and not fat: insert!(childbox,...)
    # if saturated and internal and fat: insert here
    # also if not saturated but there are non empty internal boxes try to insert there not here

    # or shorter:

    # sat & not internal: create children and redistibute
    # sat & internal & not fat: insert in childbox
    # all other cases: insert here
    # Will find out first if we are solveing octree or quadtree 3D/2D
    dim = length(P)
    nch = 2^dim
    expanding_ratio=tree.expanding_ratio

    saturated = (length(box.data) + 1) > tree.splitcount
    fat       = !fitsinbox(point, radius, center, halfsize,expanding_ratio) # we test if the point is within the box and the expanswion if there is any
    internal  = !isleaf(box)

    if (!internal && !saturated) || (saturated && internal && fat)
        # this will only insert in top level in two cases
        # 1) the object is fat anyway
        # 2) there is no child boxes and still there is a place in this box ( it is not saturated)
        push!(box.data, id)

    elseif internal && !fat
        # now if the box has a space or not but it has a childern try to insert in the child not here
        sct = childsector(point, center)
        chdbox = box.children[sct+1]
        chdcenter, chdhalfsize = childcentersize(center, halfsize, sct)
        if fitsinbox(point, radius, chdcenter, chdhalfsize,expanding_ratio) # check if it is fat and please consider the expansion
          insert!(tree, chdbox, chdcenter, chdhalfsize, point, radius, id)
        else
          push!(box.data, id)
        end



    else # saturated && not internal

        # if their was a previous attempt to subdivide this box,

        # insert the new element in this box for now as we will sort them after we create childrens
        push!(box.data, id)

        # if we are not allowed to subdivide any further stop. This will
        # avoid the contruction of a tree with N levels when N equal points
        # are inserted.
        if halfsize/2 < tree.minhalfsize
            return
        end

        # Create an array of childboxes
        box.children = Array{Box}(undef,nch)
        for i in 1:nch
            box.children[i] = Box(Int[], Box[])
        end


        # subdivide:
        # for every id in this box
        #   find the correspdoning child sector
        #   if it fits in the child box, insert
        #   if not, add to the list of unmovables
        # replace the current box data with the list of unmovables

        unmovables = Int[]
        for id in box.data

            point = tree.points[id]
            radius = tree.radii[id]

            sct = childsector(point, center)
            chdbox = box.children[sct+1]
            chdcenter, chdhalfsize = childcentersize(center, halfsize, sct)
            if fitsinbox(point, radius, chdcenter, chdhalfsize,expanding_ratio)# # check if it is fat for the child and please consider the expansion
                push!(chdbox.data, id)
            else
                push!(unmovables, id)
            end

        end

        box.data = unmovables

    end

end

import Base.length
function length(tree::Octree)

    # Traversal order:
    #   data in the box
    #   data in all children
    #   data in the sibilings
    level = 0

    box = tree.rootbox
    sz = length(box.data)

    box_stack = [tree.rootbox]
    sct_stack = [1]

    sz = -0

    box = tree.rootbox
    sct = 0

    box_stack = Box[]
    sct_stack = Int[]

    while true

        # if this is the first time the box is visited, count the data
        if sct == 0
            sz += length(box.data)
            if length(box.data) != 0
                println("Adding ", length(box.data), " contributions at level: ", level)
            end
        end

        # if this box has unprocessed children
        # push this box on the stack and process the children
        if sct < length(box.children)
            push!(box_stack, box)
            push!(sct_stack, sct+1)
            level += 1

            box = box.children[sct+1]
            sct = 0

            continue
        end

        # if box and its children are processed,
        # and their is no parent above this box:
        # end the traversal:
        if isempty(box_stack)
            break
        end

        # if either no children or all children processed:
        # move up one level
        box = pop!(box_stack)
        sct = pop!(sct_stack)
        level -= 1

    end

    return sz

end


mutable struct BoxIterator{T,P,F}
    predicate::F
    tree::Octree{T,P}
end

Base.IteratorSize(::BoxIterator) = Base.SizeUnknown()

mutable struct BoxIteratorStage{T,P}
    box::Box
    sct::Int
    center::P
    halfsize::T
end

boxes(tree::Octree, pred = (ctr,hsz)->true) = BoxIterator(pred, tree)

"""
    advance(it, state)

Moves `state` ahead to point at either the next valid position or one-off-end.
"""
function advance(bi::BoxIterator, state)

    pred = bi.predicate

    box = last(state).box
    sct = last(state).sct
    hsz = last(state).halfsize
    ctr = last(state).center

    while true

        # scan for a next child box that meets the criterium
        childbox_found = false
        while sct < length(box.children)
            chd_ctr, chd_hsz = childcentersize(ctr, hsz, sct)
            if bi.predicate(chd_ctr, chd_hsz)
                childbox_found = true
                break
            end
            sct += 1
        end

        if childbox_found

            # if this box has unvisited children, increment
            # the next child sct counter and move down the tree
            last(state).sct = sct + 1
            ctr, hsz = childcentersize(ctr, hsz, sct)
            stage = BoxIteratorStage(box.children[sct+1], 0, ctr, hsz)
            push!(state, stage)

        else

            pop!(state)

        end

        # if we popped the root, we're finished
        if isempty(state)
            break
        end

        box = last(state).box
        sct = last(state).sct
        hsz = last(state).halfsize
        ctr = last(state).center

        # only stop the iteration when a new box is found
        # and if that box is non-empty
        # (sct == 0) implies that this is the first visit
        if sct == 0 && !isempty(box.data)
            break
        end
    end

    return state
end

function Base.iterate(bi::BoxIterator)

    state = [ BoxIteratorStage(
        bi.tree.rootbox, 0, bi.tree.center, bi.tree.halfsize
    ) ]

    if !bi.predicate( bi.tree.center, bi.tree.halfsize)
        state = advance(bi, state)
    end

    # at this point state will be either empty or valid
    @assert isempty(state) || bi.predicate(last(state).center, last(state).halfsize)

    iterate(bi, state)
end

function Base.iterate(bi::BoxIterator, state)

    isempty(state) && return nothing

    return last(state).box.data, advance(bi, state)
end

"""
    find(octree, pos, tolerance=sqrt(eps(eltype(pos))))

Return an array containing the indices of values at `pos` (up to a tolerance)
"""
function find(tr::Octree, v; tol = sqrt(eps(eltype(v))))

    pred = (c,s) -> fitsinbox(v, 0.0, c, s)# i didn't change it because find will get the point anyway, it only chck for its existance
    I = Int[]
    for b in boxes(tr, pred)
      for i in b
        if norm(tr.points[i] - v) < tol
          push!(I, i)
        end
      end
    end

    return I

end
