function qsspSplit_JoinSplittedOutput(ReadPath,varargin)
%qsspSplit_JoinSplittedOutput Join splitted output files of qssp, after qsspSplit_SplitPoints
%   Finds all output files in the provided path, according to the pattern:
%   [filename_prefix, '*.DAT]
%   then reads each one of them with QSSPsnapshot2table
%   and concatenates them in one table.
%   The joined output is saved in a .mat file,
%   suitable for inport into plotting functions.

%   Input arguments:
%      - ReadPath : Path to search output files in.
%                   Joined file will be written there (in mat format)
%      - (optional) filename_prefix : default: 'snap_coseis_'
%                                     Part of filename of splitted output
%                                     files before sequential numbers.
%      The saved joined mat file (one table) keeps the same prefix:
%      [filename_prefix, 'all.mat']
%   
% 2021-02-19 AP

narginchk(1,2)

% optional argument: filename prefix (before sequential numbers)
% also defines output filename: [filename_prefix, 'all.mat']
if nargin==2
    filename_prefix = varargin{1};
    assert(ischar(filename_prefix) || isstring(filename_prefix),...
        'filename prefix must be type char or string');
else
    filename_prefix = 'snap_coseis_'; % default
end

%% read all files matching pattern
SnapshotList = struct2cell(dir([ReadPath, filename_prefix, '*.dat']));
SnapshotList = SnapshotList(1, :); % names only
SnapshotCount = size(SnapshotList, 2); % number of files
SnapshotCount_digits = ceil(log10(SnapshotCount))+1; % digits of SnapshotCount
SnapshotCount_fmt = ['%0',num2str(SnapshotCount_digits,'%i'),'i']; % format string for num2str
SnapshotCount_str = num2str(SnapshotCount,SnapshotCount_fmt);

Snapshot_in = cell(1,SnapshotCount);

for n=1:SnapshotCount
    fprintf([...
        'Reading file ',...
        num2str(n, SnapshotCount_fmt),...
        ' of ', SnapshotCount_str,...
        ' : ', char(SnapshotList(1, n))]);
    Snapshot_in{n} = QSSPsnapshot2table([ReadPath, char(SnapshotList(1, n))]);
    fprintf([' done. (', num2str(size(Snapshot_in{n}, 1),'%04i'), ' rows)\n']);
end

%% concatenate snapshots

fprintf(['Concatenating ',num2str(SnapshotCount, '%i'), ' files... '])
Snapshot_all = Snapshot_in{1}; % first table
for n=2:size(Snapshot_in, 2) % concatenate one-by-one the other tables
    Snapshot_all = vertcat(Snapshot_all, Snapshot_in{n}); %#ok<AGROW>
end
fprintf(' done.\n')

%% save concatenated
OutFilename = [ReadPath, filename_prefix, 'all.mat'];
save(OutFilename, 'Snapshot_all');
disp(['Joined data saved in: ', OutFilename])
disp(['   Total receivers: ', num2str(size(Snapshot_all, 1), '%i')])
disp('Call to qsspSplit_JoinSplittedOutput done.');

end
