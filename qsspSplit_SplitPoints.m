function varargout = qsspSplit_SplitPoints(lonRange, latRange, lonStep, latStep, nsplit, varargin)
%qsspGeneratePositions Generate positions for qssp, in (lat, lon) degrees
%   Input arguments:
%      - lonRange : [lonMin, lonMax], 2 element vector, [deg]
%                   if optional argument sparse_points_flag is true
%                   this is interpreted instead as a vector of spare points longitudes
%      - latRange : [latMin, latMax], 2 element vector, [deg]
%                   if optional argument sparse_points_flag is true
%                   this is interpreted instead as a vector of spare points latitudes
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
%      - optional: doParallelCalls flag
%                  true:   prepare a call script for gnu parallel,
%                          in the form:
%                          "ls ${filePrefix}_split_*.inp | parallel --verbose echo {1} '|' ${qsspbin}"
%                  false:  prepare a call script with
%                          semicolon-separated serial calls
%      - optional: qsspbin, binary of qsspstatic to be called
%                  e.g. if we have more than one version
%                  such as one re-compiled with different options
%                  for a larger number of receiver points
%                  defaults to 'qsspstatic'
%      - optional: create join script (defaul: true)
%                  set to false for GF computation calls
%      - optional: provide sparse points instead of grids
%                  (note that this requires different post-processing,
%                  with no reliance on calls to gmt xyz2grd)
%                  If this this (sparse_points_flag) is set to true,
%                  lonRange and latRange are interpreted as two
%                  same-length vectors defining the sparse points
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
% 2021-01-27, 2021-02-19, 2021-07-05, 2023-07-03 AP

narginchk(5,15)
nargoutchk(0,1)

if nargin>5 && ~isempty(varargin{1}) % optional output to filename
    outFilename = varargin{1};
    assert(ischar(outFilename) || isstring(outFilename),...
        'output filename must be type char or string');
else
    outFilename = [];
end

if ~isempty(outFilename) && nargin>6 % part of inp file to prepend and append
    assert(nargin>=8)
    PrependAppendFlag = true;
    prependFilename = varargin{2};
    appendFilename = varargin{3};
    assert(ischar(prependFilename) || isstring(prependFilename),...
        'prepend filename must be type char or string');
    assert(ischar(appendFilename) || isstring(appendFilename),...
        'append filename must be type char or string');
    assert(logical(exist(prependFilename, 'file')),...
        [prependFilename, ' does not exist or is not a file'])
    assert(logical(exist(appendFilename, 'file')),...
        [appendFilename, ' does not exist or is not a file'])
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
% a 'snapshot_names' function is provided
% to turn a vector of days in a cell array of 'day, name' rows
if nargin>9 && ~isempty(varargin{5})
    assert(iscell(varargin{5}),'customSnapshots must be provided as type cell');
    definedSnapshots = varargin{5};
else
    definedSnapshots = {0, 'coseis'};
end

% prefix of output files (those defined in the inp files)
if nargin>10 && ~isempty(varargin{6})
    assert(ischar(varargin{6}) || isstring(varargin{6}),...
        'filePrefix must be type char or string');
    filePrefix = varargin{6};
else
    filePrefix = '';
end

if nargin>11 && ~isempty(varargin{7})
    doParallelCalls = logical(varargin{7});
else
    doParallelCalls = false;
end

% qsspbin: which binary to call in the call script
% to do: from ampersand (&) to proper gnu parallel or alternative
if nargin>12 && ~isempty(varargin{8})
    assert(ischar(varargin{8}) || isstring(varargin{8}),...
        'qssbin must be type char or string');
    qsspbin = varargin{8};
else
    qsspbin = 'qsspstatic';
end

% create_join_script:
% write a Matlab script for calls to qsspSplit_JoinSplittedOutput
% (default: true)
if nargin>13 && ~isempty(varargin{9})
    create_join_script = logical(varargin{9});
else
    create_join_script = true;
end

if nargin>14 && ~isempty(varargin{10})
    sparse_points_flag = logical(varargin{10});
else
    sparse_points_flag = false;
end

if ~sparse_points_flag
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
else
    assert(length(lonRange) == length(latRange))
    numPoints = length(lonRange);
end

disp(['Total number of points: ', num2str(numPoints)]);
if numPoints>1e12 % max number of 'station id' characters is 12 (unlikely)
    disp('Warning: qsspsatic allows for max 12 char long station IDs');
    disp('         Therefore, using a sequential integer as station ID,');
    disp('         it will be longer than that.');
    disp('Possibile solution, not yet implemented: use alphanumeric ID.');
end

if ~sparse_points_flag
    % create meshgrids with all the (lat, lon) points defined by Lon and Lat
    [latMesh, lonMesh] = meshgrid(Lat, Lon);
    % perform -180/180 wrap of longitude
    lonMesh = wrapTo180(lonMesh);
    % TODO: wrap latitude, if below/above -90/+90 (less trivial than longitude)
    % numPoints by 2 array of (lat, lon) couples
    LatLon = [latMesh(:), lonMesh(:)];
