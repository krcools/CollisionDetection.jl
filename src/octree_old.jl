using DataStructures

type Leaf{VT,PT,SZ}
	position::PT
	radius::ST
	value::VT
end

type Box{ValueType, PointType, SizeType}
	sector::Int
	children::LinkedList{Box{ValueType,PointType,SizeType}}
	leafs::LinkedList{Leaf{ValueType,PointType,SizeType}}
end

type Octree{ValueType, PointType, SizeType}
	root::Box{ValueType, PointType, SizeType}
	size::SizeType
	center::PointType
end

type TreeIteratorState{VT,PT,ST}

	center::PT
	size::ST

	next_value::LinkedList{Leaf{VT,PT,ST}}
	next_sibling::LinkedList{Box{VT,PT,ST}}
	next_child::LinkedList{Box{VT,PT,ST}}

	prev_state::TreeIteratorState{VT,PT,ST}

end

type TreeIterator{PredicateType, VT, PT, ST}

	p::PredicateType
	state::TreeIteratorState{VT,PT,ST}

end




function insert(tree, point, radius, value)

	center, size, box = tree.center, tree.size, tree.box

	# find the box in which to inserrt
	box, center, size, fat = findbox(point, radius, box, center, size)

	# add a leaf to this box
	box.leafs = cons(Leaf(point, radius, value), box.leafs)

	# if the newly inserted object is fat, no point in subdividing
	fat && return

	subdivide!(box, center, size)

end

import Base.eltype
eltype{T}(::LinkedList{T}) = T

function subdivide!{ValueType, PointType, SizeType}(
	box::Box{ValueType, PointType, SizeType},
	center, size, maxnvals)

	# if there are only a few elements in this box, return
	nvals = length(box.leafs)
	(nvals <= maxnvals) && return

	# if all elements in this box are the same, return
	pos = first(box.leafs).position
	all_equal = true
	for leaf in box.leafs
		if pos != leaf.position
			all_equal = false
			break
		end
	end
	all_equal && return

	dim = length(center)
	nsubs = 2^dim

	tot_num_skinnies = 0
	num_skinnies = zeros(Int, nsubs)

	fatties = nil(ValueType)
	groups = fill(nil(ValueType), nchds)

	for leaf in box.leafs
		sct, fits = findsector(leaf, center, size)

		if fits
			# bookkeeping
			tot_num_skinnies += 1
			num_skinnies[sector] += 1

			# add leaf to the correct child box
			groups[sct] = cons(groups[sct], leaf)

		else

			fatties = cons(leaf, fatties)
		end
	end

	# do the actual subdividing
	for (sct, group) in enumerate(groups)

		it, exists = findbox(box.children, sct)

		if exists
			chd, it = next(box.children, it)
		else
			chd = Box(sct, nil(), nil())
		end

		for leaf in group
			chd




end


function update_center_and_size(sector, center, size)

	chd_size = size / 2;

	for i in 1 : length(center)
		center[i] += (sector & (1 << (i-1))) ? chd_size/2 : -chd_size/2
	end

	return center, size/2
end


findbox(boxlist, sct) = findfirst(x -> x.sector = sct, boxlist)

# find the (box,center,size) where to store (pos,radius). The fourth value
# in the returned tuple is false when the search ended because the object
# was too large to fit in a smaller box, and true otherwise
function findbox(octree, pos, radius, box, center, size)

	while true

		sct = sector(pos, center)
		it, found = findfirst(b -> b.sector == sct, box.children)

		if !found
			return box, center, size, true
		end

		chd_box, it = next(box.children, it)
		chd_center, chd_size = update_center_and_size(sct, center, size)

		# check for fatness
		if !fitsinbox(pos, radius, center, size)
			return box, center, size, false
		end

		# child box exist and object not fat: rinse & repeat!
		center, size, box = chd_center, chd_size, chd_box
	end

	return box, center, size, fat

end


function findsector(node, center, size)

	pos, radius = node.position, node.radius

	sct = sector(node.position, center)
	center, size = update_center_and_size(sct, center, size)
	fits = fitsinbox(pos, radius, center, size)

	return sct, fits
end


function sector(point, center)

	sct = 0
	r = point - center
	for (i,x) in enumerate(r)
		if x > zero(x)
			sct |= (1 << (i-1))
		end
	end

	return sct
end

function fitsinbox(pos, radius, center, size)

	for i in 1:length(pos)
		(pos[i] - radius < center[i] - size/2) && return false
		(pos[i] + radius < center[i] + size/2) && return false
	end

	return true
end
