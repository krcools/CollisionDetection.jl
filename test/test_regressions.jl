using Test
using Random
using StaticArrays

function stored_ids(tree)
    ids = Int[]
    for box in CD.boxes(tree)
        append!(ids, box)
    end
    ids
end

@testset "octree primitive boundaries" begin
    c = @SVector [0.0, 0.0, 0.0]
    @test CD.boxesoverlap(c, 1.0, @SVector([2.0, 0.0, 0.0]), 1.0)
    @test !CD.boxesoverlap(c, 1.0, @SVector([2.1, 0.0, 0.0]), 1.0)
    @test CD.fitsinbox(@SVector([0.0, 0.0]), 1.0, @SVector([0.0, 0.0]), 1.0)
    @test !CD.fitsinbox(@SVector([0.0, 0.0]), 1.01, @SVector([0.0, 0.0]), 1.0)
    @test CD.fitsinbox(@SVector([0.0, 0.0]), 1.1, @SVector([0.0, 0.0]), 1.0, 1.1)
    @test CD.childcentersize(@SVector([0.0, 0.0]), 2.0, 3) ==
        (@SVector([1.0, 1.0]), 1.0)
end

@testset "octree storage invariants" begin
    points = [@SVector([Float64(x), Float64(y), Float64(z)])
              for x in -2:2, y in -2:2, z in -2:2]
    points = vec(points)
    radii = [isodd(i) ? 0.0 : 0.15 for i in eachindex(points)]
    tree = CD.Octree(points, radii, 1.1, 4)
    ids = stored_ids(tree)
    @test length(tree) == length(points)
    @test sort(ids) == collect(1:length(points))

    # Coincident objects cannot be separated by spatial subdivision. They
    # must remain in a box, once each, rather than causing unbounded splitting.
    coincident = CD.Octree(fill(@SVector([0.0, 0.0]), 32), zeros(32), 1.1, 4)
    @test sort(stored_ids(coincident)) == collect(1:32)
end

@testset "object bounds are respected during subdivision" begin
    points = [@SVector([0.0, 0.0]), @SVector([1.0, 0.0])]
    radii = [0.6, 0.0]
    tree = CD.Octree(points, radii, 1.1, 1)

    # The first object's bounding box protrudes across the child boundary. It must
    # remain searchable even though its center belongs to only one child.
    found = collect(CD.searchtree(_ -> true, tree, (@SVector([0.5, 0.0]), 0.05)))
    @test found == [1]
end

@testset "search APIs agree with brute force" begin
    points = [@SVector([Float64(x), Float64(y), Float64(z)])
              for x in -4:4, y in -3:3, z in -2:2]
    points = vec(points)
    radii = [0.05 + 0.02 * mod(i, 4) for i in eachindex(points)]
    tree = CD.Octree(points, radii, 1.1, 6)

    queries = (
        (@SVector([0.0, 0.0, 0.0]), 0.4),
        (@SVector([2.0, -1.0, 0.5]), 0.75),
        (@SVector([20.0, 20.0, 20.0]), 0.1),
    )

    for (center, halfsize) in queries
        bb = (center, halfsize)
        expected = [i for i in eachindex(points)
                          if CD._overlapsbounds(points[i] .- radii[i], points[i] .+ radii[i],
            center .- halfsize, center .+ halfsize)]
        pred(i) = iseven(i) || points[i][1] < 0
        expected = filter(pred, expected)

        found = collect(CD.searchtree(pred, tree, bb))
        visited = Int[]
        CD.foreachsearchtree(tree, bb) do i
            pred(i) && push!(visited, i)
            false
        end
        @test sort(found) == sort(expected)
        @test sort(visited) == sort(expected)
        @test CD.anysearchtree(pred, tree, bb) == !isempty(expected)
    end
end

@testset "search visitor early termination" begin
    points = [@SVector([Float64(x), 0.0]) for x in 1:20]
    tree = CD.Octree(points, zeros(20), 1.1, 3)
    seen = Ref(0)
    stopped = CD.foreachsearchtree(tree, (@SVector([10.0, 0.0]), 20.0)) do _
        seen[] += 1
        true
    end
    @test stopped
    @test seen[] == 1
end

function brute_force_ids(points, radii, center, halfsize, pred)
    querylower = center .- halfsize
    queryupper = center .+ halfsize
    [i for i in eachindex(points)
           if CD._overlapsbounds(
        points[i] .- radii[i],
        points[i] .+ radii[i],
        querylower,
        queryupper,
    ) && pred(i)]
end

@testset "randomized search agrees with brute force" begin
    rng = MersenneTwister(0xC0111D)

    for dimension in (2, 3)
        point_type = dimension == 2 ? SVector{2,Float64} : SVector{3,Float64}
        points = [point_type(rand(rng, dimension) .* 2 .- 1) for _ in 1:1000]
        radii = rand(rng, 1000) .* 0.08

        # Include cases that random sampling rarely produces reliably.
        append!(points, [zero(point_type), zero(point_type), point_type(ones(dimension))])
        append!(radii, [0.0, 0.25, 0.0])

        for (splitcount, expansion_ratio) in ((4, 1.0), (8, 1.1), (16, 1.25))
            tree = CD.Octree(points, radii, expansion_ratio, splitcount)
            for _ in 1:40
                center = point_type(rand(rng, dimension) .* 3 .- 1.5)
                halfsize = rand(rng) .* 0.5
                bb = (center, halfsize)
                pred = i -> iszero(mod(i, 5)) || points[i][1] < -0.2
                expected = brute_force_ids(points, radii, center, halfsize, pred)

                found = collect(CD.searchtree(pred, tree, bb))
                visited = Int[]
                CD.foreachsearchtree(tree, bb) do id
                    pred(id) && push!(visited, id)
                    false
                end

                @test sort(found) == sort(expected)
                @test sort(visited) == sort(expected)
                @test CD.anysearchtree(pred, tree, bb) == !isempty(expected)
            end
        end
    end