else
    lonRange = wrapTo180(lonRange);
    LatLon = [latRange(:), lonRange(:)];
end

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
% last split: fill with remainder of points (<= nsplit)
splits{number_of_splits} = LatLon(nsplit * (number_of_splits-1) + 1 : end, :);

% format string for integers
% according to number of digits in number_of_splits, with leading zeros
number_of_splits_digits = ceil(log10(number_of_splits))+1;
% e.g. 200 splits -> intFmt is '%03d' -> 001, 002, ..., 200
intFmt = ['%0', num2str(number_of_splits_digits, '%d'), 'd'];

disp(['Number of splits: ', num2str(number_of_splits, '%d')])

if ~isempty(outFilename) && ~PrependAppendFlag
    % no input files to prepend and append provided
    % simply output the plaintext lat, lon pairs (using qsspstatic inp indentation)
    for n=1:number_of_splits
        outFilename_seq = [outFilename, '_', num2str(n, intFmt)];
        fprintf(['[', num2str(n, intFmt), '/', num2str(number_of_splits,intFmt), '] Writing out to ', outFilename_seq])
        fid=fopen(outFilename_seq, 'w');
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
        fid=fopen(outFilename_seq, 'a'); % append
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
                '  ''', filePrefix, 'displacement_', intFmt,...
                '''  ''', filePrefix, 'vstrain_', intFmt,...
                '''  ''', filePrefix, 'tilt_', intFmt,...
                '''  ''', filePrefix, 'gravity_', intFmt,...
                '''  ''', filePrefix, 'geoid_', intFmt, '''\n'], ...
            n, n, n, n, n);
        % snapshots definitions
        snapshot_number = size(definedSnapshots, 1);
        fprintf(fid, ['  ', num2str(snapshot_number),'\n']); % number of snapshots
        % definedSnapshots: snapshots along rows (first dimension)
        %                   columns: first is numberf of days,
        %                            second is label
        for snapshot_n=1:snapshot_number
            fprintf(fid, [...
                '     ', num2str(definedSnapshots{snapshot_n, 1}, '%f'),...
                '    ''', filePrefix, 'snap_', definedSnapshots{snapshot_n, 2},...
                '_', intFmt, '.dat''', '\n'], n);
        end
        fprintf(fid, '\n');
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
    % print script with required commands
    % (serial, list of calls separeted with ';',
    %  or call to gnu parallel, with pattern)
    fid=fopen([outFilename, '_launch.sh'], 'w');
    fprintf(fid, '#!/usr/bin/env bash\n');
    fprintf(fid, '# This file was automatically generated by qsspSplit_SplitPoints.m\n');
    fprintf(fid, '# Use this to call qsspstatic on all the splitted inp files.\n');
    if ~doParallelCalls % serial
        for n=1:number_of_splits
            fprintf(fid, '# Serial mode: semicolon separated calls.\n');
            fprintf(fid, ['printf "', [outFilename, '_split_', num2str(n, intFmt) , '.inp'],...
                '" | ', qsspbin, ';', '\n']);
        end
        fprintf(fid, 'echo "ALL DONE!"\n');
    else % gnu parallel, match-pattern call
        fprintf(fid, '# Parallel mode: call to gnu parallel.\n');
        fprintf(fid, [...
            'ls ', filePrefix, 'split_*.inp ',...
            '| parallel --verbose echo {1} ',...
            '''|'' ', qsspbin, '\n']);
    end
    fclose(fid);
    % print matlab call script for calls to qsspSplit_JoinSplittedOutput
    if create_join_script
        fid=fopen([outFilename, '_call_qsspJoin.m'], 'w');
        fprintf(fid, '%% This file was automatically generated by qsspSplit_SplitPoints.m\n');
        fprintf(fid, '%%    After qsspstatic has run on all splits, join them in one file\n');
        fprintf(fid, '%%    by calling qsspSplit_JoinSplittedOutput on all snapshots.\n');
        for snapshot_n=1:snapshot_number
            % arguments of qsspSplit_JoinSplittedOutput:
            % - 1st : path, same directory
            % - 2nd : pattern to search for: write snapshots filename before split number
            fprintf(fid, [...
                'qsspSplit_JoinSplittedOutput(''./'', ''',...
                filePrefix, 'snap_', definedSnapshots{snapshot_n, 2},'_',...
                ''');\n']);
        end
        fclose(fid);
    end
else
    % 'outFilename' not provided, do not write output to file
    % will return 'splits' as output argument (if requested)
    disp('No output filename provided, therefore nothing to write external files.')
end

if nargout==1
    varargout{1} = splits; % return LatLon to output argument, if called with one
end

end
