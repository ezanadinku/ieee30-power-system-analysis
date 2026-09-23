function [If, V_post, Zth] = short_circuit_analysis(bus_data, branch_data, fault_bus, Zf, Sbase, Vbase_kV, V_prefault)
%SHORT_CIRCUIT_ANALYSIS Three-phase symmetrical fault using the Z-bus method.
%
%   If = V_prefault(f) / (Zbus(f,f) + Zf)
%   Vpost = V_prefault - Zbus(:,f)*If
%
%   V_prefault is optional. If it is omitted, a flat 1 pu profile is used,
%   matching the simplified fault study in the original project.

if nargin < 4 || isempty(Zf),       Zf = 0; end
if nargin < 5 || isempty(Sbase),    Sbase = 100; end
if nargin < 6 || isempty(Vbase_kV), Vbase_kV = 132; end

n_bus = size(bus_data, 1);
if nargin < 7 || isempty(V_prefault)
    V_prefault = ones(n_bus, 1);
end

if numel(V_prefault) ~= n_bus
    error('V_prefault must contain one complex voltage per bus.');
end
if fault_bus < 1 || fault_bus > n_bus || fault_bus ~= floor(fault_bus)
    error('fault_bus must be an integer between 1 and %d.', n_bus);
end

Ybus = form_Ybus(bus_data, branch_data);
Zbus = inv(Ybus);  % direct Z-bus formation for this small teaching case

Zth = Zbus(fault_bus, fault_bus);
If_complex = V_prefault(fault_bus) / (Zth + Zf);
V_post = V_prefault - Zbus(:, fault_bus) * If_complex;

Ibase_kA = (Sbase*1e6) / (sqrt(3)*Vbase_kV*1e3) / 1e3;
If.pu = abs(If_complex);
If.kA = If.pu * Ibase_kA;
If.angle_deg = angle(If_complex) * 180/pi;

fprintf('\n--- Three-phase fault at Bus %d (Zf = %.4f pu) ---\n', ...
    fault_bus, Zf);
fprintf('Zth = %.4f + j%.4f pu\n', real(Zth), imag(Zth));
fprintf('Fault current = %.4f pu = %.4f kA\n', If.pu, If.kA);

fprintf('%-6s %-12s %-12s\n', 'Bus', '|V| (pu)', 'Angle (deg)');
for i = 1:n_bus
    fprintf('%-6d %-12.4f %-12.4f\n', ...
        i, abs(V_post(i)), angle(V_post(i))*180/pi);
end
end
