# Continuum Sweep Results

This file records the Trixi-only sweep performed from this repository on `2026-07-08`.

## Tested Cases

### Mesh / baseline cases

- `Kn = 1e-3`, `NX = 40`, `TEND = 200`
  - command:
    ```bash
    make trixi-run KN=1e-3 NX=40 POLYDEG=1 TEND=200 SAVE_DT=50 OUTDIR=results/trixi_kn1e-3_nx40_t200
    ```
  - status: completed
  - accepted timesteps: `45786`
  - wall-clock runtime: about `8 s`

- Existing prior runs available in the repo:
  - `Kn = 1e-3`, `NX = 80`, `TEND = 200`
  - `Kn = 1e-3`, `NX = 160`, `TEND = 300`

These are sufficient to support an approximate mesh/time convergence discussion for the assignment, although a fully clean rerun of all three cases in separate directories would be better if you want a polished appendix.

### Stability sweep in Knudsen number

- `Kn = 3e-3`, `NX = 80`, `TEND = 200`
  - command:
    ```bash
    make trixi-run KN=3e-3 NX=80 POLYDEG=1 TEND=200 SAVE_DT=50 OUTDIR=results/trixi_kn3e-3_nx80_t200
    ```
  - status: completed
  - accepted timesteps: `95897`
  - runtime: about `31 s`

- `Kn = 1e-2`, `NX = 80`, `TEND = 200`
  - command:
    ```bash
    make trixi-run KN=1e-2 NX=80 POLYDEG=1 TEND=200 SAVE_DT=50 OUTDIR=results/trixi_kn1e-2_nx80_t200
    ```
  - status: completed
  - accepted timesteps: `97939`
  - runtime: about `33.5 s`

- `Kn = 3e-2`, `NX = 80`, `TEND = 200`
  - command:
    ```bash
    make trixi-run KN=3e-2 NX=80 POLYDEG=1 TEND=200 SAVE_DT=50 OUTDIR=results/trixi_kn3e-2_nx80_t200
    ```
  - status: failed very early
  - failure time: about `t ≈ 0.53`
  - failure mode: negative temperature state caused `sqrt(T)` in the hard-sphere viscosity model to throw a `DomainError`

- `Kn = 1e-1`, `NX = 80`, `TEND = 200`
  - command:
    ```bash
    make trixi-run KN=1e-1 NX=80 POLYDEG=1 TEND=200 SAVE_DT=50 OUTDIR=results/trixi_kn1e-1_nx80_t200
    ```
  - status: failed very early
  - failure time: before `t = 1`
  - failure mode: same negative-temperature `DomainError`

## Main Continuum Conclusion

For this Trixi setup and this tested resolution:

- `Kn = 1e-2` still works
- `Kn = 3e-2` already fails

So the largest stable Knudsen number is bracketed as:

```text
1e-2 <= Kn_stable < 3e-2
```

If you need one single reported value for the assignment, the strongest defensible statement from these runs is:

- the largest tested stable case is `Kn = 1e-2`

## Physical Interpretation Of The Failure

The continuum solver failure is not shock-related. The crash occurs because the solution evolves to a nonphysical state with negative temperature in the near-wall region, which then breaks the viscosity model `mu ~ sqrt(T)`.

This supports the intended assignment interpretation:

- increasing `Kn` makes the gas more rarefied
- near-wall velocity slip and temperature jump become important
- the continuum no-slip/isothermal closure becomes increasingly inconsistent with the true kinetic wall physics
- unresolved near-wall non-equilibrium causes oscillatory or nonphysical states
- the Navier-Stokes solve then fails even though no shocks are present

SPARTA is the right tool to confirm this interpretation, since it should continue to show physically meaningful rarefied-wall behavior where the continuum model becomes unreliable.
