%% Render for NCS proposal
%
% Renders the simple scene with a factorial set of scalings, translations,
% and rotations fo the blue guy.
%
% Some work done to move the scaled guys down so their feet just touch the
% floor.
%

%% History
%    01/19/21  dhb  Wrote it.
%    01/20/21  dhb  Commented more fully.
%    01/24/21  dhb  Output to local/NCSRenderOut in repository.

%% Initialize
clear; close all; ieInit;
if ~piDockerExists, piDockerConfig; end

%% Find directory this file runs in and set up output
[a,b] = fileparts(which(mfilename));
outputFilePath = fullfile(a,'..','local','NCSRenderNicole');
if (~exist(outputFilePath,'dir'))
    mkdir(outputFilePath)
end

%% Read simple base scene and get rid of some extraneous stuff, and render
sceneName = 'simple scene';
thisR = piRecipeDefault('scene name', sceneName);
FASTRENDER = true;
if (FASTRENDER)
    thisR.set('film resolution',[200 150]);
    thisR.set('rays per pixel',40);
    thisR.set('nbounces',2);
else
    thisR.set('film resolution',[800 600]);
    thisR.set('rays per pixel',1000);
    thisR.set('nbounces',7);
end
thisR.set('fov',25);

% Get the subtree under the black mirror branch and chop it off
thisAssetName = 'mirror_B';
id = thisR.get('asset', thisAssetName, 'id');
mirrorSubtree = thisR.assets.subtree(id);
[~, mirrorSubtree] = mirrorSubtree.stripID([], true);
thisR.assets = thisR.assets.chop(id);

% Get rid of the piece of glass that's in there too
thisAssetName = 'glass_B';
id = thisR.get('asset', thisAssetName, 'id');
mirrorSubtree = thisR.assets.subtree(id);
[~, mirrorSubtree] = mirrorSubtree.stripID([], true);
thisR.assets = thisR.assets.chop(id);

% Render, show and save
sceneGamma = 0.6;
piWrite(thisR);
scene = piRender(thisR, 'render type', 'radiance');
sceneWindow(scene);
sceneSet(scene, 'gamma', sceneGamma);

% Fill up scene window?
SCENE_WINDOW = false;

% Get rgb.  This only works if you first show in sceneWindow above.
%
% Calling sceneShowImage replaces the image in the scene window with the
% passed scene. It doesn't appear to update the label. There may be a
% better way to get the rgb image for writing out to an image file, but
% this works.
%
% Using a gamma renders the hdr a bit better into the image file. For
% experiments would do a more careful job of rendering from the underlying
% hyperspectal image contained in the scene.
%
% Scaling to max for each image is also a shortcut OK for here, but is a
% shortcut. For experiments would be careful to do a common scaling across
% the whole ensemble of images.
rgb = sceneShowImage(scene,1,sceneGamma);
rgb = rgb/max(rgb(:));
imwrite(rgb,fullfile(outputFilePath,'BaseScene.tiff'),'tif');

% Get the spatial x, y and z coordinate images.  Didn't end up using these,
% but they could be useful for a more precise attempt to move objects in
% the scene around.
GETXYZ = false;
if (GETXYZ)
    [coords] = piRender(thisR, 'render type','coordinates');
    figure; imagesc(coords(:,:,1)); title('X coordinates');
    figure; imagesc(coords(:,:,2)); title('Y coordinates');
    figure; imagesc(coords(:,:,3)); title('Z coordinates');
end

% Find blue guy pixels. The mesh map lets us find the
% pixels for every mesh (aka object).  But we have to
% look at them to figure out which is which.  Set
% DETERMINE_BLUEGUY to true here to have the code loop
% through and let you look at an image of one mesh at
% a time - hit space bar to advance through.  The title of the figure window tells you 
% the corresponding mesh index number.
% Once this is done, set the flag to false and enter
% the mesh index just at the end of the loop.  The mesh
% index does seem to stay the same through the manipulations
% we do in this script.
[meshMap] = piRender(thisR,'renderType','mesh');
DETERMINE_BLUEGUY = false;
if (DETERMINE_BLUEGUY)
    meshIndices = unique(meshMap);
    figure;
    for ii = 1:length(meshIndices)
        oneObjectMeshMap = zeros(size(meshMap));
        oneObjectMeshMap(meshMap == meshIndices(ii)) = 1;
        imshow(oneObjectMeshMap);
        title(sprintf('Mesh index %d\n',meshIndices(ii)));
        pause
    end
end
blueGuyMeshIndex = 1;
[minX,minY,maxX,maxY,blueGuyHeight,blueGuyWidth] = FindMeshExtent(thisR,blueGuyMeshIndex);

