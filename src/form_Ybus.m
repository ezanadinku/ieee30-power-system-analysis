function Ybus = form_Ybus(bus_data, branch_data)
%FORM_YBUS Build the bus-admittance matrix for the IEEE 30-bus case.

n_bus = size(bus_data, 1);
Ybus = complex(zeros(n_bus));

for k = 1:size(branch_data, 1)
    from = branch_data(k, 1);
    to   = branch_data(k, 2);
    R    = branch_data(k, 3);
    X    = branch_data(k, 4);
    B2   = branch_data(k, 5);
    tap  = branch_data(k, 6);

    if tap == 0
        tap = 1;
    end

    y = 1 / (R + 1j*X);
    y_sh = 1j * B2;

    % Off-nominal tap is assumed to be on the 'from' side.
    Ybus(from, from) = Ybus(from, from) + y/(tap^2) + y_sh;
    Ybus(to,   to)   = Ybus(to,   to)   + y + y_sh;
    Ybus(from, to)   = Ybus(from, to)   - y/tap;
    Ybus(to,   from) = Ybus(to,   from) - y/tap;
end

% Bus shunts are given on the 100 MVA system base.
for i = 1:n_bus
    Gs = bus_data(i, 5);
    Bs = bus_data(i, 6);
    Ybus(i, i) = Ybus(i, i) + (Gs + 1j*Bs)/100;
end

fprintf('Y-bus formed: %d buses, %d branches.\n', ...
    n_bus, size(branch_data, 1));
end
