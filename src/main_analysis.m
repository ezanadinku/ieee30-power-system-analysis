% IEEE 30-bus power-system study
% Power flow, three-phase fault analysis and equal-area stability study.

clearvars;
close all;
clc;

Sbase = 100;      % MVA
Vbase_kV = 132;   % kV line-to-line

project_root = fileparts(fileparts(mfilename('fullpath')));
figure_dir = fullfile(project_root, 'results', 'figures');
if ~isfolder(figure_dir)
    mkdir(figure_dir);
end

[bus_data, branch_data, gen_data] = ieee30_data();
n_bus = size(bus_data, 1);

fprintf('IEEE 30-bus study\n');
fprintf('Buses: %d, branches: %d, base: %.0f MVA / %.0f kV\n', ...
    n_bus, size(branch_data,1), Sbase, Vbase_kV);

%% Y-bus
Ybus = form_Ybus(bus_data, branch_data);

fprintf('\nFirst 10 Y-bus diagonal elements:\n');
for i = 1:min(10, n_bus)
    fprintf('Y(%2d,%2d) = %.4f < %.1f deg\n', ...
        i, i, abs(Ybus(i,i)), angle(Ybus(i,i))*180/pi);
end

%% Gauss-Seidel load flow
% The GS solver expects net demand in columns 3 and 4, so generator output
% is folded into those columns before the call.
bus_gs = bus_data;
for k = 1:size(gen_data, 1)
    bus = gen_data(k,1);
    if bus_data(bus,2) ~= 3
        bus_gs(bus,3) = bus_data(bus,3) - gen_data(k,2);
        bus_gs(bus,4) = bus_data(bus,4) - gen_data(k,3);
    end
end

tol_gs = 1e-5;
[V_gs, iter_gs, conv_gs, hist_gs] = ...
    gauss_seidel_pf(bus_gs, Ybus, Sbase, tol_gs, 500);
if ~conv_gs
    warning('Gauss-Seidel did not meet the requested tolerance.');
end

print_bus_results('Gauss-Seidel', V_gs, Ybus, Sbase);
total_loss_gs = branch_losses(V_gs, branch_data, Sbase, true);
fprintf('Total GS active-power loss: %.4f MW\n', total_loss_gs);

weak = find(abs(V_gs) < 0.95);
if isempty(weak)
    fprintf('No GS bus voltage is below 0.95 pu.\n');
