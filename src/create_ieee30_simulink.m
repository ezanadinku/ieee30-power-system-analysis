function create_ieee30_simulink()
%CREATE_IEEE30_SIMULINK Build the block layout for an IEEE 30-bus model.
%   The script uses native Simscape Electrical blocks. Block parameter names
%   can vary between MATLAB releases, so unsupported settings are skipped and
%   can be completed from the Property Inspector.

model_name = 'IEEE30_SLD';
if bdIsLoaded(model_name)
    close_system(model_name, 0);
end

new_system(model_name);
open_system(model_name);
set_param(model_name, ...
    'SolverType', 'Variable-step', ...
    'Solver', 'ode23t', ...
    'StopTime', '0.1', ...
    'RelTol', '1e-4', ...
    'AbsTol', '1e-6');

[bus_data, branch_data, gen_data] = ieee30_data();

Sbase = 100e6;
Vbase_kV = 132;
Vbase = Vbase_kV*1e3;
f0 = 60;
Zbase = Vbase^2/Sbase;
Ybase = 1/Zbase;

% Approximate canvas positions for the 30 buses.
layout = [
     1,130,130;   2,420,130;   3,280,310;   4,420,310;   5,730,130;
     6,590,310;   7,730,310;   8,870,310;   9,590,480;  10,810,480;
    11,520,600;  12,1020,310; 13,1020,480; 14,1160,310; 15,1160,480;
    16,1300,310; 17,1300,480; 18,1160,640; 19,1160,800; 20,1020,800;
    21,990,640;  22,1050,640; 23,1430,640; 24,1450,800; 25,1570,640;
    26,1690,800; 27,1570,480; 28,870,400;  29,1690,640; 30,1690,480
];
bus_xy = zeros(30, 2);
for k = 1:size(layout, 1)
    bus_xy(layout(k,1), :) = layout(k,2:3);
end

% Solver and electrical reference blocks.
solver = [model_name '/Solver Configuration'];
add_block('nesl_utility/Solver Configuration', solver, ...
    'Position', [30 30 250 80]);
try_set_param(solver, 'DoDC', 'on');

reference = [model_name '/Grounded Neutral'];
add_block('ee_lib/Connectors & References/Grounded Neutral', reference, ...
    'Position', [30 110 160 150]);

% Busbars.
for bus = 1:30
    x = bus_xy(bus,1);
    y = bus_xy(bus,2);
    path = sprintf('%s/Busbar_%02d', model_name, bus);

    add_block('ee_lib/Connectors & References/Busbar', path, ...
        'Position', [x y x+60 y+40]);
    try_set_param(path, 'RatedVoltage', num2str(Vbase));
    try_set_param(path, 'Frequency', num2str(f0));
end

% Generator/load-flow source blocks.
for k = 1:size(gen_data, 1)
    bus = gen_data(k,1);
    x = bus_xy(bus,1);
    y = bus_xy(bus,2);
    path = sprintf('%s/Gen_Bus%02d', model_name, bus);

    add_block('ee_lib/Sources/Load Flow Source', path, ...
        'Position', [x-220 y-15 x-70 y+35]);

    if bus == 1
        source_type = 'Swing bus';
    else
        source_type = 'PV bus';
    end

    try_set_param(path, 'SourceType', source_type);
    try_set_param(path, 'RatedVoltage', num2str(Vbase));
    try_set_param(path, 'TerminalVoltage', num2str(gen_data(k,6)));
    try_set_param(path, 'ActivePower', num2str(gen_data(k,2)*1e6));
    try_set_param(path, 'Frequency', num2str(f0));
end

% Branches that are represented as transformer blocks in the project model.
transformer_pairs = [6 9; 6 10; 9 11; 12 13; 28 27];

for k = 1:size(branch_data, 1)
    from = branch_data(k,1);
    to   = branch_data(k,2);
    R    = branch_data(k,3);
    X    = branch_data(k,4);
    B2   = branch_data(k,5);
    tap  = branch_data(k,6);

    x1 = bus_xy(from,1); y1 = bus_xy(from,2);
    x2 = bus_xy(to,1);   y2 = bus_xy(to,2);
    xm = round((x1+x2)/2);
    ym = round((y1+y2)/2);

    is_transformer = any(all(transformer_pairs == [from to], 2)) || ...
        any(all(transformer_pairs == [to from], 2));

    if is_transformer
        if tap == 0
            tap = 1;
        end

        path = sprintf('%s/TF_%d_%d', model_name, from, to);
        add_block('ee_lib/Passive/Two-Winding Transformer (Three-Phase)', ...
            path, 'Position', [xm-75 ym-35 xm+75 ym+35]);

        R_ohm = max(R, 1e-4)*Zbase;
        L_H = max(X, 1e-4)*Zbase/(2*pi*f0);

        try_set_param(path, 'Winding1Voltage', num2str(Vbase));
        try_set_param(path, 'Winding2Voltage', num2str(Vbase*tap));
        try_set_param(path, 'WindingResistance', num2str(R_ohm));
        try_set_param(path, 'LeakageInductance', num2str(L_H));
        try_set_param(path, 'Frequency', num2str(f0));
    else
        if abs(R) < 1e-12 && abs(X) < 1e-12
            continue;
        end

        path = sprintf('%s/Line_%d_%d', model_name, from, to);
        add_block('ee_lib/Passive/Transmission Line (Three-Phase)', ...
            path, 'Position', [xm-85 ym-30 xm+85 ym+30]);

        R_ohm = R*Zbase;
        L_H = X*Zbase/(2*pi*f0);
        C_F = max(2*B2*Ybase/(2*pi*f0), 0);

        try_set_param(path, 'Length', '1');
        try_set_param(path, 'Resistance', num2str(R_ohm));
        try_set_param(path, 'Inductance', num2str(L_H));
        try_set_param(path, 'Capacitance', num2str(C_F));
        try_set_param(path, 'Frequency', num2str(f0));
    end
end

% Loads.
for bus = 1:30
    Pd = bus_data(bus,3);
    Qd = bus_data(bus,4);
    if Pd < 0.01 && abs(Qd) < 0.01
        continue;
    end

    x = bus_xy(bus,1);
    y = bus_xy(bus,2);
    path = sprintf('%s/Load_Bus%02d', model_name, bus);

    add_block('ee_lib/Passive/Wye-Connected Load', path, ...
        'Position', [x+110 y+90 x+240 y+140]);
    try_set_param(path, 'ActivePower', num2str(Pd*1e6));
    try_set_param(path, 'ReactivePower', num2str(Qd*1e6));
    try_set_param(path, 'Voltage', num2str(Vbase));
    try_set_param(path, 'Frequency', num2str(f0));
end

save_system(model_name, [model_name '.slx']);
fprintf('Created %s.slx.\n', model_name);
fprintf('The blocks still need to be wired and any skipped parameters checked in the Property Inspector.\n');
end

function try_set_param(block_path, parameter, value)
% Set a block parameter only when it exists in the installed MATLAB release.
try
    set_param(block_path, parameter, value);
catch
    % Parameter names differ between some Simscape Electrical releases.
end
end
