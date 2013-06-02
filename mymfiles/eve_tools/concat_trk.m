function concat_trk(trk_names,new_trk_name,cleanup)
%concat_trk.m

if nargin<3
    cleanup=0;
end

if ischar(trk_names)
    trk_names=cellstr(trk_names);
end

T=length(trk_names);

master_tracks=[]; ncount_master=0;

for t=1:T
    [header,tracks]=trk_read(trk_names{t});
    if ~isempty(header)
        master_tracks=horzcat(master_tracks, tracks);
        ncount_master=ncount_master+header.n_count;
    end
end


header.n_count=ncount_master;
trk_write(header,master_tracks,new_trk_name);

if cleanup==1
    for d=1:T
        delete(trk_names{d});
    end
end
end