else
    fprintf('GS buses below 0.95 pu: %s\n', mat2str(weak.'));
end

%% Newton-Raphson load flow
tol_nr = 1e-6;
[V_nr, iter_nr, conv_nr, hist_nr] = ...
    newton_raphson_pf(bus_data, gen_data, Ybus, Sbase, tol_nr, 50);
if ~conv_nr
    warning('Newton-Raphson did not meet the requested tolerance.');
end

print_bus_results('Newton-Raphson', V_nr, Ybus, Sbase);
total_loss_nr = branch_losses(V_nr, branch_data, Sbase, false);
fprintf('Total NR active-power loss: %.4f MW\n', total_loss_nr);

%% Power-flow figures
figure('Name','Bus Voltage Profile','Position',[100 100 1000 500]);
b = bar(1:n_bus, [abs(V_gs), abs(V_nr)], 'grouped');
b(1).FaceColor = [0.2 0.4 0.8];
b(2).FaceColor = [0.8 0.3 0.2];
hold on;
yline(0.95, 'r--', 'LineWidth', 1.5, 'Label', 'V_{min} = 0.95 pu');
yline(1.05, 'b--', 'LineWidth', 1.5, 'Label', 'V_{max} = 1.05 pu');
xlabel('Bus Number');
ylabel('Voltage Magnitude (pu)');
title('IEEE 30-Bus System - Bus Voltage Profiles: GS vs NR');
legend({'Gauss-Seidel','Newton-Raphson','V_{min}','V_{max}'}, ...
    'Location','southeast');
grid on;
ylim([0.90 1.10]);
saveas(gcf, fullfile(figure_dir, 'fig_voltage_profiles.png'));

figure('Name','GS Convergence','Position',[100 100 700 450]);
semilogy(1:numel(hist_gs), hist_gs, 'b-o', 'LineWidth', 1.8, 'MarkerSize', 4);
yline(tol_gs, 'r--', 'LineWidth', 1.5, 'Label', sprintf('Tol = %.0e', tol_gs));
xlabel('Iteration Number');
ylabel('Max |\DeltaV| (pu)');
title('Gauss-Seidel Convergence History');
grid on;
saveas(gcf, fullfile(figure_dir, 'fig_gs_convergence.png'));

figure('Name','NR Convergence','Position',[100 100 700 450]);
semilogy(1:numel(hist_nr), hist_nr, 'r-s', 'LineWidth', 1.8, 'MarkerSize', 6);
yline(tol_nr, 'r--', 'LineWidth', 1.5, 'Label', sprintf('Tol = %.0e', tol_nr));
xlabel('Iteration Number');
ylabel('Max Power Mismatch (pu)');
title('Newton-Raphson Convergence History');
grid on;
saveas(gcf, fullfile(figure_dir, 'fig_nr_convergence.png'));

figure('Name','Voltage Angles','Position',[100 100 1000 450]);
plot(1:n_bus, angle(V_gs)*180/pi, 'b-o', 'LineWidth', 1.8, ...
    'MarkerSize', 5, 'DisplayName', 'Gauss-Seidel');
hold on;
plot(1:n_bus, angle(V_nr)*180/pi, 'r-s', 'LineWidth', 1.8, ...
    'MarkerSize', 5, 'DisplayName', 'Newton-Raphson');
xlabel('Bus Number');
ylabel('Voltage Angle (degrees)');
title('IEEE 30-Bus - Voltage Phase Angles');
legend('Location','southwest');
grid on;
saveas(gcf, fullfile(figure_dir, 'fig_voltage_angles.png'));

%% Three-phase fault study
fault_buses = [1 5 10 15 22 29];
fault_labels = {'Bus 1 (Slack/Gen)', 'Bus 5 (Gen-PV)', ...
    'Bus 10 (Central-Cap)', 'Bus 15 (Load-Area)', ...
    'Bus 22 (Peripheral)', 'Bus 29 (Remote Load)'};
load_factors = [0.5 1.25];
Zf_values = [0 0.05];
fault_results = zeros(numel(fault_buses), 4);

fprintf('\nThree-phase fault-current comparison\n');
fprintf('%-22s %-12s %-12s %-12s %-12s\n', ...
    'Location', 'Min Zf=0', 'Min Zf=.05', 'Max Zf=0', 'Max Zf=.05');

for fidx = 1:numel(fault_buses)
    fbus = fault_buses(fidx);

    for lidx = 1:numel(load_factors)
        bus_scaled = bus_data;
        bus_scaled(:,3:4) = bus_data(:,3:4)*load_factors(lidx);

        % The original project uses a flat 1 pu pre-fault profile here.
        % short_circuit_analysis also accepts an NR voltage vector if a
        % load-dependent pre-fault study is required later.
        [If0, ~, ~] = short_circuit_analysis( ...
            bus_scaled, branch_data, fbus, Zf_values(1), Sbase, Vbase_kV);
        [Ifz, ~, ~] = short_circuit_analysis( ...
            bus_scaled, branch_data, fbus, Zf_values(2), Sbase, Vbase_kV);

        cols = (lidx-1)*2 + (1:2);
        fault_results(fidx, cols) = [If0.pu Ifz.pu];
    end

    fprintf('%-22s %-12.4f %-12.4f %-12.4f %-12.4f\n', ...
        fault_labels{fidx}, fault_results(fidx,:));
end

figure('Name','Fault Current Comparison','Position',[100 100 1000 550]);
b2 = bar(1:numel(fault_buses), fault_results, 'grouped');
b2(1).FaceColor = [0.8 0.2 0.2];
b2(2).FaceColor = [0.9 0.5 0.5];
b2(3).FaceColor = [0.2 0.4 0.8];
b2(4).FaceColor = [0.5 0.7 0.9];
xticks(1:numel(fault_buses));
xticklabels({'Bus 1','Bus 5','Bus 10','Bus 15','Bus 22','Bus 29'});
xlabel('Fault Location');
ylabel('Fault Current (pu)');
title('Three-Phase Fault Currents - Min & Max Loading, Zf=0 & Zf=0.05 pu');
legend({'Min Load, Zf=0','Min Load, Zf=0.05', ...
    'Max Load, Zf=0','Max Load, Zf=0.05'}, 'Location','northeast');
grid on;
saveas(gcf, fullfile(figure_dir, 'fig_fault_currents.png'));

bus_max = bus_data;
bus_max(:,3:4) = 1.25*bus_data(:,3:4);
[~, V_post_10, ~] = short_circuit_analysis( ...
    bus_max, branch_data, 10, 0, Sbase, Vbase_kV);

figure('Name','Post-Fault Voltages','Position',[100 100 1000 450]);
bar(1:n_bus, abs(V_post_10), 'FaceColor', [0.7 0.3 0.3]);
yline(0.95, 'b--', 'LineWidth', 1.5, 'Label', 'Normal V_{min}');
xlabel('Bus Number');
ylabel('Post-Fault Voltage Magnitude (pu)');
title('Post-Fault Bus Voltages - Three-Phase Fault at Bus 10 (Max Loading)');
grid on;
saveas(gcf, fullfile(figure_dir, 'fig_post_fault_voltages.png'));

%% Equal-area stability study for the Bus 2 generator
H = 5.0;
f0 = 60;
Xd_prime = 0.20;
Xe_pre = 0.10;
Xe_post = 0.20;
Xe_during = 0.50;
E_prime = 1.10;
V_inf = 1.00;
Pm = 0.40;

Pmax_pre = E_prime*V_inf/(Xd_prime + Xe_pre);
Pmax_during = E_prime*V_inf/(Xd_prime + Xe_during);
Pmax_post = E_prime*V_inf/(Xd_prime + Xe_post);
delta0_deg = asin(Pm/Pmax_pre)*180/pi;
t_clear = 0.15;

[delta_cr, tcr, stable] = equal_area_criterion( ...
    Pm, Pmax_pre, Pmax_post, Pmax_during, delta0_deg, ...
    H, f0, t_clear, figure_dir);

fprintf('\nEqual-area summary\n');
fprintf('Initial angle: %.2f deg\n', delta0_deg);
if isnan(delta_cr)
    fprintf('Critical clearing angle: not resolved by the supplied model.\n');
else
    fprintf('Critical clearing angle: %.2f deg\n', delta_cr*180/pi);
end
fprintf('Critical clearing time: %.4f s\n', tcr);
fprintf('Applied clearing time: %.4f s\n', t_clear);
if stable
    fprintf('Stability decision: STABLE\n');
else
    fprintf('Stability decision: UNSTABLE\n');
end

%% Final GS/NR comparison
fprintf('\nGS vs NR voltage comparison\n');
fprintf('%-5s %-11s %-11s %-12s %-12s\n', ...
    'Bus', 'V_GS', 'V_NR', 'Ang_GS', 'Ang_NR');
for i = 1:n_bus
    fprintf('%-5d %-11.4f %-11.4f %-12.4f %-12.4f\n', ...
        i, abs(V_gs(i)), abs(V_nr(i)), ...
        angle(V_gs(i))*180/pi, angle(V_nr(i))*180/pi);
end
fprintf('GS iterations: %d | NR iterations: %d\n', iter_gs, iter_nr);
fprintf('GS loss: %.4f MW | NR loss: %.4f MW\n', total_loss_gs, total_loss_nr);
fprintf('Figures saved in %s\n', figure_dir);

function print_bus_results(name, V, Ybus, Sbase)
fprintf('\n%s results\n', name);
fprintf('%-5s %-12s %-12s %-12s %-12s\n', ...
    'Bus', 'V (pu)', 'Angle (deg)', 'P inj (MW)', 'Q inj (MVAR)');
for i = 1:numel(V)
    Sinj = V(i)*conj(Ybus(i,:)*V)*Sbase;
    fprintf('%-5d %-12.4f %-12.4f %-12.4f %-12.4f\n', ...
        i, abs(V(i)), angle(V(i))*180/pi, real(Sinj), imag(Sinj));
end
end

function total_loss = branch_losses(V, branch_data, Sbase, print_rows)
total_loss = 0;
if print_rows
    fprintf('\n%-6s %-6s %-12s %-12s %-12s\n', ...
        'From', 'To', 'P from', 'Q from', 'Loss MW');
end

for k = 1:size(branch_data, 1)
    from = branch_data(k,1);
    to = branch_data(k,2);
    R = branch_data(k,3);
    X = branch_data(k,4);
    tap = branch_data(k,6);
    if tap == 0
        tap = 1;
    end

    z = R + 1j*X;
    if abs(z) < 1e-10
        continue;
    end

    Ift = (V(from)/tap - V(to))/z;
    Sft = V(from)*conj(Ift)*Sbase;
    Stf = V(to)*conj(-Ift)*Sbase;
    loss = real(Sft) + real(Stf);
    total_loss = total_loss + loss;

    if print_rows && abs(real(Sft)) > 0.01
        fprintf('%-6d %-6d %-12.3f %-12.3f %-12.4f\n', ...
            from, to, real(Sft), imag(Sft), loss);
    end
end
end
