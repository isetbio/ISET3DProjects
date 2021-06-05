% t_renderISET3dHyperspectral
%
% Read in a rendered recipe, extract the hyperspectral image data, 
% compute LMS cone excitations, and use PTB routines to go from
% there to a metameric rendered image on an RGB display device.

% History
%   06/05/21  dhb  Wrote it.

%% Render a simple recipe
%
% Start up ISET and check that docker is configured 
clear; close all; ieInit;
if ~piDockerExists, piDockerConfig; end

% Get a simple recipe
thisR = piRecipeDefault('scene name','sphere');

% Add a point light, needed by this scene.
pointLight = piLightCreate('point','type','point','cameracoordinate', true);
thisR.set('light','add',pointLight);

% Set up the render quality
thisR.set('film resolution',[192 192]);
thisR.set('rays per pixel',128);
thisR.set('n bounces',1); % Number of bounces

%% Save the recipe and render
piWrite(thisR);
[scene, result] = piRender(thisR);

%% Take a look at the scene
sceneWindow(scene);

%% Get the hyperspectral image data out of the scene
%
% The image is rows x cols x nWls - the third dimension
% is the spectral radiance at each pixel in photons/sec-m2-sr-nm.
wls = sceneGet(scene,'wave');
S = MakeItS(wls);
radianceImageQuanta = sceneGet(scene,'photons');


%% Get standard LMS cone spectral sensitivities in quantal units
%
% This gets us the standard CIE fundamentals, for a 2 degree field.
% We could adjust for observer age, if we wanted.  32 years old is
% the standard default.
coneParams = DefaultConeParams('cie_asano');
coneParams.ageYears = 32;
coneParams.fieldSizeDegrees = 2;
[~,T_energy,T_quanta] = ComputeObserverFundamentals(coneParams,S);

%% Convert image to cal format and get LMS.
%
% LMS coordinates in units of isomerizations/cone-sec (foveal cone
% geometric parameters used to estimate cone quantal capture).
%
% The multiplication by S(2) handles the wavelength spacing in 
% the matrix multiplication approximation of the integral over
% wavelength.  The convention in ISET code is that units of radiance
% are per nm.  Our calibration routines, below, use a convention of
% units in per wavelength band, so once we are entirely in PTB land
% we don't multiply by the delta wavelength factor.
[radianceQuantaCalFormat,nX,nY] = ImageToCalFormat(radianceImageQuanta);
LMSExcitationsCalFormat = T_quanta*radianceQuantaCalFormat*S(2);

%% Check on energy/quanta conversion
%
% Convert radiance to Watts/m2-sr-nm
radianceEnergyCalFormat = QuantaToEnergy(S,radianceQuantaCalFormat);
LMSExcitationsCalFormatChk = T_energy*radianceEnergyCalFormat*S(2);
if (max(abs(LMSExcitationsCalFormatChk(:) - LMSExcitationsCalFormat(:))) > 1e-12*max(abs(LMSExcitationsCalFormat(:))))
    error('Energy/quanta conversion glitch somewhere');
end

%% Read in a calibration file for a monitor
%
% We'll replace the test calibration file here with one for our device,
% sooner or later.
noWarningOnDuplicate = true;
cal = LoadCalFile('PTB3TestCal',[],[],noWarningOnDuplicate);
cal = SetSensorColorSpace(cal,T_energy,S);
cal = SetGammaMethod(cal,1);

%% Go from LMS to device primary space
rgbCalFormat = SensorToPrimary(cal,LMSExcitationsCalFormat);

%% Scale into gamut
%
% Nothing in our rendering pipeline guarantees that the maximum
% intensity of the image is within the gamut of the monitor.  We
% could address this by scaling the illumination intensity of
% the light source to bring the maximum primary RGB value down
% lower than 1, or we can scale at this stage. 
%
% When we do the experiment, we have to be careful to scale all
% of the images the same way, so it may be cleaner to scale the
% intensity of the light source in the rendering, and then throw
% an error at this stage if the intensity is out of gamut.
%
% When we do scale, it's good to leave a little headroom (that is,
% don't go quite to 1), because monitors get dimmer over time
% and because the Philly and Boston monitors may have different
% max values. It's possible we'll need to scale differently for
% Philly and Boston monitors.
headroomFactor = 0.9;
maxPrimaryValue = max(rgbCalFormat(:));
if (maxPrimaryValue > headroomFactor)
    fprintf('Warning: Maximum primary intensity of %0.2g exceeds desired max of %0.2g\n',maxPrimaryValue,headroomFactor);
