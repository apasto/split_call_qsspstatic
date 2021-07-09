function splits = qsspSplit_SplitPoints(lonRange, latRange, lonStep, latStep, nsplit, varargin)
%qsspGeneratePositions Generate positions for qssp, in (lat, lon) degrees
%   Input arguments:
%      - lonRange : [lonMin, lonMax], 2 element vector, [deg]
%      - latRange : [latMin, latMax], 2 element vector, [deg]
%      - lonStep : interval between samples along longitude, [deg]
%      - latStep : interval between samples along latitude, [deg]
%      - nsplit : how many maximum points in each split? (can be empty, results in no splitting)
%      - optional: outFilename, where to write (lat, lon, ID) rows for qssp
%                  it begins with a header line with the total number of points
%                  it includes a sequential 'split number'.
%      - optional (two arguments to be provided together)
%                  - prependFilename
%                  - appendFilename
%       with part of the qssp inp file to be prepended and appended before
%       and after the points, with the following structure
%       [prepended file, stop after the 'output parameters' comments
%       "  1    0.0  0.0"
%       "  1               1           1       1          1" (may be set to 0 by 'noTimeSeries' optional argument)
%       "  'displacement_[SPLIT NUMBER]'  'vstrain_[SPLIT NUMBER]'  'tilt_[SPLIT NUMBER]'  'gravity_[SPLIT NUMBER]'  'geoid_[SPLIT NUMBER]'"
%       "  1" (number of output snapshots)
%       "     0.0    'snap_coseis_[SPLIT NUMBER].dat'"
%       ""
%       "  [number of receiver points here]"
%       "    [lat  lon  ID of each point in split]"
%      - optional: no time series option (only snapshot)
%      - optional: custom snapshots, provided as a cell array
%                  with snapshots along 1st dimension (rows)
%                  1st column is time in days
%                  2nd column is a label, will be placed in filename
%      - optional: prefix for time series and snapshot files
%      - optional: flag, write call script for concurrent (parallel) calls
%       
%       NOTE: the 'prepend' part should have the 'calculate green functions'
%             switch turned off! (important for concurrent istances)
%             Therefore, perform one run (e.g. with fewer points)
%             to compute them (is point distance important?)
%             (maybe it is wise to compute 4 receivers covering all the
%             lon/lat extents.
%       
%       NOTE: .dat output of 'modified' rheology model gets overwritten
%             should check if it is the same in all model runs?
%
%       NOTE: due to issues with CR/LF vs LF endline character
%             save appendFilename as a Unix-type endline (LF only)
%             (this is probably a trivial issue to fix)
%
%   Output arguments:
%      - LatLon: cell array, each element an array with a (lat, lon) couple each row
%
% 2021-01-27, 2021-02-19, 2021-07-05 AP

narginchk(5,12)
nargoutchk(0,1)

if nargin>5 && ~isempty(varargin{1}) % optional output to filename
    outFilename = varargin{1};
    assert(ischar(outFilename) || isstring(outFilename),...
        'output filename must be type char or string');
else
    outFilename = [];
end

if nargin>6 % part of inp file to prepend and append
    assert(nargin>=8)
    PrependAppendFlag = true;
    prependFilename = varargin{2};
    appendFilename = varargin{3};
    assert(ischar(prependFilename) || isstring(prependFilename),...
        'prepend filename must be type char or string');
    assert(ischar(appendFilename) || isstring(appendFilename),...
        'append filename must be type char or string');
    assert(logical(exist(prependFilename, 'file')))
    assert(logical(exist(appendFilename, 'file')))
else
    PrependAppendFlag = false;
end

% 'noTimeSeries', no-time-series option
% if we are only interested in snapshots
if nargin>8 && ~isempty(varargin{4})
    noTimeSeries = logical(varargin{4});
else
    noTimeSeries = false;
end

% optional: instead of coseismic snapshot only
% provide days and name of the requested snapshots (as a cell array)
% e.g. to get this:
%   6
%     -1.0    'snap_final_[SPLIT NUMBER].dat'
% 	 0.0    'snap_coseis_[SPLIT NUMBER].dat'
% 	 30.0   'snap_1month_[SPLIT NUMBER].dat'
% 	 60.0   'snap_2month_[SPLIT NUMBER].dat'
% 	 365.0  'snap_1year_[SPLIT NUMBER].dat'
% 	 730.0  'snap_2year_[SPLIT NUMBER].dat'
% provide this:
% {...
%     -1, 'final';...
%     0, 'coseis';...
%     30, '1month';...
%     60, '2month';...
%     365, '1year';...
%     730, '2year'}
if nargin>9 && ~isempty(varargin{5})
    assert(iscell(varargin{5}),'customSnapshots must be provided as type cell');
    customSnapshots = varargin{5};
    customSnapshotsFlag = true;
else
    customSnapshotsFlag = false;
end

% prefix of output files (those defined in the inp files)
if nargin>10 && ~isempty(varargin{6})
    assert(ischar(varargin{6}) || isstring(varargin{6}),...
        'filePrefix must be type char or string');
    filePrefix = varargin{6};
else
    filePrefix = '';
end

% serial (;) or parallel (&) calls in call script
% to do: from ampersand (&) to proper gnu parallel or alternative
if nargin>10 && ~isempty(varargin{7})
    doParallelCalls = logical(varargin{7});
else
    doParallelCalls = false;
end
% select the shell script separator between calls accordingly
if doParallelCalls
    callSeparator = '&';
else
    callSeparator = ';';
end

assert(length(lonRange(:))==2)
assert(length(latRange(:))==2)
assert(lonRange(2) - lonRange(1)>=0)
assert(latRange(2) - latRange(1)>=0)
assert(isscalar(lonStep))
assert(isscalar(latStep))

% vectors of sampled longitudes and latitudes
Lon = lonRange(1):lonStep:lonRange(2);
Lat = latRange(1):lonStep:latRange(2);

% print actual lon and lat range
% ('stop' lon and lat may not be reached with imposed step,
%  but regular grid structure is more important than range coverage)
disp(['Actual lon range : min=', num2str(Lon(1)), '°, max=', num2str(Lon(end)), '°']);
disp(['Actual lat range : min=', num2str(Lat(1)), '°, max=', num2str(Lat(end)), '°']);

numLon = numel(Lon);
numLat = numel(Lat);
numPoints = numLon * numLat;
disp(['Total number of points: ', num2str(numPoints)]);
if numPoints>1e12 % max number of 'station id' characters is 12 (unlikely)
    disp('Warning: qsspsatic allows for max 12 char long station IDs');
    disp('         Therefore, using a sequential integer as station ID,');
    disp('         it will be longer than that.');
    disp('Possibile solution, not yet implemented: use alphanumeric ID.');
end

% create meshgrids with all the (lat, lon) points defined by Lon and Lat
[latMesh, lonMesh] = meshgrid(Lat, Lon);

% numPoints by 2 array of (lat, lon) couples
LatLon = [latMesh(:), lonMesh(:)];

strLonLatFormat = '%12.8f'; % fprintf format for conversion

% perform split according to nsplit
if isempty(nsplit) % empy nsplit = no splitting (i.e. one split)
    number_of_splits = 1;
    nsplit = numPoints;
else
    number_of_splits = ceil(numPoints / nsplit);
end

if nsplit>301 % max number of points in standard qsspstatic
    disp('Warning: standard qsspstatic allows for a maximum of 301 points');
    disp(['         ', num2str(nsplit), ' points-per-split are being requested']);
end

splits = cell(1, number_of_splits);
for n=1:(number_of_splits - 1)
    splits{n} = LatLon(nsplit * (n-1) + 1 : nsplit * n, :);
end
splits{number_of_splits} = LatLon(nsplit * (number_of_splits-1) + 1 : end, :);

intFmt = '%03d'; % format string for integers
% to do: adequate number of leading zeros with digits of number_of_splits

disp(['Number of splits: ', num2str(number_of_splits, '%d')])

if ~isempty(outFilename) && ~PrependAppendFlag
    % no input files to prepend and append provided
    % simply output the plaintext lat, lon pairs (using qsspstatic inp indentation)
    for n=1:number_of_splits
        outFilename_seq = [outFilename, '_', num2str(n, intFmt)];
        fprintf(['[', num2str(n, intFmt), '/', num2str(number_of_splits,intFmt), '] Writing out to ', outFilename_seq])
        fid=fopen(outFilename_seq, 'wt'); % t option: CR LF endline (DOS)
        % write number of points (indentation: 2 spaces)
        fprintf(fid, '  %i\n', size(splits{n}, 1));
        % write lat, lon pairs (indentation: 4 spaces)
        for row=1:size(splits{n}, 1)
            fprintf(fid, ['    ', strLonLatFormat, ' ', strLonLatFormat, ' ''%i'' \n'], splits{n}(row,:), row);
        end
        fclose(fid);
        disp(' done.')
    end
elseif ~isempty(outFilename) && PrependAppendFlag
    % input files to prepend and append were provided, use them
    toBeAppended = fileread(appendFilename);
    for n=1:number_of_splits
        outFilename_seq = [outFilename, '_split_', num2str(n, intFmt) , '.inp'];
        copyfile(prependFilename, outFilename_seq); % copy part to be prepended
        fprintf(['[', num2str(n, intFmt), '/', num2str(number_of_splits, intFmt), '] Writing out to ', outFilename_seq])
        fid=fopen(outFilename_seq, 'at'); % append, t option: CR LF endline (DOS)
        % write preamble, with output files for qssp
        fprintf(fid, '\n  1    0.0  0.0\n'); % NEEDS to start with a newline
        % timeseries on/off flag (spacing as in original template)
        fprintf(fid, [...
            '  ', num2str(noTimeSeries),...
            '               ', num2str(noTimeSeries),...
            '           ', num2str(noTimeSeries),...
            '       ', num2str(noTimeSeries),...
            '          ', num2str(noTimeSeries), '\n']);
        % timeseries filenames (may be used or not, according to 'noTimeSeries')
        % note: escaping of quotes, this: "''' '''" becomes "' '"
        %       (double quotes excluded, uses as delimiters in this example)
        fprintf(fid, ...
            [...
                '  ', filePrefix, 'displacement_', intFmt,...
                '''  ''', filePrefix, 'vstrain_', intFmt,...
                '''  ''', filePrefix, 'tilt_', intFmt,...
                '''  ''', filePrefix, 'gravity_', intFmt,...
                '''  ''', filePrefix, 'geoid_', intFmt, '''\n'], ...
            n, n, n, n, n);
        % snapshots: only coseismic or custom snapshot are provided
        if ~customSnapshotsFlag
            fprintf(fid, '  1\n'); % number of snapshots
            fprintf(fid, ['     0.0    ', filePrefix, 'snap_coseis_', intFmt, '.dat', '\n'], n);
            fprintf(fid, '\n');
        else
            snapshot_number = size(customSnapshots, 1);
            fprintf(fid, ['  ', num2str(snapshot_number),'\n']); % number of snapshots
            % customSnapshots: snapshots along rows (first dimension)
            % along columns: first is numberf of days, second is label
            for snapshot_n=1:snapshot_number
                fprintf(fid, [...
                    '     ', num2str(customSnapshots{snapshot_n, 1}),...
                    '    ', filePrefix, 'snap_', customSnapshots{snapshot_n, 2},...
                    '_', intFmt, '.dat', '\n'], n);
            end
            fprintf(fid, '\n');
        end
        % write number of points (indentation: 2 spaces)
        fprintf(fid, '  %i\n', size(splits{n}, 1));
        % write lat, lon pairs (indentation: 4 spaces)
        for row=1:size(splits{n}, 1)
            fprintf(fid, ['    ', strLonLatFormat, ' ', strLonLatFormat, ' ''%i'' \n'], splits{n}(row,:), row);
        end
        % write part to be appended
        fprintf(fid,'%s',toBeAppended);
        fclose(fid);
        disp(' done.')
    end
    % print script with required commands (in serie with ';', alternative is '&' parallel)
    fid=fopen([outFilename, '_launch.sh'], 'w');
    for n=1:number_of_splits
        fprintf(fid, ['printf "', [outFilename, '_split_', num2str(n, intFmt) , '.inp'], '" | qsspstatic_bigmem', callSeparator, '\n']);
    end
    if doParallelCalls % 'wait' command after all '&'-separated calls
        fprintf(fid, 'wait\n');
    end
    fprintf(fid, 'echo "ALL DONE!"\n');
    fclose(fid);
else
    % 'outFilename' not provided, do not write output to file
    % will return 'splits' as output argument (if requested)
    disp('No output filename provided, therefore nothing to write external files.')
end

end
