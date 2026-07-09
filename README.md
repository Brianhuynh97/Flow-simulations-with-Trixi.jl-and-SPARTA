# Project 03: Couette Flow with Trixi.jl and SPARTA

This repository turns the assignment into a reproducible command-line project. It contains:

- a physical-parameter calculator for the argon Couette setup
- a configurable Trixi.jl Navier-Stokes simulation file in scaled variables
- post-processing utilities for automated Trixi profile extraction and plotting
- a dependency-free SPARTA grid-dump exporter that writes ParaView-readable VTK files
- a SPARTA runbook and input-deck placeholders for the DSMC half of the assignment

The local environment used to prepare this repo can build the Julia environment, but it cannot run `Trixi.jl` end-to-end inside the Codex sandbox because MPI socket initialization is blocked. A local serial SPARTA binary is vendored in `external/sparta-src/src/spa_mac`, and the `Kn = 1e-2` DSMC comparison case has been run successfully from this repo.

## Assignment Setup

- Channel width: `L = 0.01 m`
- Wall temperature: `T_w = 300 K`
- Wall velocities: `v_y = +/- 1000 m/s`
- Gas: argon
- Molecular mass: `m = 6.63e-26 kg`
- Hard-sphere diameter: `d = 3.657897e-10 m`
- Target near-continuum case: `Kn = 1e-3`

Useful derived values for `Kn = 1e-3`:

| quantity | value |
| --- | ---: |
| mean free path `lambda` | `1.000000e-05 m` |
| number density `n` | `1.682179e+23 1/m^3` |
| mass density `rho` | `1.115285e-02 kg/m^3` |
| pressure `p` | `6.967496e+02 Pa` |
| viscosity `mu(T_w)` | `2.183590e-05 Pa s` |
| conductivity `kappa(T_w)` | `1.705188e-02 W/(m K)` |
| gas constant `R = k_B / m` | `2.082427e+02 J/(kg K)` |
| sound speed at wall | `3.226784e+02 m/s` |
| wall Mach number | `3.099061` |
| centerline temperature rise estimate | `1.440627e+03 K` |

The large temperature rise is expected here because the imposed wall speed is strongly supersonic with respect to the argon sound speed at `300 K`.

## Repository Layout

- [`trixi/elixir_couette_argon.jl`](/Users/brianhuynh/Project03_MSSD/trixi/elixir_couette_argon.jl): Trixi setup for the scaled Navier-Stokes simulation
- [`scripts/argon_couette_params.py`](/Users/brianhuynh/Project03_MSSD/scripts/argon_couette_params.py): computes density, pressure, viscosity, conductivity, Reynolds/Peclet estimates
- [`sparta/workflow.py`](/Users/brianhuynh/Project03_MSSD/sparta/workflow.py): single SPARTA entry point for recommendations, case generation, running, VTK export, and plotting
- [`scripts/extract_trixi_profile.jl`](/Users/brianhuynh/Project03_MSSD/scripts/extract_trixi_profile.jl): extracts a 1D line-profile CSV directly from Trixi HDF5 output
- [`scripts/plot_profiles.py`](/Users/brianhuynh/Project03_MSSD/scripts/plot_profiles.py): plots temperature and velocity-deviation profiles from extracted or ParaView-exported CSV files
- [`sparta/workflow.py`](/Users/brianhuynh/Project03_MSSD/sparta/workflow.py): SPARTA entry point compatible with the documented `make sparta-*` workflow
- [`docs/run-results.md`](/Users/brianhuynh/Project03_MSSD/docs/run-results.md): completed run record and generated ParaView inputs from this repo
- [`docs/continuum-sweep-results.md`](/Users/brianhuynh/Project03_MSSD/docs/continuum-sweep-results.md): Trixi stability sweep and continuum breakdown summary
- [`Makefile`](/Users/brianhuynh/Project03_MSSD/Makefile): convenience commands

## Quick Start

Compute physical parameters:

```bash
python3 scripts/argon_couette_params.py --kn 1e-3
```

