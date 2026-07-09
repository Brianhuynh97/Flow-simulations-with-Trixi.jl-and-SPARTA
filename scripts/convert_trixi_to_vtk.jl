#!/usr/bin/env julia

using Glob
using HDF5
using Trixi2Vtk

function print_help()
    println("Usage: julia --project=. scripts/convert_trixi_to_vtk.jl [input-glob] [output-dir]")
    println("  input-glob  Glob or file path for Trixi solution HDF5 files (default: out/solution_*.h5)")
    println("  output-dir  Directory for generated VTK files (default: out)")
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

    return map(item -> item.filename, compatible)
end

function main(args)
    if any(arg -> arg in ("-h", "--help"), args)
        print_help()
        return
    end

    input_glob = length(args) >= 1 ? args[1] : joinpath("out", "solution_*.h5")
    output_dir = length(args) >= 2 ? args[2] : "out"

    println("Converting Trixi output to VTK")
    println("  input:  $(input_glob)")
    println("  output: $(output_dir)")

    compatible_files = collect_compatible_files(input_glob)
    println("  files:  $(length(compatible_files)) compatible solution files")

    trixi2vtk(compatible_files..., output_directory = output_dir)
end

main(ARGS)
