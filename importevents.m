function eventsdefinitions = importevents(filename)

dataLines = [2, Inf];

%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 12);

% Specify range and delimiter
opts.DataLines = dataLines;
opts.Delimiter = ",";

% Specify column names and types
% TODO: assert for actual VariableNames in header row
opts.VariableNames = ["event_name", "mag", "scalarMoment", "time", "longitude", "latitude", "depth", "Mrr", "Mtt", "Mpp", "Mrt", "Mrp", "Mtp", "url"];
opts.VariableTypes = ["string", "double", "double", "string", "double", "double", "double", "double", "double", "double", "double", "double", "double", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["event_name", "time"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["event_name", "time"], "EmptyFieldRule", "auto");

% Import the data
eventsdefinitions = readtable(filename, opts);

eventsdefinitions.Properties.RowNames = eventsdefinitions.event_name;

%% if magnitude is missing (not populated in quakeml), compute it from scalar moment
for n = 1:size(eventsdefinitions, 1)
    if isnan(eventsdefinitions(n, :).mag)
        eventsdefinitions(n, :).mag = ...
            (2 / 3) * log10(eventsdefinitions(n, :).scalarMoment * 1e7) - 10.7;
    end
end

%% time string to datetime
% TODO

%% compute a 'M unit' for each event and convert depths to km
% (this is a factor that scales all Mij values)
% use the largest power of ten
eventsdefinitions.Munit = ones(size(eventsdefinitions, 1), 1);
for n = 1:size(eventsdefinitions, 1)
    max_Mij_abs = max(abs([ ...
        eventsdefinitions(n, :).Mrr, eventsdefinitions(n, :).Mtt, ...
        eventsdefinitions(n, :).Mpp, eventsdefinitions(n, :).Mrt, ...
        eventsdefinitions(n, :).Mrp, eventsdefinitions(n, :).Mtp]));
    eventsdefinitions(n, :).Munit = 10^(floor(log10(max_Mij_abs)));
    % divide all Mij by Munit
    eventsdefinitions(n, :).Mrr = eventsdefinitions(n, :).Mrr / eventsdefinitions(n, :).Munit;
    eventsdefinitions(n, :).Mtt = eventsdefinitions(n, :).Mtt / eventsdefinitions(n, :).Munit;
    eventsdefinitions(n, :).Mpp = eventsdefinitions(n, :).Mpp / eventsdefinitions(n, :).Munit;
    eventsdefinitions(n, :).Mrt = eventsdefinitions(n, :).Mrt / eventsdefinitions(n, :).Munit;
    eventsdefinitions(n, :).Mrp = eventsdefinitions(n, :).Mrp / eventsdefinitions(n, :).Munit;
    eventsdefinitions(n, :).Mtp = eventsdefinitions(n, :).Mtp / eventsdefinitions(n, :).Munit;
    % depth: m to km
    eventsdefinitions(n, :).depth = eventsdefinitions(n, :).depth * 1e-3;
end

end