%% Blue guy leaf asset name
assetName = 'figure_3m_O';

%% Scale and translate in crossed fashion
%
% The three lists below give the rotations (in degrees)
% translations (in scene units), and scalings (fraction)
% to be applied.
%
% At present the scalings need to be less than 1, because
% of the way we figure out how much to translate the scaled
% figure down so that its feet are still on the floor.  This
% could be fixed pretty easily, the problem is that with a 
% scaling greater than 1, the feet are not visible after
% the scaling, and the code assumes that they are.
theScales = [0.75 0.8 0.85];
theTranslates = [-0.05 0 0.05];
theRotates = [-10 -5 0 5 10 ];
for ss = 1:length(theScales)
    theScale = theScales(ss);
    for tt = 1:length(theTranslates)
        theTranslate = theTranslates(tt);
        for rr = 1:length(theRotates)
            theRotate = theRotates(rr);
            
            % Scale the blue guy figure
            thisR_S = thisR.copy;
            thisR_S.set('asset', assetName, 'scale', theScale);
            piWrite(thisR_S);
            scene = piRender(thisR_S, 'render type', 'radiance');
            scene = sceneSet(scene, 'name', 'Raw Scale');
            if (SCENE_WINDOW), sceneWindow(scene); end
            rgb = sceneShowImage(scene,1,sceneGamma); rgb = rgb/max(rgb(:));
            
            % Find extent of the scaled blue guy. This is done in the
            % subroutine by rendering the mesh map and finding the vertical
            % and horizontal extent of the blue guy image.
            %
            % The function FindMeshExtent is at the bottom of this file.
            % It makes its own local copy of the recipe so doesn't affect
            % the version worked with at this level.
            [minX_S,minY_S,maxX_S,maxY_S,blueGuyHeight_S,blueGuyWidth_S] = FindMeshExtent(thisR_S,blueGuyMeshIndex);
            desiredTranslationPixels = minY-minY_S;
            
            % Figure out relation between pixels and translation units and
            % get desired translation.  We do this by translating the blue
            % guy a known number of translation units and seeing how far it
            % went in pixels.
            %
            % The function CalibrateVerticalTranslation is at the end of
            % this file, and uses its own local copy of the passed recipe.
            calibrateTranslationStep = 1;
            pixelsPerTranslationUnit = CalibrateVerticalTranslation(thisR_S,assetName,blueGuyMeshIndex,calibrateTranslationStep);
            desiredTranslation = desiredTranslationPixels/pixelsPerTranslationUnit;
            
            % Now translate the scaled figure down by the amount calculated
            % above, to put its feet back on the floor. Because we do this
            % calculation in the image plane, it's not entirely exact.  But
            % it seems to work well.  Deciding precisely what it means to
            % scale an object and leave it in the same position is tricky,
            % both conceptually and in terms of how best to do it
            % automatically in the code.
            thisR_ST = thisR_S.copy;
            blueManTranslateAsset = thisR_ST.get('asset parent id',assetName);
            thisR_ST.set('asset', blueManTranslateAsset, 'translate', [0 desiredTranslation 0]);
            piWrite(thisR_ST);
            scene = piRender(thisR_ST, 'render type', 'radiance');
            scene = sceneSet(scene, 'name', 'Scaled on floor');
            if (SCENE_WINDOW), sceneWindow(scene); end
            rgb = sceneShowImage(scene,1,sceneGamma); rgb = rgb/max(rgb(:));
            
            % Check extent and position.  This lets us verify that the
            % bottom of the feet are in about the right place.
            [minX_ST,minY_ST,maxX_ST,maxY_ST,blueGuyHeight_ST,blueGuyWidth_ST] = FindMeshExtent(thisR_ST,blueGuyMeshIndex);
            
            % Translate laterally. This operation does not seem to commute
            % with the rotation operation below. If you rotate first, the
            % axes along which the translation happen seem to rotate too.
            thisR_ST.set('asset', blueManTranslateAsset, 'translate', [theTranslate, 0, 0]);
            piWrite(thisR_ST);
            scene = piRender(thisR_ST, 'render type', 'radiance');
            scene = sceneSet(scene, 'name', 'Lateral Translate');
            if (SCENE_WINDOW), sceneWindow(scene); end
            rgb = sceneShowImage(scene,1,sceneGamma); rgb = rgb/max(rgb(:));
            
            % Finally, rotate
            blueManAsset = thisR_ST.get('asset',assetName);
            thisR_ST.set('asset', blueManAsset.name, 'rotate', [0, theRotate, 0]);
            piWrite(thisR_ST);
            scene = piRender(thisR_ST, 'render type', 'radiance');
            scene = sceneSet(scene, 'name', 'Rotated');
            if (SCENE_WINDOW), sceneWindow(scene); end
            rgb = sceneShowImage(scene,1,sceneGamma); rgb = rgb/max(rgb(:));
            
            % Write final image out with a name that tells us how it was
            % transformed.  Order is scaling (*100), translation (*100),
            % rotation.
            imwrite(rgb,fullfile(outputFilePath,sprintf('Scene_%d_%d_%d.tiff',round(100*theScale),round(100*theTranslate),theRotate)),'tif');
            
            % Report. This printout tells us things about how well the
            % repositioning worked.  Could save the relevant variables each
            % time the loop for a fuller analysis at the end.
            fprintf('Original blue guy height: %d, width: %d\n',blueGuyHeight,blueGuyWidth);
            fprintf('Scaled blue guy height: %d, width: %d\n',blueGuyHeight_S,blueGuyWidth_S);
            fprintf('Predicted scaled blue guy height: %d, width: %d\n',round(theScale*blueGuyHeight),round(theScale*blueGuyWidth));
            fprintf('Original blue guy low point: %d\n',minY);
            fprintf('Scaled blue guy low point: %d\n',minY_S);
            fprintf('Predicted scaled blue guy low point: %d\n',minY+round((blueGuyHeight-blueGuyHeight_S)/2));
            fprintf('Final scaled and translated blue guy height: %d, width: %d\n',blueGuyHeight_ST,blueGuyWidth_ST);
            fprintf('Final scaled and translated blue guy low point: %d (desired: %d)\n',minY_ST,minY);
        end
    end
