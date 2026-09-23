function [V, iter, converged, mismatch_hist] = gauss_seidel_pf(bus_data, Ybus, Sbase, tol, max_iter)
%GAUSS_SEIDEL_PF Solve the load flow with the Gauss-Seidel method.
%   bus_data(:,3:4) are treated as net demand. The main script subtracts
%   generator injections at PV buses before calling this function.

if nargin < 3 || isempty(Sbase),   Sbase = 100; end
if nargin < 4 || isempty(tol),     tol = 1e-5; end
if nargin < 5 || isempty(max_iter), max_iter = 200; end

n_bus = size(bus_data, 1);
bus_type = bus_data(:, 2);
Vset = bus_data(:, 7);

Psch = -bus_data(:, 3) / Sbase;
Qsch = -bus_data(:, 4) / Sbase;

% Use specified magnitudes for slack/PV buses and a flat start for PQ buses.
V = Vset .* exp(1j * bus_data(:, 8) * pi/180);
V(bus_type == 1) = 1 + 0j;

converged = false;
mismatch_hist = zeros(max_iter, 1);

fprintf('\n=== Gauss-Seidel Load Flow ===\n');
fprintf('%-8s %-15s\n', 'Iter', 'Max |DeltaV|');

for iter = 1:max_iter
    V_old = V;

    for i = 1:n_bus
        if bus_type(i) == 3
            continue;  % slack bus
        end

        yv_other = Ybus(i,:) * V - Ybus(i,i) * V(i);

        if bus_type(i) == 1
            Ssch = Psch(i) + 1j*Qsch(i);
            V(i) = (conj(Ssch)/conj(V(i)) - yv_other) / Ybus(i,i);

        elseif bus_type(i) == 2
            % Estimate Q from the current state, update the angle, then
            % restore the specified PV-bus voltage magnitude.
            Scalc = V(i) * conj(Ybus(i,:) * V);
            Ssch = Psch(i) + 1j*imag(Scalc);
            Vnew = (conj(Ssch)/conj(V(i)) - yv_other) / Ybus(i,i);
            V(i) = Vset(i) * exp(1j*angle(Vnew));
        end
    end

    max_dV = max(abs(V - V_old));
    mismatch_hist(iter) = max_dV;

    if iter == 1 || mod(iter, 10) == 0
        fprintf('%-8d %-15.6e\n', iter, max_dV);
    end

    if max_dV < tol
        converged = true;
        mismatch_hist = mismatch_hist(1:iter);
        break;
    end
end

if ~converged
    mismatch_hist = mismatch_hist(1:iter);
end

if converged
    fprintf('Gauss-Seidel converged in %d iterations (tol = %.1e).\n', iter, tol);
else
    fprintf('Gauss-Seidel did not converge within %d iterations.\n', max_iter);
end
end
