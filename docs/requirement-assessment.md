# Requirement Assessment

This note records the concrete choices used to satisfy the project requirements on `2026-07-09`.

## 1. Gas density / number density from Knudsen number

For the hard-sphere argon model,

- `lambda = Kn * L`
- `n = 1 / (sqrt(2) * pi * lambda * d^2)`
- `rho = m * n`

with:

- `L = 0.01 m`
- `m = 6.63e-26 kg`
- `d = 3.657897e-10 m`

Results:

| Kn | mean free path `lambda` [m] | number density `n` [1/m^3] | mass density `rho` [kg/m^3] | pressure at 300 K [Pa] |
| --- | ---: | ---: | ---: | ---: |
| `1e-3` | `1.000000e-05` | `1.682179e+23` | `1.115285e-02` | `6.967496e+02` |
| `1e-2` | `1.000000e-04` | `1.682179e+22` | `1.115285e-03` | `6.967496e+01` |
| `3e-2` | `3.000000e-04` | `5.607263e+21` | `3.717615e-04` | `2.322499e+01` |

For this project, the main continuum baseline is `Kn = 1e-3`, so the corresponding gas state is:

- `n = 1.682179e+23 1/m^3`
- `rho = 1.115285e-02 kg/m^3`

## 2. Trixi.jl cell count from velocity-profile convergence

I compared final `t = 200` line profiles for:

- `NX = 40`
- `NX = 80`
- `NX = 160`

The Trixi line data are stored in scaled variables, so the profile differences below were converted back to physical units using:

- `v_ref = 249.94560494208386 m/s`
- `T_ref = 300 K`

Profile differences at final time:

| comparison | velocity RMS diff [m/s] | velocity max diff [m/s] | temperature RMS diff [K] | temperature max diff [K] |
| --- | ---: | ---: | ---: | ---: |
| `NX=40` vs `NX=80` | `0.677` | `3.049` | `0.0064` | `0.0283` |
| `NX=80` vs `NX=160` | `0.149` | `0.943` | `0.0014` | `0.0086` |

Conclusion:

- `NX = 40` is already close, but still changes visibly relative to `NX = 80`
- `NX = 80` and `NX = 160` are nearly indistinguishable
- `NX = 80` is the best practical choice for the report

Recommended Trixi discretization:

- `NX = 80`
- `polydeg = 1`

If a stricter convergence appendix is needed, `NX = 160` is the next refinement level.

## 3. Trixi.jl total simulation time

I compared saved `NX = 80` profiles at `t = 50, 100, 150, 200`.

Late-time drift:

| comparison | velocity RMS diff [m/s] | velocity max diff [m/s] | temperature RMS diff [K] | temperature max diff [K] |
| --- | ---: | ---: | ---: | ---: |
| `t=50` vs `t=100` | `1.158` | `2.053` | `0.581` | `0.800` |
| `t=100` vs `t=150` | `1.116` | `1.662` | `0.168` | `0.230` |
| `t=150` vs `t=200` | `0.309` | `0.458` | `0.044` | `0.060` |

Conclusion:

- the solution is still evolving noticeably by `t = 100`
- by `t = 150`, it is close to steady
- by `t = 200`, the remaining drift is small

Recommended Trixi end time:

- use `TEND = 200` for the converged baseline
- `TEND = 150` is almost enough, but `200` is the safer report value

## 4. SPARTA cell count and timestep

I used the project rule:

- resolve the mean free path with about one cell: `dx <= lambda`
- keep particle flight per step below half a cell width: `dt <= 0.5 * dx / U_wall`

with `U_wall = 1000 m/s`.

This gives:

| Kn | `lambda` [m] | recommended cells across channel | `dx` [m] | recommended `dt` [s] | steps for `8e-3 s` |
| --- | ---: | ---: | ---: | ---: | ---: |
| `1e-2` | `1.0e-4` | `100` | `1.0e-4` | `5.0e-8` | `160000` |
| `1e-3` | `1.0e-5` | `1000` | `1.0e-5` | `5.0e-9` | `1600000` |

Recommended SPARTA settings:

- `cells_per_mean_free_path = 1.0`
- `flight_fraction = 0.5`

For the comparison case `Kn = 1e-2`, the production run therefore uses:

- `100` cells
- `dt = 5e-8 s`
- `160000` steps

For `Kn = 1e-3`, the same criteria imply a much more expensive DSMC job:

- `1000` cells
- `dt = 5e-9 s`
- `1.6e6` steps

## 5. Required SPARTA time averaging

I reran the `Kn = 1e-2` SPARTA case with three averaging windows:

- `avg_fraction = 0.10`
- `avg_fraction = 0.25`
- `avg_fraction = 0.50`

All runs used the same `160000` total steps, so the averaging windows were:

- `0.10` -> last `16000` steps
- `0.25` -> last `40000` steps
- `0.50` -> last `80000` steps

Smoothness was assessed from discrete profile curvature. Lower is smoother.

| averaging fraction | normalized velocity roughness | normalized temperature roughness |
| --- | ---: | ---: |
| `0.10` | `1.6217e-03` | `7.0138e-03` |
| `0.25` | `1.0432e-03` | `4.2520e-03` |
| `0.50` | `7.7310e-04` | `3.2728e-03` |

Direct difference from the `0.50` reference:

| comparison to `avg_fraction=0.50` | velocity RMS diff [m/s] | velocity max diff [m/s] | temperature RMS diff [K] | temperature max diff [K] |
| --- | ---: | ---: | ---: | ---: |
| `0.10` vs `0.50` | `5.89` | `15.76` | `6.89` | `16.58` |
| `0.25` vs `0.50` | `1.78` | `4.58` | `5.31` | `13.00` |

Conclusion:

- `avg_fraction = 0.10` is too noisy
- `avg_fraction = 0.25` is usable, but still noticeably rougher
- `avg_fraction = 0.50` is the best report-quality choice

Recommended averaging choice:

- minimum acceptable: `avg_fraction = 0.25`
- preferred production setting: `avg_fraction = 0.50`

## Final recommended setup

For the report-quality continuum baseline:

- gas state from `Kn = 1e-3`:
  - `n = 1.682179e+23 1/m^3`
  - `rho = 1.115285e-02 kg/m^3`
- Trixi:
  - `NX = 80`
  - `polydeg = 1`
  - `TEND = 200`

For the DSMC comparison at the largest stable continuum case `Kn = 1e-2`:

- SPARTA:
  - `100` cells across the channel
  - `dt = 5e-8 s`
  - `160000` steps for `8e-3 s`
  - averaging over the last `50%` of the run
