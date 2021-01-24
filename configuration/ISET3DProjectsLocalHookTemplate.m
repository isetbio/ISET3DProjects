function ISET3DProjectsLocalHook
% ISET3DProjectsLocalHook
%
% Configure things for working on the ISET3DProjects project.
%
% For use with the ToolboxToolbox.  If you copy this into your
% ToolboxToolbox localToolboxHooks directory (by default,
% ~/localToolboxHooks) and delete "LocalHooksTemplate" from the filename,
% this will get run when you execute tbUseProject('ISET3DProjects') to set up for
% this project.  You then edit your local copy to match your configuration.
%
% You will need to edit the project location and i/o directory locations
% to match what is true on your computer.

%% Define project
projectName = 'ISET3DProjects';

%% Say hello
fprintf('Running %s local hook\n',projectName);

%% Clear out old preferences
if (ispref(projectName))
    rmpref(projectName);
end

%% Specify project location
projectBaseDir = tbLocateProject(projectName);

% If we ever needed some user/machine specific preferences, this is one way
% we could do that.
sysInfo = GetComputerInfo();
switch (sysInfo.localHostName)
    case 'eagleray'
        % DHB's desktop
        baseDir = fullfile(filesep,'Volumes','Users1','Dropbox (Aguirre-Brainard Lab)');
 
    otherwise
        % Some unspecified machine, try user specific customization
        switch(sysInfo.userShortName)
            % Could put user specific things in, but at the moment generic
            % is good enough.
            otherwise
                baseDir = fullfile('/Users/',sysInfo.userShortName,'Dropbox (Aguirre-Brainard Lab)');
        end
end

%% Set preferences for project output
%
% This will need to be locally configured.
% setpref(projectName,'rayleighDataDir',fullfile(baseDir,'MELA_datadev','Experiments',projectName,'OLRayleighMatch'));
% setpref(projectName,'rayleighAnalysisDataDir',fullfile(baseDir,'MELA_data','Experiments',projectName,'OLRayleighMatch'));
% setpref(projectName,'rayleighAnalysisDir',fullfile(baseDir,'MELA_analysis','Experiments',projectName, 'OLRayleighMatch'));
% setpref(projectName,'currentCal','BoxBRandomizedLongCableAEyePiece1_12_10_19');   % Most recent calibration. Update as needed.
% setpref(projectName,'mainExpDir',projectBaseDir);
% setpref(projectName,'analysisDir',fullfile(baseDir,'CNST_analysis',projectName));
% setpref(projectName,'stimulusFolder',fullfile(baseDir,'CNST_materials',projectName,'E3'));
% setpref(projectName,'dataFolder',fullfile(baseDir,'CNST_data',projectName));
% setpref(projectName,'demoDataDir',fullfile(baseDir,'CNST_analysis',projectName,'DemoData'));
% setpref(projectName,'mainCodeDir',fullfile('/Users/', sysInfo.userShortName, 'Documents/MATLAB/projects/Experiments/ColorMaterial/code'));
% setpref(projectName,'calFileName','ColorMaterialCalibration');
% setpref('OneLightToolbox', 'OneLightCalData',fullfile(baseDir,'MELA_materials','Experiments',projectName,'OneLightCalData'));
% setpref('BrainardLabToolbox','CalDataFolder',fullfile(baseDir,'MELA_materials','Experiments',projectName,'OneLightCalData'));
