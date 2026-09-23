function [delta_cr, tcr, stable] = equal_area_criterion(Pm, Pe_max_pre, Pe_max_post, Pe_max_during, delta0_deg, H, f0, t_clear, output_dir)
%EQUAL_AREA_CRITERION Equal-area transient-stability calculation for an SMIB model.
%   delta_cr is returned in radians. tcr and t_clear are in seconds.

if nargin < 6 || isempty(H),       H = 5.0; end
if nargin < 7 || isempty(f0),      f0 = 60; end
if nargin < 8 || isempty(t_clear), t_clear = 0.1; end
if nargin < 9 || isempty(output_dir), output_dir = pwd; end

ws = 2*pi*f0;
delta0 = delta0_deg*pi/180;

% Check the supplied initial angle against the pre-fault equilibrium.
delta0_calc = asin(Pm/Pe_max_pre);
if abs(delta0_deg - delta0_calc*180/pi) > 5
    fprintf('Warning: supplied delta0 differs from the pre-fault equilibrium.\n');
    delta0 = delta0_calc;
end

fprintf('\n=== Equal Area Criterion Analysis ===\n');
fprintf('Pm = %.4f pu\n', Pm);
fprintf('Pmax (pre/fault/post) = %.4f / %.4f / %.4f pu\n', ...
    Pe_max_pre, Pe_max_during, Pe_max_post);
fprintf('Initial rotor angle = %.2f deg\n', delta0*180/pi);

if Pm > Pe_max_post
    fprintf('No post-fault equilibrium exists because Pm > Pmax_post.\n');
    delta_cr = NaN;
    tcr = NaN;
    stable = false;
    return;
end

delta_stable_post = asin(Pm/Pe_max_post);
delta_max = pi - delta_stable_post;

% Area expressions used in the submitted project calculation.
delta_grid = linspace(delta0, delta_max, 10000);
A1 = Pm*(delta_grid - delta0) + ...
    Pe_max_during*(cos(delta0) - cos(delta_grid));
A2 = Pe_max_post*(cos(delta_grid) - cos(delta_max)) - ...
    Pm*(delta_max - delta_grid);

area_diff = A1 - A2;
idx = find(area_diff >= 0, 1, 'last');
if isempty(idx) || idx >= numel(delta_grid)
    fprintf('A critical clearing angle was not found for these parameters.\n');
    delta_cr = NaN;
    tcr = NaN;
    stable = false;
    return;
end

delta_cr = delta_grid(idx);
fprintf('Critical clearing angle = %.2f deg\n', delta_cr*180/pi);

% Integrate the fault-on swing equation with a 1 ms time step.
dt = 1e-3;
t_max = 2.0;
delta = delta0;
omega = 0;
t = 0;
tcr = NaN;

n_steps = floor(t_max/dt) + 1;
t_hist = zeros(n_steps, 1);
delta_hist = zeros(n_steps, 1);
k = 0;

while t <= t_max
    k = k + 1;
    t_hist(k) = t;
    delta_hist(k) = delta*180/pi;

    if delta > delta_max
        break;
    end

    Pe = Pe_max_during*sin(delta);
    omega = omega + (ws/(2*H))*(Pm - Pe)*dt;
    delta = delta + omega*dt;

    if isnan(tcr) && delta >= delta_cr
        tcr = t;
    end

    t = t + dt;
end

t_hist = t_hist(1:k);
delta_hist = delta_hist(1:k);

if isnan(tcr)
    tcr = t_max;
end

stable = t_clear <= tcr;
fprintf('Critical clearing time = %.4f s\n', tcr);
fprintf('Applied clearing time  = %.4f s -> %s\n', ...
    t_clear, ternary_label(stable));

% Power-angle plot.
delta_plot = linspace(0, pi, 500);
figure('Name', 'Equal Area Criterion', 'Position', [100 100 900 600]);
hold on;
plot(delta_plot*180/pi, Pe_max_pre*sin(delta_plot), 'b-', ...
    'LineWidth', 2, 'DisplayName', 'Pre-fault');
plot(delta_plot*180/pi, Pe_max_during*sin(delta_plot), 'r--', ...
    'LineWidth', 1.8, 'DisplayName', 'During fault');
plot(delta_plot*180/pi, Pe_max_post*sin(delta_plot), 'g-', ...
    'LineWidth', 2, 'DisplayName', 'Post-fault');
plot(delta_plot*180/pi, Pm*ones(size(delta_plot)), 'k-', ...
    'LineWidth', 1.5, 'DisplayName', 'P_m');

fill1 = linspace(delta0, delta_cr, 200);
fill([fill1, fliplr(fill1)]*180/pi, ...
    [Pm*ones(size(fill1)), fliplr(Pe_max_during*sin(fill1))], ...
    'r', 'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
    'DisplayName', 'A_1');

fill2 = linspace(delta_cr, delta_max, 200);
fill([fill2, fliplr(fill2)]*180/pi, ...
    [Pe_max_post*sin(fill2), fliplr(Pm*ones(size(fill2)))], ...
    'g', 'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
    'DisplayName', 'A_2');

xline(delta0*180/pi, 'k:', 'Label', '\delta_0');
xline(delta_cr*180/pi, 'm:', 'Label', '\delta_{cr}');
xline(delta_max*180/pi, 'k:', 'Label', '\delta_{max}');
xlabel('Rotor Angle \delta (degrees)');
ylabel('Power (pu)');
title('Equal Area Criterion - Generator at Bus 2');
legend('Location', 'northeast');
grid on;
xlim([0 200]);
saveas(gcf, fullfile(output_dir, 'fig_equal_area.png'));

% Fault-on swing curve.
figure('Name', 'Swing Curve', 'Position', [100 100 800 500]);
plot(t_hist, delta_hist, 'b-', 'LineWidth', 2);
hold on;
yline(delta_cr*180/pi, 'r--', 'Label', '\delta_{cr}');
yline(delta_max*180/pi, 'k--', 'Label', '\delta_{max}');
xlabel('Time (s)');
ylabel('Rotor Angle \delta (degrees)');
title('Fault-on Swing Curve - Generator at Bus 2');
grid on;
saveas(gcf, fullfile(output_dir, 'fig_swing_curve.png'));
end

function label = ternary_label(condition)
if condition
    label = 'STABLE';
else
    label = 'UNSTABLE';
end
end
