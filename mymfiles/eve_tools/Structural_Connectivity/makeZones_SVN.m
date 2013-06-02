function [ZonesFileName, MaskSurfFileName, MaskTrackingFileName, Zones, Mask_Surf, size_voxel, dim_mask] = makeZones_SVN(NumZones,AtlasFile,AtlasName,Mask_Contrast,Mask_White,OutPath)

%%Amy rewrote line 152 to accommodate for paths with spaces in the name
%AR mods: apparently AtlasFile refers to text file, and AtlasName to actual .img file of Atlas...
% Usage : [Zones, Mask_Surf] = makeZones(NumZones,AtlasFile,AtlasName,Mask_Contrast,Mask_White,OutPath)
%
% Description: This function, using a file (.txt or .cod file) whit names of
%              ordered gray matter zones, a three dimensional image of gray
%              matter Atlas and a three dimensional probabilistic image of
%              white and gray matter, create a file Zones.mat that for each
%              area contains the name, the number, the coordinates of the
%              points and the coordinates of the external points. Also, it is
%              calculed a three dimensional mask that only possesses the
%              points of white matter and the external points of the defined
%              gray matter zones.
%
% Input Parameters:
%        NumZones : Number of zones to be defined.
%
% Output Parameters:
%        Zones    : struct file of fields: 'name' (name of the zones),
%                   'voxels' (coordinates of the zones), 'number'(number of
%                   the zones in the Atlas File) and 'roi' (coordinates of
%                   the external points of the zones). This variable will
%                   be saved in a chosen directory.
%        Mask     : three-dimensional matrix that expresses the presence
%                   of white or gray matter in each point. It only
%                   possesses the points of white matter and the external
%                   points of the defined gray matter zones. It will be
%                   saved as image 'Mask_forTracking.img' in the
%                   chosen directory.
%--------------------------------------------------------------------------
% Authors: Yasser Iturria Medina & Pedro Vald�s-Hern�ndez
% Neuroimaging Department
% Cuban Neuroscience Center
% November 15th 2005
% Version $1.0
% Whittled down and amended for her own purposes by E. LoCastro

Zones = struct('name',[],'voxels',[],'number',[],'roi',[]);

[ptha,fna,ext] = fileparts(AtlasName);
%%Reading Atlas:
AtlasVol = spm_vol(AtlasName);
if strcmp(ext,'.img')
    AtlasVol.pinfo = [1;0;0];
end
rAtlas = floor(spm_read_vols(AtlasVol));
[pth,nam,ext] = fileparts(AtlasName);

%%Reading Masks:
Mget = spm_vol(Mask_Contrast);
if strcmp(ext,'.img')
    Mget.pinfo = [1;0;0];
end
Mask_contrast = spm_read_vols(Mget);

WMget = spm_vol(Mask_White);
dim_mask = WMget.dim;
if strcmp(ext,'.img')
    WMget.pinfo = [1;0;0];
end
size_voxel = sqrt(sum(WMget.mat(1:3,1:3).^2));
WM = spm_read_vols(WMget);
ind_WM = find(WM); clear WM

%% creating vector of directions to neighbors
[Y, Z, X] = meshgrid(-1:1, -1:1, -1:1);
vec = [X(:) Y(:) Z(:)];
ind = find(vec(:, 1) ~= 0 | vec(:, 2) ~= 0 | vec(:, 3) ~= 0);
dir_Vecinos = vec(ind, :);
n_vecinos = size(dir_Vecinos, 1);
clear X Y Z vec ind
dir_Vecinos = reshape(dir_Vecinos,[1 3 26]);

Mask_Surf = zeros(dim_mask);

atlist=ReadInTxt(AtlasFile);

