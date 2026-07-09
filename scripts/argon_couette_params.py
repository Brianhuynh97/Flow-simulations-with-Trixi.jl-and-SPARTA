#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math

K_B = 1.380649e-23
ARGON_MASS = 6.63e-26
ARGON_DIAMETER = 3.657897e-10
GAMMA = 5.0 / 3.0
PRANDTL = 2.0 / 3.0


def compute_state(kn: float, length: float, temperature: float, wall_speed: float) -> dict[str, float]:
    mean_free_path = kn * length
    number_density = 1.0 / (math.sqrt(2.0) * math.pi * mean_free_path * ARGON_DIAMETER**2)
    density = ARGON_MASS * number_density
    pressure = number_density * K_B * temperature
    gas_constant = K_B / ARGON_MASS
    viscosity = 5.0 / (16.0 * ARGON_DIAMETER**2) * math.sqrt(ARGON_MASS * K_B * temperature / math.pi)
    conductivity = 15.0 * K_B / (4.0 * ARGON_MASS) * viscosity
    cp = 5.0 * K_B / (2.0 * ARGON_MASS)
    sound_speed = math.sqrt(GAMMA * gas_constant * temperature)
    mach = wall_speed / sound_speed
    reynolds = density * wall_speed * length / viscosity
    peclet = reynolds * PRANDTL
    kinematic_viscosity = viscosity / density
    thermal_diffusivity = conductivity / (density * cp)
    diffusion_time = length**2 / kinematic_viscosity
    thermal_time = length**2 / thermal_diffusivity
    delta_t_center = (GAMMA - 1.0) / (2.0 * PRANDTL) * mach**2 * temperature

    return {
        "kn": kn,
        "length_m": length,
        "temperature_K": temperature,
        "wall_speed_m_per_s": wall_speed,
        "mean_free_path_m": mean_free_path,
        "number_density_per_m3": number_density,
        "density_kg_per_m3": density,
        "pressure_Pa": pressure,
        "gas_constant_J_per_kgK": gas_constant,
        "viscosity_Pa_s": viscosity,
        "conductivity_W_per_mK": conductivity,
        "cp_J_per_kgK": cp,
        "sound_speed_m_per_s": sound_speed,
        "mach": mach,
        "reynolds": reynolds,
        "peclet": peclet,
        "kinematic_viscosity_m2_per_s": kinematic_viscosity,
        "thermal_diffusivity_m2_per_s": thermal_diffusivity,
        "momentum_diffusion_time_s": diffusion_time,
        "thermal_diffusion_time_s": thermal_time,
        "centerline_temperature_rise_K": delta_t_center,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kn", type=float, default=1.0e-3)
    parser.add_argument("--length", type=float, default=1.0e-2)
    parser.add_argument("--temperature", type=float, default=300.0)
    parser.add_argument("--wall-speed", type=float, default=1000.0)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    state = compute_state(args.kn, args.length, args.temperature, args.wall_speed)
    if args.json:
        print(json.dumps(state, indent=2, sort_keys=True))
        return

    for key, value in state.items():
        if isinstance(value, float):
            print(f"{key:32s} = {value:.12e}")
        else:
            print(f"{key:32s} = {value}")


if __name__ == "__main__":
    main()
