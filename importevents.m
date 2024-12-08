function eventsdefinitions = importevents(filename, varargin)

narginchk(1, 2);

dataLines = [2, Inf];

% optional argument: type of data:
%   moment tensor provided or double-coupled defined with angles
if nargin > 1
    events_kind = lower(varargin{1});
else
    % default to moment tensor
    events_kind = 'moment';
end

switch events_kind
    case 'moment'
        num_variables = 12;
        variable_names =  ["event_name", "mag", "scalarMoment", ...
            "time", "longitude", "latitude", "depth", ...
            "Mrr", "Mtt", "Mpp", "Mrt", "Mrp", "Mtp", ...
            "url"];
        variable_types = ["string", "double", "double", ...
            "string", "double", "double", "double", ...
            "double", "double", "double", "double", "double", "double", ...
            "string"];
    case 'doublecouple'
        num_variables = 12;
        variable_names =  ["event_name", "mag", "scalarMoment", ...
            "time", "longitude", "latitude", "depth", ...
            "strike", "dip", "rake", ...
            "url"];
        variable_types = ["string", "double", "double", ...
            "string", "double", "double", "double", ...
            "double", "double", "double", ...
            "string"];
    otherwise
        error(["Invalid events format provided: '", events_kind,"'"]);
end

%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", num_variables);

% Specify range and delimiter
opts.DataLines = dataLines;
opts.Delimiter = ",";

% Specify column names and types
% TODO: assert for actual VariableNames in header row
opts.VariableNames = variable_names;
opts.VariableTypes = variable_types;

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

if strcmp(events_kind, 'moment')
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
    end
end

% depth: m to km
for n = 1:size(eventsdefinitions, 1)
    eventsdefinitions(n, :).depth = eventsdefinitions(n, :).depth * 1e-3;
end

end