Run the Trixi case with a local writable depot:

```bash
JULIA_DEPOT_PATH=$PWD/.julia_depot:$HOME/.julia \
~/.juliaup/bin/julia --project=. trixi/elixir_couette_argon.jl \
  --kn 1e-3 \
  --nx 80 \
  --polydeg 1 \
  --t-end 200 \
  --save-dt 50 \
  --maxiters 5000000
```

Before opening in ParaView, convert the Trixi HDF5 output to VTK:

```bash
make trixi-vtk
```

This generates ParaView-readable `.vtu` files and a `.pvd` collection in `out/`.

For an end-to-end CLI workflow, extract the Trixi line profile directly from the latest compatible HDF5 snapshot and plot it:

```bash
make trixi-figures
```

This writes `out/trixi_line.csv` plus `velocity.png`, `velocity_deviation.png`, and `temperature.png` in `figures/`.

If you want the intermediate CSV without plotting, run:

```bash
make trixi-profile
```

You can still use a ParaView-exported CSV if you prefer:

```bash
python3 scripts/plot_profiles.py \
  --csv trixi_line.csv \
  --output-dir figures \
  --length 0.01 \
  --wall-speed 1000
```

For the SPARTA run already stored in the repo, you can export figures directly from the grid dump:

```bash
python3 sparta/workflow.py plot \
  --case-dir runs/sparta_kn1e-2 \
  --output-dir figures
```

This writes PNG figures for velocity, velocity deviation from the linear Couette profile, and temperature.

To run the full SPARTA path from one script, use:

```bash
make sparta-all KN=1e-2
```

This generates the case, runs SPARTA, exports `runs/sparta_kn<KN>/sparta_profile.vtu`, and writes the SPARTA figures.

To open SPARTA results directly in ParaView without requiring the upstream VTK Python package, convert the SPARTA grid dumps into VTK XML:

```bash
make sparta-vtk KN=1e-2
```

This writes a single ParaView file at `runs/sparta_kn<KN>/sparta_profile.vtu`. If multiple `profile.*.grid` files are present, the workflow picks the latest timestep by default.

## Recommended Workflow

1. Use `scripts/argon_couette_params.py` to compute `rho`, `n`, `p`, and the expected diffusion time scale for each Knudsen number you test.
2. Start with `Kn = 1e-3`.
3. For Trixi, sweep `nx` until the velocity-deviation profile changes only weakly.
4. Increase `t-end` until the temperature and density profiles no longer drift noticeably between saved outputs.
5. For SPARTA, choose a cell width `dx <= lambda` and a timestep that keeps particles from crossing too many cells per step.
6. Export or extract both line profiles and compare:
   - `v_y(x) - (-v_0 + 2 x v_0 / L)`
   - `T(x)`
7. Increase Knudsen number by lowering density until the Trixi Navier-Stokes run becomes oscillatory or unstable; compare the same case against SPARTA.

## Notes On Interpretation

The assignment asks specifically why the continuum solution can oscillate or crash even though no shocks are present. The physical explanation to test against your results is:

- continuum Navier-Stokes enforces near-equilibrium constitutive closure
- increasing `Kn` produces velocity slip and temperature jump at the walls
- near-wall distribution functions become strongly non-equilibrium
- the DSMC/SPARTA solution resolves these kinetic boundary layers, while Trixi does not
- the resulting under-resolved near-wall gradients can drive spurious oscillations or outright solver failure in the continuum run

## Current Status

- Julia environment: built successfully
- Trixi runtime in sandbox: blocked by MPI socket permissions
- Trixi result files: available in `out/` and `results/`
- SPARTA binary: available at `external/sparta-src/src/spa_mac`
- SPARTA runs:
  - `Kn = 1e-3` smoke case completed for 200 steps in `runs/sparta_smoke_kn1e-3/`
  - `Kn = 1e-2` production case completed on `2026-07-08` in `runs/sparta_kn1e-2/`

The remaining project work is now mostly report assembly and figure generation from the stored Trixi and SPARTA outputs.
