# Run Results

This file records the actual runs completed from this repository in the current environment.

## Trixi Baseline Run

Run date:

- `2026-07-07`

Command:

```bash
make trixi-run KN=1e-3 NX=80 POLYDEG=1 TEND=200 SAVE_DT=50 MAXITERS=5000000
```

Execution notes:

- the run required execution outside the sandbox because MPI socket initialization is blocked inside the sandbox
- the run completed successfully
- final simulation time: `200.0`
- accepted timesteps: `90102`
- wall-clock runtime: about `36.2 s`

Recorded final analysis values from the last Trixi summary block:

- `L2(rho) = 3.36860453e-01`
- `L2(rho_v1) = 2.01267647e-05`
- `L2(rho_v2) = 1.09716786e+00`
- `L2(rho_e_total) = 3.05359047e+00`
- `Linf(rho) = 1.29182010e+00`
- `Linf(rho_v1) = 1.54963291e-04`
- `Linf(rho_v2) = 5.15643091e+00`
- `Linf(rho_e_total) = 1.22575239e+01`

## Generated ParaView Inputs

The run produced HDF5 output files in [out](/Users/brianhuynh/Project03_MSSD/out):

- [mesh.h5](/Users/brianhuynh/Project03_MSSD/out/mesh.h5)
- [solution_000000000.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000000000.h5)
- [solution_000018400.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000018400.h5)
- [solution_000036431.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000036431.h5)
- [solution_000041293.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000041293.h5)
- [solution_000065521.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000065521.h5)
- [solution_000081905.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000081905.h5)
- [solution_000090102.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000090102.h5)
- [solution_000130035.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000130035.h5)
- [solution_000178867.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000178867.h5)
- [solution_000227879.h5](/Users/brianhuynh/Project03_MSSD/out/solution_000227879.h5)

Open these in ParaView and use `Plot Over Line` to export the 1D profile CSV needed by `scripts/plot_profiles.py`.

## SPARTA Runs

Run date:

- `2026-07-08`

### `Kn = 1e-3` Smoke Validation

Command:

```bash
cd runs/sparta_smoke_kn1e-3 && ../../external/sparta-src/src/spa_mac -in in.couette
```

Execution notes:

- completed successfully
- intended only as a smoke test of the generated input deck
- final timestep: `200`
- wall-clock runtime: about `0.26 s`

Produced files:

- [runs/sparta_smoke_kn1e-3/log.sparta](/Users/brianhuynh/Project03_MSSD/runs/sparta_smoke_kn1e-3/log.sparta)
- [runs/sparta_smoke_kn1e-3/profile.grid](/Users/brianhuynh/Project03_MSSD/runs/sparta_smoke_kn1e-3/profile.grid)

### `Kn = 1e-2` Production Comparison Case

Command:

```bash
make sparta-run KN=1e-2
```

Execution notes:

- completed successfully on `2026-07-08`
- final timestep: `160000`
- particles: `4000`
- grid cells: `100`
- wall-clock runtime: about `32.9 s`
- averaging window: final `80000` steps

Produced files:

- [runs/sparta_kn1e-2/log.sparta](/Users/brianhuynh/Project03_MSSD/runs/sparta_kn1e-2/log.sparta)
- [runs/sparta_kn1e-2/profile.00000000.grid](/Users/brianhuynh/Project03_MSSD/runs/sparta_kn1e-2/profile.00000000.grid)
- [runs/sparta_kn1e-2/profile.00160000.grid](/Users/brianhuynh/Project03_MSSD/runs/sparta_kn1e-2/profile.00160000.grid)

Extracted profile summary from `profile.00160000.grid`:

- near lower wall at `x = 5.0e-5 m`: `v = -974.79 m/s`, versus linear no-slip value `-990 m/s`
- centerline at `x = 4.95e-3 m`: `v = -10.06 m/s`, `T = 1000.99 K`
- near upper wall at `x = 9.95e-3 m`: `v = 974.70 m/s`, versus linear no-slip value `990 m/s`
- temperature range across the channel: about `349.19 K` to `1002.75 K`
- pressure range across the channel: about `171.07 Pa` to `172.35 Pa`
- RMS deviation from the linear Couette velocity profile: about `30.88 m/s`

Interpretation:

- the DSMC result exhibits clear wall slip of about `15 m/s` near each wall at `Kn = 1e-2`
- the profile remains close to linear in the core, but not at the walls
- the temperature rise is strong and peaks near the channel center, consistent with viscous heating
- this is the appropriate SPARTA comparison case for the largest continuum-stable Knudsen number found in the existing Trixi sweep

### Practical Note On `Kn = 1e-3`

The generated `Kn = 1e-3` production case uses:

- `1000` cells
- `40000` simulation particles
- timestep `5e-9 s`
- `1.6e6` total steps

That case is therefore much more expensive than `Kn = 1e-2`. The smoke run verifies the deck, but a full production `Kn = 1e-3` DSMC run is better treated as a longer offline job.