end

@testset "Float32 search agrees with brute force" begin
    rng = MersenneTwister(0xF032)
    point_type = SVector{3,Float32}
    points = [point_type(rand(rng, Float32, 3) .* 2f0 .- 1f0)
              for _ in 1:3000]
    radii = rand(rng, Float32, 3000) .* 0.08f0
    tree = CD.Octree(points, radii, 1.1, 16)

    for _ in 1:300
        center = point_type(rand(rng, Float32, 3) .* 3f0 .- 1.5f0)
        halfsize = rand(rng, Float32) * 0.5f0
        expected = brute_force_ids(points, radii, center, halfsize, _ -> true)
        found = collect(CD.searchtree(_ -> true, tree, (center, halfsize)))
        @test sort(found) == sort(expected)
    end
end

@testset "targeted query bounds" begin
    points = [
        @SVector([-1.0, -1.0, -1.0]),
        @SVector([1.0, 1.0, 1.0]),
        @SVector([0.0, 0.0, 0.0]),
    ]
    radii = [0.0, 0.0, 0.5]
    tree = CD.Octree(points, radii, 1.1, 1)

    queries = (
        (@SVector([0.0, 0.0, 0.0]), 0.0),
        (@SVector([0.5, 0.5, 0.5]), 0.0),
        (@SVector([0.0, 0.0, 0.0]), 0.5),
        (@SVector([10.0, 10.0, 10.0]), 0.0),
    )
    for (center, halfsize) in queries
        expected = brute_force_ids(points, radii, center, halfsize, _ -> true)
        @test sort(collect(CD.searchtree(_ -> true, tree, (center, halfsize)))) ==
            sort(expected)
    end
end

@testset "default tree ratio preserves raw box queries" begin
    points = [@SVector([Float64(x), Float64(y)])
        for x in 0:9, y in 0:9]
    points = vec(points)
    radii = fill(0.4, length(points))
    tree = CD.Octree(points, radii)

    for id in eachindex(points)
        center = points[id]
        radius = radii[id]
        found = Int[]
        predicate = (box_center, box_halfsize) ->
            CD.fitsinbox(center, radius, box_center, box_halfsize + 1e-12)
        for box in CD.boxes(tree, predicate)
            append!(found, box)
        end
        @test id in found
    end
end

@testset "two-dimensional minimum box size uses dimensional scaling" begin
    points = [@SVector([0.0, 0.0]), @SVector([2.0, 0.0]),
              @SVector([0.0, 2.0]), @SVector([2.0, 2.0])]
    splitcount = 8
    tree = CD.Octree(points, zeros(4), 1.0, splitcount)
    expected = 0.1 * tree.halfsize * (splitcount / length(points))^(1 / 2)
    old_three_dimensional_formula =
        0.1 * tree.halfsize * (splitcount / length(points))^(1 / 3)
    @test tree.minhalfsize ≈ expected
    @test tree.minhalfsize != old_three_dimensional_formula
end

@testset "mesh-derived bounds agree with brute force" begin
    fixture = joinpath(@__DIR__, "assets", "mesh_bounds_100k.jld2")
    data = JLD2.load(fixture)
    rng = MersenneTwister(0x5EEDDA7A)

    cases = (
        (data["circle_centers"], data["circle_radii"]),
        (data["sphere_centers"], data["sphere_radii"]),
    )
    for (center_data, radii) in cases
        dimension = size(center_data, 1)
        point_type = dimension == 2 ? SVector{2,Float64} : SVector{3,Float64}
        points = [point_type(center_data[:, i]) for i in axes(center_data, 2)]
        queries = [
            (zero(point_type), 0.0),
            (zero(point_type), 0.01),
            (zero(point_type), 0.1),
            (zero(point_type), 0.5),
            (point_type(fill(2.0, dimension)), 0.01),
        ]
        append!(queries, [
            (point_type(rand(rng, dimension) .* 3 .- 1.5), rand(rng) * 0.2)
            for _ in 1:995
        ])

        for (splitcount, expansion_ratio) in ((4, 1.0), (16, 1.1), (64, 1.25))
            tree = CD.Octree(points, radii, expansion_ratio, splitcount)
            for (center, halfsize) in queries
                bb = (center, halfsize)
                pred = i -> iseven(i) || points[i][1] < 0
                expected = brute_force_ids(points, radii, center, halfsize, pred)
                found = collect(CD.searchtree(pred, tree, bb))
                visited = Int[]
                CD.foreachsearchtree(tree, bb) do id
                    pred(id) && push!(visited, id)
                    false
                end

                @test sort(found) == sort(expected)
                @test sort(visited) == sort(expected)
                @test length(unique(found)) == length(found)
                @test length(unique(visited)) == length(visited)
                @test CD.anysearchtree(pred, tree, bb) == !isempty(expected)
            end
        end
    end
end
