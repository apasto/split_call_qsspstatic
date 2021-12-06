function CallSplit_createCallShellScripts(common_eqName, eqNames, varargin)
%CallSplit_createCallShellScripts create script with calls, serial, to all the call scripts
%
% 2021-07-20 Alberto
% 2021-11-27 Alberto: add pre-computation of GF, optional

narginchk(2,3)

if nargin==2
    do_GF_precomp = false;
    dirNames_GF = [];
else
    do_GF_precomp = true;
    dirNames_GF = varargin{1};
end

LaunchScriptFileName = ['Launch_', common_eqName, '.sh'];
LogFileNamePrefix = ['Log_', common_eqName];
fid=fopen(LaunchScriptFileName, 'w');
fprintf(fid, '#!/usr/bin/env bash\n');
fprintf(fid, '# This call script was automatically generated\n');
fprintf(fid, ['# by ', mfilename, '\n']);
fprintf(fid, ['# on ', datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS'), '\n']);
% create complete log filename: append call date
% date '+%Y%m%dT%H%M%S'
fprintf(fid, ['LogFile="$(pwd)/', LogFileNamePrefix, '_$(date ''+%%Y%%m%%dT%%H%%M%%S'')"\n']);
% try touching log file, quit if fails, then write call date
fprintf(fid, 'touch ${LogFile} || exit 1\n');
fprintf(fid, 'echo "Called on $(date -R)" > ${LogFile}\n');

% pre-computation of GF, if required
if do_GF_precomp
    % prepare these as gnu parallel call to all launch scripts
    fprintf(fid, 'echo "Pre-computation of GF requested, taking care of that first." > ${LogFile}\n');
    % create a list of files, to be fed to gnu parallel
    gf_joblist_filename = ['Launch_', common_eqName, '_GF_comp_list'];
    % as 'parallel :::: list_filename'
    gf_joblist_fid = fopen(gf_joblist_filename, 'w');
    for n=1:size(dirNames_GF, 2)
        % single launch scripts are are in '${dir_name}/${dir_name}_launch.sh'
        fprintf(gf_joblist_fid, [...
            'cd ', dirNames_GF{n}, '; bash ', './', dirNames_GF{n}, '_launch.sh\n']);
    end
    fprintf(fid, 'echo "GF computation started on $(date -R)" >> ${LogFile}\n'); % log start
    fprintf(fid, 'subStartTime=$(date +%%s)\n'); % store start time, to compute duration
    fprintf(fid, ['parallel :::: ', gf_joblist_filename, ';\n']);
    fprintf(fid, 'echo "GF computation ended on $(date -R)" >> ${LogFile}\n'); % log when done
    fprintf(fid, 'echo "    time elapsed: $(date -ud "@$(($(date +%%s) - $subStartTime))" +%%T) (HH:MM:SS)" >> ${LogFile}\n'); % duration
end

% ordinary part
for n=1:size(eqNames, 2)
    fprintf(fid, ['cd ', eqNames{n},' || exit 1\n']);
    % one call for the close range, then one for the global range
    % the former has no prefix, the second starts with 'WIDE'
    for rangeString={'', 'WIDE_'}
        fprintf(fid, ['echo "', rangeString{1}, eqNames{n},' started on $(date -R)" >> ${LogFile}\n']); % log start
        fprintf(fid, 'subStartTime=$(date +%%s)\n'); % store start time, to compute duration
        fprintf(fid, ['bash ./', rangeString{1}, eqNames{n}, '_launch.sh', ';\n']);
        fprintf(fid, ['echo "', rangeString{1}, eqNames{n},' ended on $(date -R)" >> ${LogFile}\n']); % log when done
        fprintf(fid, 'echo "    time elapsed: $(date -ud "@$(($(date +%%s) - $subStartTime))" +%%T) (HH:MM:SS)" >> ${LogFile}\n'); % duration
    end
    fprintf(fid, 'cd .. || exit 1\n');
end

% log when done
fprintf(fid, 'echo "Finished on $(date -R)" >> ${LogFile}\n');
fprintf(fid, 'echo "ALL DONE!"\n');
fclose(fid);
end

