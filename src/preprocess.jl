# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/JuliaFEM.jl/blob/master/LICENSE.md

#=
- read meshes from different formats
- reorder connectivity, create element sets, node sets, ...
- create partitions for parallel runs
- renumber elements / nodes
- maybe precheck for bad elements
- check surface normal direction in boundary elements
- orientation of 2d elements
- etc only topology related stuff
=#

importall Base

using JuliaFEM

type Mesh
    nodes :: Dict{Int64, Vector{Float64}}
    node_sets :: Dict{ASCIIString, Set{Int64}}
    elements :: Dict{Int64, Vector{Int64}}
    element_types :: Dict{Int64, Symbol}
    element_sets :: Dict{ASCIIString, Set{Int64}}
end

function Mesh()
    return Mesh(Dict(), Dict(), Dict(), Dict(), Dict())
end

function add_node!(mesh::Mesh, nid::Int, ncoords::Vector{Float64})
    mesh.nodes[nid] = ncoords
end

function add_nodes!(mesh::Mesh, nodes::Dict{Int64, Vector{Float64}})
    for (nid, ncoords) in nodes
        add_node!(mesh, nid, ncoords)
    end
end

function add_node_to_node_set!(mesh::Mesh, set_name::ASCIIString, nids...)
    if !haskey(mesh.node_sets, set_name)
        mesh.node_sets[set_name] = Set{Int64}()
    end
    push!(mesh.node_sets[set_name], nids...)
end

function add_element!(mesh::Mesh, elid::Int, eltype::Symbol, connectivity::Vector{Int64})
    mesh.elements[elid] = connectivity
    mesh.element_types[elid] = eltype
end

function add_elements!(mesh::Mesh, elements::Dict{Int64, Tuple{Symbol, Vector{Int64}}})
    for (elid, (eltype, elcon)) in elements
        add_element!(mesh, elid, eltype, elcon)
    end
end

function add_element_to_element_set!(mesh::Mesh, set_name::ASCIIString, elids...)
    if !haskey(mesh.element_sets, set_name)
        mesh.element_sets[set_name] = Set{Int64}()
    end
    push!(mesh.element_sets[set_name], elids...)
end

function copy(mesh::Mesh)
    mesh2 = Mesh()
    mesh2.nodes = copy(mesh.nodes)
    mesh2.node_sets = copy(mesh.node_sets)
    mesh2.elements = copy(mesh.elements)
    mesh2.element_types = copy(mesh.element_types)
    mesh2.element_sets = copy(mesh.element_sets)
    return mesh2
end

function filter_by_element_id(mesh::Mesh, element_ids::Vector{Int64})
    mesh2 = copy(mesh)
    mesh2.elements = Dict()
    for elid in element_ids
        if haskey(mesh.elements, elid)
            mesh2.elements[elid] = mesh.elements[elid]
        end
    end
    return mesh2
end

function filter_by_element_set(mesh::Mesh, set_name::ASCIIString)
    filter_by_element_id(mesh::Mesh, collect(mesh.element_sets[set_name]))
end

function create_elements(mesh::Mesh)
    elements = Element[]
    for (elid, elcon) in mesh.elements
        eltype = mesh.element_types[elid]
        element = Element(JuliaFEM.(eltype), elcon)
        update!(element, "geometry", mesh.nodes)
        push!(elements, element)
    end
    return elements
end

function create_elements(mesh::Mesh, element_sets::ASCIIString...)
    elements = Element[]
    for element_set in element_sets
        new_elements = create_elements(filter_by_element_set(mesh, element_set))
        push!(elements, new_elements...)
    end
    return elements
end

function create_elements(mesh::Mesh, element_type::Symbol)
    elements = Element[]
    for (elid, elcon) in mesh.elements
        eltype = mesh.element_types[elid]
        eltype == element_type || continue
        element = Element(JuliaFEM.(eltype), elcon)
        update!(element, "geometry", mesh.nodes)
        push!(elements, element)
    end
    return elements
end

""" find npts nearest nodes form mesh and return id numbers as list. """
function find_nearest_nodes(mesh::Mesh, coords::Vector, npts=1)
    dist = Dict{Int64, Float64}()
    for (nid, c) in mesh.nodes
        dist[nid] = norm(coords-c)
    end
    s = sort(collect(dist), by=x->x[2])
    nd = s[1:npts] # [(id1, dist1), (id2, dist2), ..., (id_npts, dist_npts)]
    node_ids = [n[1] for n in nd]
    return node_ids
end

"""
Apply new node ordering to elements. In JuliaFEM same node ordering is used
than in ABAQUS and if mesh is parsed from FEM format with other node ordering
this can be used to reorder nodes.

Parameters
----------
mapping :: Dict{Symbol, Vector{Int}}
    e.g. :Tet10, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

"""
function reorder_element_connectivity!(mesh::Mesh, mapping::Dict{Symbol, Vector{Int}})
    for (elid, eltype) in mesh.element_types
        haskey(mapping, eltype) || continue
        new_order = mapping[eltype]
        element_connectivity = mesh.elements[elid]
        new_element_connectivity = element_connectivity[new_order]
        mesh.elements[elid] = new_element_connectivity
    end
end

"""
Swap surface element connectivity s.t. normals point outward
"""
function check_orientation!
    # TODO
end

"""
Partition model using METIS
"""
function partition_model!
    # TODO
end
