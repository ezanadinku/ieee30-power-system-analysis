# IEEE 30-Bus Power System Analysis

MATLAB implementation of an IEEE 30-bus study for **ELE4343 Advanced Power Systems**. The project covers:

- Y-bus formation from branch and shunt data
- Gauss-Seidel load-flow analysis
- Newton-Raphson load-flow analysis with a full Jacobian
- Three-phase symmetrical fault analysis using the Z-bus method
- Equal Area Criterion / swing-equation transient-stability study
- A Simscape Electrical script that lays out the IEEE 30-bus model blocks

The numerical methods are written directly in MATLAB rather than calling a dedicated power-flow toolbox routine.

## Repository structure

```text
ieee30-power-system-analysis/
├── run_project.m
├── src/
│   ├── ieee30_data.m
│   ├── form_Ybus.m
│   ├── gauss_seidel_pf.m
│   ├── newton_raphson_pf.m
│   ├── short_circuit_analysis.m
│   ├── equal_area_criterion.m
│   ├── create_ieee30_simulink.m
│   └── main_analysis.m
├── results/
│   └── figures/
└── docs/
    └── Advanced_Power_Report.docx
```

## Requirements

- MATLAB
- Simulink + Simscape Electrical only if `create_ieee30_simulink.m` is used

The main numerical analysis itself is implemented with standard MATLAB operations.

## Running the project

1. Clone the repository.
2. Open MATLAB and set the Current Folder to the repository root.
3. Run:

```matlab
run_project
```

The main script writes its figures to `results/figures/`.

To generate the Simulink block layout separately:

```matlab
addpath('src')
create_ieee30_simulink
```

The Simulink builder creates the block layout and saves `IEEE30_SLD.slx`. Because Simscape block parameter names can vary by MATLAB release, unsupported parameters are skipped and should be checked in the Property Inspector. The electrical connections still need to be wired after the blocks are created.

## Main source files

| File | Purpose |
| --- | --- |
| `ieee30_data.m` | Bus, branch and generator data |
| `form_Ybus.m` | Builds the network admittance matrix |
| `gauss_seidel_pf.m` | Gauss-Seidel load-flow solver |
| `newton_raphson_pf.m` | Newton-Raphson load-flow solver |
| `short_circuit_analysis.m` | Three-phase Z-bus fault analysis |
| `equal_area_criterion.m` | SMIB equal-area / swing-equation study |
| `main_analysis.m` | Runs the complete numerical study and produces plots |
| `create_ieee30_simulink.m` | Creates the Simscape Electrical block layout |

## Collaboration plan

The source files are intentionally separated so that three contributors can work with minimal merge conflicts:

- **Network model:** `ieee30_data.m`, `form_Ybus.m`, `create_ieee30_simulink.m`
- **Power flow:** `gauss_seidel_pf.m`, `newton_raphson_pf.m`
- **Fault and stability:** `short_circuit_analysis.m`, `equal_area_criterion.m`

`main_analysis.m`, documentation and final integration should be changed only after the three source branches have been merged.

## Modeling note

The supplied project uses a simplified flat 1.0 pu pre-fault voltage by default in the short-circuit calculation. `short_circuit_analysis.m` also accepts an optional complex pre-fault voltage vector, so a future version can use a load-dependent Newton-Raphson solution without rewriting the fault equations.

## Report and figures

The submitted report is stored in `docs/`. Representative output plots are stored in `results/figures/` so the repository can be reviewed without rerunning MATLAB first.
