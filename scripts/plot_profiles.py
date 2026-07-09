#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path
from typing import Dict, List

def load_csv(path: str) -> Dict[str, List[float]]:
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        columns: Dict[str, List[float]] = {name: [] for name in reader.fieldnames or []}
        for row in reader:
            for name, value in row.items():
                columns[name].append(float(value))
    return columns


def pick_column(columns: Dict[str, List[float]], candidates: list[str]) -> str:
    lowered = {name.lower(): name for name in columns}
    for candidate in candidates:
        if candidate.lower() in lowered:
            return lowered[candidate.lower()]
    raise KeyError(f"could not find any of {candidates} in CSV columns {list(columns)}")


def resolve_csv_path(raw_path: str) -> Path:
    path = Path(raw_path)
    if path.exists():
        return path

    matches = sorted(Path.cwd().rglob(path.name))
    if len(matches) == 1:
        return matches[0]

    if matches:
        formatted_matches = "\n".join(f"  - {match}" for match in matches)
        raise SystemExit(
            f"CSV file '{raw_path}' was not found exactly, and multiple files named "
            f"'{path.name}' exist under {Path.cwd()}:\n{formatted_matches}\n"
            "Pass the intended file path explicitly with --csv."
        )

    raise SystemExit(
        f"CSV file '{raw_path}' was not found.\n"
        "Export a `Plot Over Line` CSV from ParaView first, or pass the correct path "
        "to an existing export with --csv."
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--length", type=float, default=0.01)
    parser.add_argument("--wall-speed", type=float, default=1000.0)
    parser.add_argument("--gas-constant", type=float, default=2.082426847662e02)
    args = parser.parse_args()

    cache_root = Path(args.output_dir) / ".plot_cache"
    mpl_config_dir = cache_root / "matplotlib"
    xdg_cache_home = cache_root / "xdg"
    mpl_config_dir.mkdir(parents=True, exist_ok=True)
    xdg_cache_home.mkdir(parents=True, exist_ok=True)
    os.environ["MPLCONFIGDIR"] = str(mpl_config_dir)
    os.environ["XDG_CACHE_HOME"] = str(xdg_cache_home)

    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "matplotlib is required for plotting. Install it with "
            "`python3 -m pip install --user matplotlib`."
        ) from exc

    os.makedirs(args.output_dir, exist_ok=True)
    csv_path = resolve_csv_path(args.csv)
    columns = load_csv(str(csv_path))

    x_name = pick_column(columns, ["Points:0", "Points_X", "x", "arc_length"])
    vy_name = pick_column(columns, ["v2", "velocity_y", "Velocity:1"])
    x_raw = columns[x_name]
    vy_vals = columns[vy_name]

    if x_raw and min(x_raw) >= -1.0e-12 and max(x_raw) <= 1.0 + 1.0e-12:
        x_vals = [x * args.length for x in x_raw]
    else:
        x_vals = x_raw

    try:
        t_name = pick_column(columns, ["temperature", "T", "Temperature"])
        t_vals = columns[t_name]
    except KeyError:
        rho_name = pick_column(columns, ["rho", "density"])
        p_name = pick_column(columns, ["p", "pressure", "Pressure"])
        rho_vals = columns[rho_name]
        p_vals = columns[p_name]
        t_vals = [p / (rho * args.gas_constant) for p, rho in zip(p_vals, rho_vals)]

    expected_linear = [
        -args.wall_speed + 2.0 * (x / args.length) * args.wall_speed
        for x in x_vals
    ]
    vy_deviation = [vy - expected for vy, expected in zip(vy_vals, expected_linear)]

    plt.figure(figsize=(6, 4))
    plt.plot(x_vals, vy_vals, linewidth=2, label="Trixi")
    plt.plot(x_vals, expected_linear, "--", linewidth=1.5, label="Linear no-slip")
    plt.xlabel("x [m]")
    plt.ylabel("v_y [m/s]")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(os.path.join(args.output_dir, "velocity.png"), dpi=200)
    plt.close()

    plt.figure(figsize=(6, 4))
    plt.plot(x_vals, vy_deviation, linewidth=2)
    plt.xlabel("x [m]")
    plt.ylabel("v_y - v_linear [m/s]")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(args.output_dir, "velocity_deviation.png"), dpi=200)
    plt.close()

    plt.figure(figsize=(6, 4))
    plt.plot(x_vals, t_vals, linewidth=2)
    plt.xlabel("x [m]")
    plt.ylabel("Temperature [K]")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(args.output_dir, "temperature.png"), dpi=200)
    plt.close()


if __name__ == "__main__":
    main()
