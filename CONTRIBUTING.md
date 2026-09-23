# Collaboration workflow

Use one branch per work package and keep each package in its own commit series. This prevents three contributors from editing the same files at the same time.

## Contributor 1 — network model and data

Files:
- `src/ieee30_data.m`
- `src/form_Ybus.m`
- `src/create_ieee30_simulink.m`

Suggested branch:

```bash
git switch -c feature/network-model
```

Suggested commits:

```text
Add IEEE 30-bus network data
Implement Y-bus formation
Add Simscape IEEE 30-bus layout builder
```

## Contributor 2 — load-flow methods

Files:
- `src/gauss_seidel_pf.m`
- `src/newton_raphson_pf.m`

Suggested branch:

```bash
git switch -c feature/power-flow
```

Suggested commits:

```text
Implement Gauss-Seidel load flow
Implement Newton-Raphson load flow
```

## Contributor 3 — fault and stability analysis

Files:
- `src/short_circuit_analysis.m`
- `src/equal_area_criterion.m`

Suggested branch:

```bash
git switch -c feature/fault-stability
```

Suggested commits:

```text
Implement three-phase Z-bus fault analysis
Add equal-area transient-stability study
```

## Integration

The repository owner should merge the three pull requests, then make the integration commit for:

- `src/main_analysis.m`
- `run_project.m`
- figures and report
- `README.md`

Before merging, each contributor should pull the latest `main`, run the files they changed, and confirm that no generated MATLAB cache files are staged.
