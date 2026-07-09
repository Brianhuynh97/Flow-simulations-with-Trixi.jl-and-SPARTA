#!/usr/bin/env julia

using Glob
using HDF5
using Printf

function print_help()
    println("Usage: julia --project=. scripts/extract_trixi_profile.jl [input-glob] [output-csv]")
    println("  input-glob  Glob or file path for Trixi solution HDF5 files (default: out/solution_*.h5)")
    println("  output-csv  CSV file for the extracted 1D profile (default: out/trixi_line.csv)")
end

function solution_metadata(filename)
    h5open(filename, "r") do file
        attrs = attributes(file)
        return (
            filename = filename,
            n_elements = Int(read(attrs["n_elements"])),
            time = Float64(read(attrs["time"])),
            timestep = Int(read(attrs["timestep"])),
        )
    end
end

function collect_compatible_files(input_glob)
    matches = sort(glob(input_glob))
    isempty(matches) && error("no files matched input pattern '$(input_glob)'")

    metadata = map(solution_metadata, matches)
    reference_elements = first(metadata).n_elements
    compatible = filter(item -> item.n_elements == reference_elements, metadata)
    skipped = filter(item -> item.n_elements != reference_elements, metadata)
    sort!(compatible, by = item -> item.time)

    if !isempty(skipped)
        println("Skipping incompatible files with different element counts:")
        for item in skipped
            println("  ", item.filename, " (n_elements=", item.n_elements, ", time=", item.time, ")")
        end
    end

    return compatible
end

function read_solution(filename)
    h5open(filename, "r") do file
        attrs = attributes(file)
        ndims = Int(read(attrs["ndims"]))
        ndims == 2 || error("only 2D Trixi solution files are supported, got ndims=$(ndims)")

        polydeg = Int(read(attrs["polydeg"]))
        n_elements = Int(read(attrs["n_elements"]))
        n_vars = Int(read(attrs["n_vars"]))
        n_nodes = polydeg + 1
        mesh_file = joinpath(dirname(filename), read(attrs["mesh_file"]))
        time = Float64(read(attrs["time"]))

        variables = Dict{String, Array{Float64, 3}}()
        for index in 1:n_vars
            dataset = file["variables_$(index)"]
            name = read(attributes(dataset)["name"])
            values = reshape(read(dataset), n_nodes, n_nodes, n_elements)
            variables[name] = values
        end

        return (; mesh_file, n_elements, n_nodes, variables, time)
    end
end

function read_mesh(mesh_file)
    h5open(mesh_file, "r") do file
        tree_node_coordinates = read(file["tree_node_coordinates"])
        nodes = read(file["nodes"])
        return (; tree_node_coordinates, nodes)
    end
end

function bilinear_coordinate(corners, xi, eta)
    t00 = corners[:, 1, 1]
    t10 = corners[:, 2, 1]
    t01 = corners[:, 1, 2]
    t11 = corners[:, 2, 2]

    return 0.25 * (
        (1 - xi) * (1 - eta) * t00 +
        (1 + xi) * (1 - eta) * t10 +
        (1 - xi) * (1 + eta) * t01 +
        (1 + xi) * (1 + eta) * t11
    )
end

function extract_profile(solution_file; gas_constant = 2.082426847662e02)
    solution = read_solution(solution_file)
    mesh = read_mesh(solution.mesh_file)

    length(mesh.nodes) == solution.n_nodes ||
        error("mesh node count $(length(mesh.nodes)) does not match solution node count $(solution.n_nodes)")
    size(mesh.tree_node_coordinates, 4) == solution.n_elements ||
        error("mesh element count does not match solution element count")

    required_variables = ("rho", "v2", "p")
    for name in required_variables
        haskey(solution.variables, name) || error("solution file is missing variable '$(name)'")
    end

    accumulators = Dict{Float64, NamedTuple{(:count, :x_sum, :rho_sum, :v1_sum, :v2_sum, :p_sum), Tuple{Int, Float64, Float64, Float64, Float64, Float64}}}()
    v1_values = get(solution.variables, "v1", zeros(solution.n_nodes, solution.n_nodes, solution.n_elements))

    for element in 1:solution.n_elements
        corners = @view mesh.tree_node_coordinates[:, :, :, element]
        for j in 1:solution.n_nodes, i in 1:solution.n_nodes
            xi = mesh.nodes[i]
            eta = mesh.nodes[j]
            coordinate = bilinear_coordinate(corners, xi, eta)
            x = round(coordinate[1], digits = 12)

            rho = solution.variables["rho"][i, j, element]
            v1 = v1_values[i, j, element]
            v2 = solution.variables["v2"][i, j, element]
            p = solution.variables["p"][i, j, element]

            current = get(accumulators, x, (count = 0, x_sum = 0.0, rho_sum = 0.0,
                                            v1_sum = 0.0, v2_sum = 0.0, p_sum = 0.0))
            accumulators[x] = (
                count = current.count + 1,
                x_sum = current.x_sum + coordinate[1],
                rho_sum = current.rho_sum + rho,
                v1_sum = current.v1_sum + v1,
                v2_sum = current.v2_sum + v2,
                p_sum = current.p_sum + p,
            )
        end
    end

    xs = sort(collect(keys(accumulators)))
    profile = Vector{NamedTuple{(:x, :rho, :v1, :v2, :p, :temperature), Tuple{Float64, Float64, Float64, Float64, Float64, Float64}}}()
    for x in xs
        item = accumulators[x]
        count = item.count
        x_avg = item.x_sum / count
        rho = item.rho_sum / count
        v1 = item.v1_sum / count
        v2 = item.v2_sum / count
        p = item.p_sum / count
        temperature = p / (rho * gas_constant)
        push!(profile, (x = x_avg, rho = rho, v1 = v1, v2 = v2, p = p, temperature = temperature))
    end

    return profile, solution.time
end

function write_profile(output_csv, profile, time)
    mkpath(dirname(output_csv))
    open(output_csv, "w") do io
        println(io, "x,rho,v1,v2,p,temperature")
        for row in profile
            @printf(io, "%.12e,%.12e,%.12e,%.12e,%.12e,%.12e\n",
                    row.x, row.rho, row.v1, row.v2, row.p, row.temperature)
        end
    end
    println(output_csv)
    println("time=$(time)")
    println("samples=$(length(profile))")
end

function main(args)
    if any(arg -> arg in ("-h", "--help"), args)
        print_help()
        return
    end

    input_glob = length(args) >= 1 ? args[1] : joinpath("out", "solution_*.h5")
    output_csv = length(args) >= 2 ? args[2] : joinpath("out", "trixi_line.csv")

    compatible_files = collect_compatible_files(input_glob)
    latest = last(compatible_files)
    println("Extracting Trixi line profile")
    println("  input:  $(latest.filename)")
    println("  output: $(output_csv)")

    profile, time = extract_profile(latest.filename)
    write_profile(output_csv, profile, time)
end

main(ARGS)
