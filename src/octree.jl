type Octree
    center
    halfsize
    rootbox

    points
    radii

    splitcount
    minhalfsize
end

function Octree(points, radii, splitcount = 10, minhalfsize = zero(eltype(points)))

    n_points = size(points, 2)
    n_dims = size(points, 1)

    # compute the bounding box taking into account
    # the radius of the objects to be inserted
    radius =  maximum(radii)
    ll = fill(minimum(points), n_dims) - radius
    ur = fill(maximum(points), n_dims) + radius

    @show ll, ur

    center = (ll + ur) / 2
    halfsize = ur[1] - center[1]
    @show center

    # if the minimal box size is not specified,
    # make a reasonable guess
    if minhalfsize == 0
        #TODO generalise
        minhalfsize = 0.1 * halfsize * (splitcount / n_points)^(1/3)
    end

    # Create an empty octree
    rootbox = Box()
    tree = Octree(center, halfsize, rootbox, points, radii, splitcount, minhalfsize)

    # populate
    for id in 1:n_points

        point, radius = points[:,id], radii[id]
        insert!(tree, tree.rootbox, center, halfsize, point, radius, id)

    end

    return tree

end


type Box
    data
    children
end

Box() = Box(Int[], Box[])

"""
    childsector(point, center) -> sector

Computes the sector w.r.t. `center` that contains  point. Sector is an Int
that encodes the position of point along each axis in its bit representation
"""
function childsector(point, center)

	sct = 0
	r = point - center
	for (i,x) in enumerate(r)
		if x > zero(x)
			sct |= (1 << (i-1))
		end
	end

	return sct+1 # because Julia has 1-based indexing
end

isleaf(node) = isempty(node.children)

function fitsinbox(pos, radius, center, halfsize)

	for i in 1:length(pos)
		(pos[i] - radius < center[i] - halfsize) && return false
		(pos[i] + radius < center[i] + halfsize) && return false
	end

	return true
end

"""
shiftcenter!(center, halfsize, sector) -> center, halfsize

Computes the center and halfsize of the child of the input box
that resides in octant `sector`
"""
function childcentersize(center, halfsize, sector)
    chd_center = deepcopy(3)
	chd_halfsize =halfsize / 2

	for i in 1 : length(center)
		chd_center[i] += (sector & (1 << (i-1))) == 0 ? -chd_halfsize : +chd_halfsize
	end

	return chd_center, chd_halfsize
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
function insert!(tree, box, center, halfsize, point, radius, id)

    # if not saturated: insert here
    # if saturated and not internal : create children and redistribute
    # if saturated and internal and not fat: insert!(childbox,...)
    # if saturated and internal and fat: insert here

    # or shorter:

    # sat & not internal: create children and redistibute
    # sat & internal & not fat: insert in childbox
    # all other cases: insert here

    saturated = (length(box.data) + 1) > tree.splitcount
    fat       = !fitsinbox(point, radius, center, halfsize)
    internal  = !isleaf(box)

    if !saturated || (saturated && internal && fat)

        push!(box.data, id)

    elseif saturated && internal && !fat

        sct = childsector(point, center)
        chdbox = box.children[sct]
        chdcenter, chdhalfsize = childcentersize!(center, halfsize, sct)
        insert!(tree, chdbox, chdcenter, chdhalfsize, point, radius, id)

    else # saturated && not internal

        # insert the new element in this box for now
        push!(box.data, id)

        # if we are not allowed to subdivide any further stop. This will
        # avoid the contruction of a tree with N levels when N equal points
        # are inserted.
        if halfsize/2 < tree.minhalfsize
            return
        end

        # Create an array of childboxes
        box.children = Array(Box,8) #TODO: generalise the 8 to 2^k
        for i in 1:8
            box.children[i] = Box(Int[], Box[])
        end


        #attempt to subdivde:
        # for point in points in this box
        #   for chbox in childboxes
        #     if fitsinbox(point, radius, center, halfsize)
        #       insert point in chdbox
        #       break
        #     else
        #       add to the list of fat points
        #     end
        #     if saturation relieved, break
        #   end
        # end

        unmovables = Int[]
        for id in box.data

            point = tree.points[id]
            radius = tree.radii[id]

            sct = childsector(point, center)
            chdbox = box.children[sct]
            chdcenter, chdhalfsize = childcentersize!(center, halfsize, sct)
            if fitsinbox(point, radius, chdcenter, chdhalfsize)
                push!(chdbox.data, id)
            else
                push!(unmovables, id)
            end

        end

        box.data = unmovables

    end

end