end
rgbCalFormatScaled = headroomFactor*rgbCalFormat/maxPrimaryValue;

% It's also possible to get negative rgb values.  This happens
% if the saturation of one of the rendered pixels exceeds
% what the monitor gamut can display.  Not much to do here 
% except truncate to positive, and perhaps let the user know.
if (any(rgbCalFormatScaled(:) < 0))
    fprintf('Warning: some primary values in rendered rgb image are negative.\n');
    fprintf('\tWorth looking into how many and by how much\n');
    fprintf('\tThis routine simply truncates such values to 0\n');
end
rgbCalFormatScaled(rgbCalFormatScaled < 0) = 0;

%% Gamma correct, now that we are in range 0,1
RGBCalFormat = PrimaryToSettings(cal,rgbCalFormatScaled);

%% Convert back to an image
RGBImage = CalFormatToImage(RGBCalFormat,nX,nY);

%% Display
%
% This image looks a little yellow, which is almost surely
% because the test calibration file is for some ancient CRT
% monitor with a color balance that differs from what we're
% using here. My guess is that it will look right when displayed
% on a monitor matched to the calibration file used in the rendering.
figure; imshow(RGBImage);
title('Calibrated RGB rendering');

%% For fun, render sRGB versions of the rendered image
%
% sRGB is sort of a generic monitor standard.  Having sRGB
% versions of images is useful for talks and papers, where 
% you don't really know what device will be used to show it
% and thus using a standard is as good a guess as anything.
%
% Notice that the image comes out looking achromatic here. 
% sRGB is closer to most modern LCD monitors than the monitor
% described by that old calibration file.
%
% sRGB is based on the CIE XYZ color matching functions, so
% first step is to go from Radiance to XYZ.  And first step
% to do that is get the color matching functions.  The magic
% 683 makes the units of Y cd/m2 when we specificy radiance
% as Watts/sr-m2-nm and take the wavelength delta properly
% into account in the summation over wavelength
load T_xyz1931
T_xyz = 683*SplineCmf(S_xyz1931,T_xyz1931,S);
XYZCalFormat = T_xyz*radianceEnergyCalFormat*S(2);

%% Convert XYZ to sRGB primary values
%
% Same general issues with scaling as above confront us here
sRGBPrimaryCalFormat = XYZToSRGBPrimary(XYZCalFormat);
maxPrimaryValue = max(sRGBPrimaryCalFormat(:));
if (maxPrimaryValue > headroomFactor)
    fprintf('Warning: Maximum sRGB primary intensity of %0.2g exceeds desired max of %0.2g\n',maxPrimaryValue,headroomFactor);
end
sRGBPrimaryCalFormatScaled = headroomFactor*sRGBPrimaryCalFormat/maxPrimaryValue;

if (any(sRGBPrimaryCalFormatScaled(:) < 0))
    fprintf('Warning: some sRGB primary values in rendered image are negative.\n');
    fprintf('\tWorth looking into how many and by how much\n');
    fprintf('\tThis routine simply truncates such values to 0\n');
end
sRGBPrimaryCalFormatScaled(sRGBPrimaryCalFormatScaled < 0) = 0;

% Gamma correct according to sRGB standard and display
% The gamma corrected values are in range 0-255, assuming 8
% bit display.  Putting the uint8() in the call to imshow()
% tells that routine to expect 0-255 input.
sRGBCalFormat = SRGBGammaCorrect(sRGBPrimaryCalFormatScaled,0);
sRGBImage = CalFormatToImage(sRGBCalFormat,nX,nY);
figure; imshow(uint8(sRGBImage));
title('sRGB rendering');






