# GitHub setup and three-contributor commit plan

This workflow assumes one repository owner plus three other contributors. The owner handles integration; each contributor owns a disjoint set of MATLAB files so their commits can be reviewed and merged independently.

## 1. Create the empty GitHub repository

On GitHub:

1. Click **New repository**.
2. Repository name: `ieee30-power-system-analysis`.
3. Choose Public or Private as required by the course/team.
4. Do **not** initialize it with a README, `.gitignore`, or license because those files already exist locally.
5. Create the repository.
6. Open **Settings > Collaborators** and invite the three team members.

## 2. Make the owner's initial scaffold commit

Open PowerShell or Git Bash in the project folder.

```bash
git init
git branch -M main
```

The initial owner commit should contain only repository scaffolding, documentation and existing result artifacts. Do not stage the analysis source files yet if you want the three contributors to have clean independent source-code commits.

```bash
git add README.md CONTRIBUTING.md GITHUB_SETUP.md TECHNICAL_NOTES.md .gitignore .gitattributes run_project.m docs results
git commit -m "Set up IEEE 30-bus project repository"
```

Connect the local repository to GitHub:

```bash
git remote add origin https://github.com/YOUR-USERNAME/ieee30-power-system-analysis.git
git push -u origin main
```

If `origin` already exists, inspect it first:

```bash
git remote -v
```

If it points to the wrong repository, correct it instead of adding a second `origin`:

```bash
git remote set-url origin https://github.com/YOUR-USERNAME/ieee30-power-system-analysis.git
git push -u origin main
```

## 3. Contributor 1 — network model and system data

Files owned by this contributor:

- `src/ieee30_data.m`
- `src/form_Ybus.m`
- `src/create_ieee30_simulink.m`

After accepting the GitHub invitation:

```bash
git clone https://github.com/YOUR-USERNAME/ieee30-power-system-analysis.git
cd ieee30-power-system-analysis
git switch -c feature/network-model
```

Copy the three assigned cleaned files into `src/`, then:

```bash
git add src/ieee30_data.m src/form_Ybus.m src/create_ieee30_simulink.m
git commit -m "Add IEEE 30-bus network model and Y-bus formation"
git push -u origin feature/network-model
```

Create a pull request from `feature/network-model` into `main`.

## 4. Contributor 2 — power-flow solvers

Files owned by this contributor:

- `src/gauss_seidel_pf.m`
- `src/newton_raphson_pf.m`

```bash
git clone https://github.com/YOUR-USERNAME/ieee30-power-system-analysis.git
cd ieee30-power-system-analysis
git switch -c feature/power-flow
```

Copy the two assigned files into `src/`, then:

```bash
git add src/gauss_seidel_pf.m src/newton_raphson_pf.m
git commit -m "Implement Gauss-Seidel and Newton-Raphson load flow"
git push -u origin feature/power-flow
```

Create a pull request from `feature/power-flow` into `main`.

## 5. Contributor 3 — fault and transient-stability analysis

Files owned by this contributor:

- `src/short_circuit_analysis.m`
- `src/equal_area_criterion.m`

```bash
git clone https://github.com/YOUR-USERNAME/ieee30-power-system-analysis.git
cd ieee30-power-system-analysis
git switch -c feature/fault-stability
```

Copy the two assigned files into `src/`, then:

```bash
git add src/short_circuit_analysis.m src/equal_area_criterion.m
git commit -m "Add fault and transient-stability analysis"
git push -u origin feature/fault-stability
```

Create a pull request from `feature/fault-stability` into `main`.

## 6. Merge the three independent pull requests

The repository owner should review and merge the pull requests one at a time. Because the three contributors own different files, normal merges should not create source-code conflicts.

After all three are merged locally:

```bash
git switch main
git pull origin main
```

## 7. Owner integration commit

The owner now adds the orchestration script:

```bash
git add src/main_analysis.m
git commit -m "Integrate complete IEEE 30-bus analysis workflow"
git push origin main
```

This commit connects the three independent work packages without assigning one contributor credit for another contributor's source files.

## 8. Run and verify the merged repository

In MATLAB, set the Current Folder to the repository root and run:

```matlab
run_project
```

Check that:

- Y-bus formation completes.
- Gauss-Seidel and Newton-Raphson complete or report their convergence status clearly.
- The six fault cases run.
- Figures are written to `results/figures/`.
- Any EAC warning or unresolved result is investigated before the repository is treated as a final technical reference.

Then make a small verification commit only if files genuinely changed:

```bash
git status
git add <only-the-files-you-intend-to-commit>
git commit -m "Verify merged analysis and update final outputs"
git push
```

## 9. Optional final release tag

When the repository is final:

```bash
git tag -a v1.0 -m "ELE4343 IEEE 30-bus final project"
git push origin v1.0
```
