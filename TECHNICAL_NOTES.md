# Technical notes from the repository cleanup

These notes are included so the public repository does not silently hide differences between the submitted report and the supplied source files.

1. **Branch count:** an earlier source matrix contained a duplicated `28-8` branch and then truncated the matrix to 40 rows. The cleaned data file stores only the 40 branches actually used by the project.

2. **Short-circuit loading cases:** the supplied fault routine uses a flat 1.0 pu pre-fault voltage unless a voltage vector is supplied. Since changing `Pd` and `Qd` does not change the network Y-bus, minimum- and maximum-loading fault-current bars can overlap in the simplified calculation. The cleaned routine has an optional `V_prefault` argument so a future study can pass the Newton-Raphson voltage solution for each loading condition.

3. **Equal Area Criterion:** the report and source contain numerical/method inconsistencies in the critical-clearing calculation. The cleanup intentionally avoids inventing a replacement result. The EAC section should be independently rechecked before the repository is used as a technical reference or publication artifact.
