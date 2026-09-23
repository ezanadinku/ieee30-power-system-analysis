function [V, iter, converged, mismatch_hist] = newton_raphson_pf(bus_data, gen_data, Ybus, Sbase, tol, max_iter)
%NEWTON_RAPHSON_PF Newton-Raphson load flow in polar coordinates.

if nargin < 4 || isempty(Sbase),    Sbase = 100; end
if nargin < 5 || isempty(tol),      tol = 1e-6; end
if nargin < 6 || isempty(max_iter), max_iter = 50; end

n_bus = size(bus_data, 1);
bus_type = bus_data(:, 2);
Vset = bus_data(:, 7);

% Scheduled net injections, in per-unit.
Psch = -bus_data(:, 3) / Sbase;
Qsch = -bus_data(:, 4) / Sbase;
for k = 1:size(gen_data, 1)
    bus = gen_data(k, 1);
    Psch(bus) = Psch(bus) + gen_data(k, 2)/Sbase;
    Qsch(bus) = Qsch(bus) + gen_data(k, 3)/Sbase;
end

Vmag = Vset;
theta = zeros(n_bus, 1);
G = real(Ybus);
B = imag(Ybus);

pq = find(bus_type == 1);
pv = find(bus_type == 2);
pvpq = [pv; pq];
n_pq = numel(pq);
n_pvpq = numel(pvpq);

converged = false;
mismatch_hist = zeros(max_iter, 1);

fprintf('\n=== Newton-Raphson Load Flow ===\n');
fprintf('%-8s %-20s %-20s\n', 'Iter', 'Max |DP| (pu)', 'Max |DQ| (pu)');

for iter = 1:max_iter
    Pcalc = zeros(n_bus, 1);
    Qcalc = zeros(n_bus, 1);

    for i = 1:n_bus
        for j = 1:n_bus
            dtheta = theta(i) - theta(j);
            Pcalc(i) = Pcalc(i) + Vmag(i)*Vmag(j) * ...
                (G(i,j)*cos(dtheta) + B(i,j)*sin(dtheta));
            Qcalc(i) = Qcalc(i) + Vmag(i)*Vmag(j) * ...
                (G(i,j)*sin(dtheta) - B(i,j)*cos(dtheta));
        end
    end

    dP = Psch - Pcalc;
    dQ = Qsch - Qcalc;
    dP(bus_type == 3) = 0;
    dQ(bus_type ~= 1) = 0;

    max_dP = max(abs(dP));
    max_dQ = max(abs(dQ));
    max_mismatch = max(max_dP, max_dQ);
    mismatch_hist(iter) = max_mismatch;

    fprintf('%-8d %-20.6e %-20.6e\n', iter, max_dP, max_dQ);

    if max_mismatch < tol
        converged = true;
        mismatch_hist = mismatch_hist(1:iter);
        break;
    end

    % Jacobian blocks: J1=dP/dtheta, J2=dP/dV,
    % J3=dQ/dtheta, J4=dQ/dV.
    J = zeros(n_pvpq + n_pq);

    for a = 1:n_pvpq
        i = pvpq(a);
        for b = 1:n_pvpq
            j = pvpq(b);
            if i == j
                J(a,b) = -Qcalc(i) - B(i,i)*Vmag(i)^2;
            else
                dtheta = theta(i) - theta(j);
                J(a,b) = Vmag(i)*Vmag(j) * ...
                    (G(i,j)*sin(dtheta) - B(i,j)*cos(dtheta));
            end
        end
    end

    for a = 1:n_pvpq
        i = pvpq(a);
        for b = 1:n_pq
            j = pq(b);
            col = n_pvpq + b;
            if i == j
                J(a,col) = Pcalc(i)/Vmag(i) + G(i,i)*Vmag(i);
            else
                dtheta = theta(i) - theta(j);
                J(a,col) = Vmag(i) * ...
                    (G(i,j)*cos(dtheta) + B(i,j)*sin(dtheta));
            end
        end
    end

    for a = 1:n_pq
        i = pq(a);
        row = n_pvpq + a;
        for b = 1:n_pvpq
            j = pvpq(b);
            if i == j
                J(row,b) = Pcalc(i) - G(i,i)*Vmag(i)^2;
            else
                dtheta = theta(i) - theta(j);
                J(row,b) = -Vmag(i)*Vmag(j) * ...
                    (G(i,j)*cos(dtheta) + B(i,j)*sin(dtheta));
            end
        end
    end

    for a = 1:n_pq
        i = pq(a);
        row = n_pvpq + a;
        for b = 1:n_pq
            j = pq(b);
            col = n_pvpq + b;
            if i == j
                J(row,col) = Qcalc(i)/Vmag(i) - B(i,i)*Vmag(i);
            else
                dtheta = theta(i) - theta(j);
                J(row,col) = Vmag(i) * ...
                    (G(i,j)*sin(dtheta) - B(i,j)*cos(dtheta));
            end
        end
    end

    correction = J \ [dP(pvpq); dQ(pq)];
    theta(pvpq) = theta(pvpq) + correction(1:n_pvpq);
    Vmag(pq) = Vmag(pq) + correction(n_pvpq+1:end);
    Vmag(pv) = Vset(pv);
end

if ~converged
    mismatch_hist = mismatch_hist(1:iter);
end

if converged
    fprintf('Newton-Raphson converged in %d iterations (tol = %.1e).\n', iter, tol);
else
    fprintf('Newton-Raphson did not converge within %d iterations.\n', max_iter);
end

V = Vmag .* exp(1j*theta);
end