end

% FindMeshExtent - Find rendered extent of a mesh (aka object)
%
% Synopsis:
%     [minX,minY,maxX,maxY,height,width] = FindMeshExtent(thisR,meshIndex)
%
% Description
%   Find the x,y extent of the specified mesh in the passed recipe, in the 
%   rendered image plane.
%

function [minX,minY,maxX,maxY,height,width] = FindMeshExtent(thisR,meshIndex)

% Render the mesh map.  Being cautions and using a copy of the recipe to avoid 
% messing things up at the calling level.
thisRUse = thisR.copy;
piWrite(thisRUse);
meshMap = piRender(thisRUse,'renderType','mesh');

% Loop over the pixels in the mesh map and identify those that match the
% passed index.  Keep track of min/max in x and y directions.  Use
% image convention that y increases from bottom to top, rather than matrix 
% row convention.
meshImage = zeros(size(meshMap));
minX = Inf; maxX = -Inf; minY = Inf; maxY = -Inf;
[nY,nX] = size(meshMap);
for ii = 1:nY
    y = nY - ii + 1;
    for jj = 1:nX
        x = jj;
        if (meshMap(ii,jj) == meshIndex)
            meshImage(ii,jj) = 1;
            if (y < minY)
                minY = y;
            end
            if (x < minX)
                minX = x;
            end
            if (y > maxY)
                maxY = y;
            end
            if (x > maxX)
                maxX = x;
            end
        end
    end
end

% Find overall height and width.
height = maxY-minY;
width = maxX-minX;

end

% CalibrateVerticalTranslation - Calibrate scene translation units wrt 
%pixels.
% Synopsis:
%    pixelsPerTranslationUnit = CalibrateVerticalTranslation(thisR,assetName,meshIndex,calibrateTranslationStep)
%
% Description:
%    Translate an object vertically, find out how far it moved in pixels.
%    Assumes that bottom of object is visible both pre and post
%    translation, which is not necessarily true in the general case.
%
%    Could add a check that the object extent is the same before and after
%    the translation, but need to worry a little about pixel rounding error
%    in setting the threshold for agreement.
% 
% See also: FindMeshExtent
%

function pixelsPerTranslationUnit = CalibrateVerticalTranslation(thisR,assetName,meshIndex,calibrateTranslationStep)

% Find object bottom position before translation
thisRUse = thisR.copy;
piWrite(thisRUse);
[minX,minY,maxX,maxY,height,width] = FindMeshExtent(thisRUse,meshIndex);

% Translate and repeat
thisR_T = thisR.copy;
theAsset = thisR_T.get('asset parent id',assetName);
thisR_T.set('asset', theAsset, 'translate', [0 calibrateTranslationStep 0]);
piWrite(thisR_T);
[minX_T,minY_T,maxX_T,maxY_T,height_T,width_T] = FindMeshExtent(thisR_T,meshIndex);

% Calculate calibration factor by measuring shift in pixels and dividing by
% the scene translation step.
pixelsPerTranslationUnit = (minY_T - minY)/calibrateTranslationStep;

end