for i = 1:NumZones
    disp([num2str(i) ' -> ' num2str(NumZones)]);
    name = deblank(atlist(i,:));
    C=textscan(name,'%[^=] %*c %[^\n]');
    Zones(i).name = C{2}{1};
    Zones(i).number = str2num(C{1}{1});
    ind_Region = nonzeros(find(round(rAtlas) == Zones(i).number));
    [x y z] = ind2sub(dim_mask,ind_Region);
    Zones(i).voxels = [x y z];
  
    if ~isempty(ind_Region),
        P = zeros(dim_mask); P(ind_Region) = 1;
        P = imfill(P,'holes');
        ind = find((x <= 1) | (y <= 1) | (z <= 1)); x(ind) = []; y(ind) = []; z(ind) = [];
        ind = find((x > dim_mask(1)-1) | (y > dim_mask(2)-1) | (z > dim_mask(3)-1)); x(ind) = []; y(ind) = []; z(ind) = [];
        xc = single([min(x)-1:max(x)+1]');
        yc = single([min(y)-1:max(y)+1]');
        zc = single([min(z)-1:max(z)+1]');
        [meshx,meshy,meshz]=meshgrid(xc,yc,zc);
        P=permute(P,[2 1 3]); %disp(P(min(yc):max(yc),min(xc):max(xc),min(zc):max(zc)));
        fv=isosurface(meshx,meshy,meshz,P(min(yc):max(yc),min(xc):max(xc),min(zc):max(zc)),0,'verbose');
        clear meshx meshy meshz;
        vertices = round(fv.vertices);
        Zones(i).roi = vertices;
        ind_Surface = sub2ind(dim_mask,vertices(:,1),vertices(:,2),vertices(:,3));
        Mask_Surf(ind_Surface) = 1;
    end
end

%eval(['save ' OutPath '\Zones.mat Zones size_voxel']);
ZonesFileName = [OutPath filesep 'Zones' num2str(NumZones) '.mat'];
save(ZonesFileName,'Zones', 'size_voxel');

%%Mask with Gray Matter Surfaces:
MaskSurfFileName = [OutPath filesep 'Mask_Surfaces' num2str(NumZones) ext];
WMget.fname = MaskSurfFileName;
spm_write_vol(WMget,Mask_Surf);

%%Mask for Tracking:
Mask_Surf(ind_WM) = 1;
ind = find(Mask_Surf);
Mask_Surf(ind) = 1;
Mask_Surf = Mask_Surf.*Mask_contrast;
MaskTrackingFileName = [OutPath filesep 'Mask_forTracking' num2str(NumZones) ext];
WMget.fname = MaskTrackingFileName;
WMget.dt(1) = 16;
spm_write_vol(WMget,Mask_Surf);
return

function [I,IB] = Iso_Rem(T,Nhood);
%
%This function removes isolated points from white matter mask.
%
% Input Parameters:
%   T            : White Matter  Mask
%   Nhood        : Minimun number of neighbors.
% Output Parameters:
%   I            : White Matter Mask without isolated points
%__________________________________________________________________________
% Authors:  Yasser Alem�nn G�mez
% Neuroimaging Department
% Cuban Neuroscience Center
% Last update: November 15th 2005
% Version $1.0

warning off
ind = find(T);
T = zeros(size(T));
T(ind) = 1;
I = zeros(size(T)+2);
I(2:end-1,2:end-1,2:end-1) = T;
clear T
ind = find(I>0);
[x,y,z] = ind2sub(size(I), ind);
s = size(x,1);
sROI = zeros(size(I));
[X, Y, Z] = meshgrid(-1:1,-1:1,-1:1);
X = X(:);Y = Y(:);Z = Z(:);
Neib = [X Y Z];clear X Y Z;
pos = find((Neib(:,1)==0)&(Neib(:,2)==0)&(Neib(:,3)==0));
Neib(pos,:) = [];
indbt = 0;
for i =1:26
    M = Neib(i,:);
    S = [x y z] + M(ones(s,1),:);
    ind2 = sub2ind(size(I),S(:,1),S(:,2),S(:,3));
    sROI(ind) = sROI(ind) + I(ind2);
    indb = find(I(ind2)==0);
    indt = sub2ind(size(I),x(indb),y(indb),z(indb));
    indbt = [indbt; indt];
end
ind = indbt(2:end,1);
indb = unique(ind);
IB = zeros(size(I));
IB(indb) = 1;
ind = find(sROI<Nhood);
I(ind) = 0;
IB(ind) = 0;
I = I(2:end-1,2:end-1,2:end-1);
IB = IB(2:end-1,2:end-1,2:end-1);
return;

