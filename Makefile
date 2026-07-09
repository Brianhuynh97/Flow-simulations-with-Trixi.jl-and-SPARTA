JULIA ?= $(HOME)/.juliaup/bin/julia
JULIA_DEPOT_PATH ?= $(CURDIR)/.julia_depot:$(HOME)/.julia
KN ?= 1e-3
NX ?= 80
POLYDEG ?= 1
TEND ?= 200
SAVE_DT ?= 50
MAXITERS ?= 5000000
OUTDIR ?= out
TRIXI_VTK_INPUT ?= $(OUTDIR)/solution_*.h5
TRIXI_VTK_OUTPUT ?= $(OUTDIR)
TRIXI_PROFILE_INPUT ?= $(OUTDIR)/solution_*.h5
TRIXI_PROFILE_OUTPUT ?= $(OUTDIR)/trixi_line.csv
FIGURES_DIR ?= figures
SPARTA ?= $(CURDIR)/external/sparta-src/src/spa_mac
SPARTA_CASE_DIR ?= runs/sparta_kn$(KN)
SPARTA_CELLS_PER_MFP ?= 1.0
SPARTA_PARTICLES_PER_CELL ?= 40
SPARTA_FLIGHT_FRACTION ?= 0.5
SPARTA_TIME ?= 8e-3
SPARTA_AVG_FRACTION ?= 0.5

.PHONY: params trixi-help trixi-run
.PHONY: trixi-vtk trixi-profile trixi-figures
.PHONY: sparta-case sparta-run sparta-vtk sparta-all

params:
	python3 scripts/argon_couette_params.py --kn $(KN)

trixi-help:
	JULIA_DEPOT_PATH="$(JULIA_DEPOT_PATH)" $(JULIA) --project=. trixi/elixir_couette_argon.jl --help

trixi-run:
	JULIA_DEPOT_PATH="$(JULIA_DEPOT_PATH)" $(JULIA) --project=. trixi/elixir_couette_argon.jl \
		--kn $(KN) \
		--nx $(NX) \
		--polydeg $(POLYDEG) \
		--t-end $(TEND) \
		--save-dt $(SAVE_DT) \
		--maxiters $(MAXITERS) \
		--output-dir $(OUTDIR)

trixi-vtk:
	JULIA_DEPOT_PATH="$(JULIA_DEPOT_PATH)" $(JULIA) --project=. scripts/convert_trixi_to_vtk.jl "$(TRIXI_VTK_INPUT)" "$(TRIXI_VTK_OUTPUT)"

trixi-profile:
	JULIA_DEPOT_PATH="$(JULIA_DEPOT_PATH)" $(JULIA) --project=. scripts/extract_trixi_profile.jl "$(TRIXI_PROFILE_INPUT)" "$(TRIXI_PROFILE_OUTPUT)"

trixi-figures: trixi-profile
	python3 scripts/plot_profiles.py \
		--csv "$(TRIXI_PROFILE_OUTPUT)" \
		--output-dir "$(FIGURES_DIR)"

sparta-case:
	python3 sparta/workflow.py case \
		--kn $(KN) \
		--output-dir $(SPARTA_CASE_DIR) \
		--cells-per-mfp $(SPARTA_CELLS_PER_MFP) \
		--particles-per-cell $(SPARTA_PARTICLES_PER_CELL) \
		--flight-fraction $(SPARTA_FLIGHT_FRACTION) \
		--physical-time $(SPARTA_TIME) \
		--avg-fraction $(SPARTA_AVG_FRACTION)

sparta-run: sparta-case
	python3 sparta/workflow.py run \
		--case-dir $(SPARTA_CASE_DIR) \
		--sparta-binary $(SPARTA)

sparta-vtk:
	python3 sparta/workflow.py vtk \
		--case-dir $(SPARTA_CASE_DIR) \
		--output $(SPARTA_CASE_DIR)/sparta_profile.vtu

sparta-all:
	python3 sparta/workflow.py all \
		--kn $(KN) \
		--case-dir $(SPARTA_CASE_DIR) \
		--sparta-binary $(SPARTA) \
		--cells-per-mfp $(SPARTA_CELLS_PER_MFP) \
		--particles-per-cell $(SPARTA_PARTICLES_PER_CELL) \
		--flight-fraction $(SPARTA_FLIGHT_FRACTION) \
		--physical-time $(SPARTA_TIME) \
		--avg-fraction $(SPARTA_AVG_FRACTION) \
		--vtk-output $(SPARTA_CASE_DIR)/sparta_profile.vtu
