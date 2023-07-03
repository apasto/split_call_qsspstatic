function customSnapshots = snapshot_names(customSnapshots_days)
% customSnapshots_days: days (not necessarily integer) to define snapshots at
% if days < 0 => days = -1 and name = 'final'
narginchk(1, 1)
nargoutchk(0, 1)

% snapshot names convention: 'day'd'hours'h
% (days: 5 digits, hours: 2 digits, both are zero padded)
customSnapshots = cell(length(customSnapshots_days), 2);
for s=1:length(customSnapshots_days)
    if customSnapshots_days(s) >= 0
        % snapshot days (decimal days)
        customSnapshots{s, 1} = customSnapshots_days(s);
        % snapshot name
        customSnapshots{s, 2} = [ ...
            num2str(floor(customSnapshots_days(s)), '%05d'), 'd', ...
            num2str(round(mod(customSnapshots_days(s), 1)), '%02d'), 'h'];
    else  % final
        customSnapshots{s, 1} = -1;
        customSnapshots{s, 2} = '99999d00h';
    end
end
end