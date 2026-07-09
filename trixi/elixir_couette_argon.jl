using OrdinaryDiffEqSSPRK
using Trixi
using FlowRef

struct SimulationConfig
    kn::Float64
    nx::Int
    polydeg::Int
    t_end::Float64
    save_dt::Float64
    maxiters::Int
    cfl::Float64
    output_dir::String
    length::Float64
    wall_temperature::Float64
    wall_speed::Float64
    argon_mass::Float64
    argon_diameter::Float64
    gamma::Float64
    prandtl::Float64
end

function print_help()
    println("Usage: julia --project=. trixi/elixir_couette_argon.jl [options]")
    println("  --kn FLOAT         Knudsen number (default: 1e-3)")
    println("  --nx INT           Number of cells across the channel (default: 80)")
    println("  --polydeg INT      DG polynomial degree (default: 1)")
    println("  --t-end FLOAT      End time in scaled units (default: 200)")
    println("  --save-dt FLOAT    HDF5 output interval in scaled units (default: 50)")
    println("  --maxiters INT     Maximum time steps (default: 5000000)")
    println("  --cfl FLOAT        CFL number (default: 0.75)")
    println("  --output-dir STR   Output directory for HDF5 files (default: out)")
    println("  --length FLOAT     Channel width in meters (default: 0.01)")
    println("  --wall-temperature FLOAT  Wall temperature in K (default: 300)")
    println("  --wall-speed FLOAT Wall speed magnitude in m/s (default: 1000)")
end

function parse_cli(args)
    values = Dict(
        "kn" => 1.0e-3,
        "nx" => 80,
        "polydeg" => 1,
        "t-end" => 200.0,
        "save-dt" => 50.0,
        "maxiters" => 5_000_000,
        "cfl" => 0.75,
        "output-dir" => "out",
        "length" => 0.01,
        "wall-temperature" => 300.0,
        "wall-speed" => 1000.0,
    )

    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--help"
            print_help()
            exit(0)
        elseif startswith(arg, "--")
            key = arg[3:end]
            i += 1
            i > length(args) && error("missing value for $(arg)")
            values[key] = if key == "output-dir"
                args[i]
            elseif occursin(r"^[0-9]+$", args[i])
                parse(Int, args[i])
            else
                parse(Float64, args[i])
            end
        else
            error("unknown argument $(arg)")
        end
        i += 1
    end

    return SimulationConfig(
        Float64(values["kn"]),
        Int(values["nx"]),
        Int(values["polydeg"]),
        Float64(values["t-end"]),
        Float64(values["save-dt"]),
        Int(values["maxiters"]),
        Float64(values["cfl"]),
        String(values["output-dir"]),
        Float64(values["length"]),
        Float64(values["wall-temperature"]),
        Float64(values["wall-speed"]),
        6.63e-26,
        3.657897e-10,
        5.0 / 3.0,
        2.0 / 3.0,
    )
end

const cfg = parse_cli(ARGS)
const K_B = FlowRef.k_B

function hard_sphere_number_density(kn, length_m, diameter_m)
    lambda = kn * length_m
    return 1.0 / (sqrt(2.0) * pi * lambda * diameter_m^2)
end

function hard_sphere_viscosity(T, mass, diameter)
    return 5.0 / (16.0 * diameter^2) * sqrt(mass * K_B * T / pi)
end

const n0 = hard_sphere_number_density(cfg.kn, cfg.length, cfg.argon_diameter)
const rho0 = cfg.argon_mass * n0
const p0 = n0 * K_B * cfg.wall_temperature
const ref_q = p_m_rho_L(p0, cfg.argon_mass, rho0, cfg.length)
const mu_ref = getproperty(ref_q, Symbol("μ_ref"))

const equations = CompressibleEulerEquations2D(cfg.gamma)

function viscosity_model(u, equations_parabolic)
    T_physical = u[4] * ref_q.T_ref
    return hard_sphere_viscosity(T_physical, cfg.argon_mass, cfg.argon_diameter) / mu_ref
end

const equations_parabolic = CompressibleNavierStokesDiffusion2D(
    equations,
    mu = viscosity_model,
    Prandtl = cfg.prandtl,
)

function primitive_state(x, equations_any)
    rho_scaled = rho0 / ref_q.rho_ref
    vx_scaled = 0.0
    vy_physical = -cfg.wall_speed + 2.0 * (x[1] / 1.0) * cfg.wall_speed
    vy_scaled = vy_physical / ref_q.v_ref
    if equations_any isa CompressibleNavierStokesDiffusion2D
        return SVector(rho_scaled, vx_scaled, vy_scaled, cfg.wall_temperature / ref_q.T_ref)
    else
        return SVector(rho_scaled, vx_scaled, vy_scaled, p0 / ref_q.p_ref)
    end
end

@inline function initial_condition(x, t, equations_any)
    return prim2cons(primitive_state(x, equations_any), equations_any)
end

const mesh = P4estMesh(
    (cfg.nx, 1),
    polydeg = 1,
    coordinates_min = (0.0, 0.0),
    coordinates_max = (1.0, 1.0),
    periodicity = (false, true),
)

const bcs_hyperbolic = (; x_neg = boundary_condition_slip_wall,
                         x_pos = boundary_condition_slip_wall)

const velocity_left = NoSlip((x, t, equations_any) -> SVector(0.0, -cfg.wall_speed / ref_q.v_ref))
const velocity_right = NoSlip((x, t, equations_any) -> SVector(0.0, cfg.wall_speed / ref_q.v_ref))
const heat_bc_wall = Isothermal((x, t, equations_any) -> cfg.wall_temperature / ref_q.T_ref)

const bc_parabolic_left = BoundaryConditionNavierStokesWall(velocity_left, heat_bc_wall)
const bc_parabolic_right = BoundaryConditionNavierStokesWall(velocity_right, heat_bc_wall)
const bcs_parabolic = (; x_neg = bc_parabolic_left,
                        x_pos = bc_parabolic_right)

const solver = DGSEM(polydeg = cfg.polydeg, surface_flux = flux_hll)

const semi = SemidiscretizationHyperbolicParabolic(
    mesh,
    (equations, equations_parabolic),
    initial_condition,
    solver;
    boundary_conditions = (bcs_hyperbolic, bcs_parabolic),
)

const tspan = (0.0, cfg.t_end)
const ode = semidiscretize(semi, tspan)

const summary_callback = SummaryCallback()
const analysis_callback = AnalysisCallback(semi, interval = 1000)
const alive_callback = AliveCallback(analysis_interval = 1000)
const save_solution = SaveSolutionCallback(
    dt = cfg.save_dt,
    save_initial_solution = true,
    save_final_solution = true,
    solution_variables = cons2prim,
    output_directory = cfg.output_dir,
)
const stepsize_callback = StepsizeCallback(cfl = cfg.cfl)
const positivity_limiter = PositivityPreservingLimiterZhangShu(
    thresholds = (1.0e-5, 1.0e-5),
    variables = (pressure, Trixi.density),
)
const callbacks = CallbackSet(
    summary_callback,
    analysis_callback,
    alive_callback,
    save_solution,
    stepsize_callback,
)

@info "Couette setup" kn = cfg.kn rho0 = rho0 n0 = n0 p0 = p0 v_ref = ref_q.v_ref T_ref = ref_q.T_ref
@info "Reference quantities" ref_q = Dict(ref_q)

sol = solve(
    ode,
    SSPRK43(stage_limiter! = positivity_limiter),
    adaptive = false;
    dt = 1.0,
    maxiters = cfg.maxiters,
    ode_default_options()...,
    callback = callbacks,
)
