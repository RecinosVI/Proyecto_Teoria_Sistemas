function projectFile = buildProject(projectFolder)
%BUILDPROJECT Crea el proyecto MATLAB nativo con rutas y accesos directos.
% Uso: addpath('src'); buildProject;
% Crea .prj y sus metadatos usando matlab.project.createProject. No abre la
% interfaz AudioFX automaticamente. Requiere MATLAB R2026b o posterior.
if nargin < 1
    projectFolder = fileparts(fileparts(mfilename('fullpath')));
end
assert(isfolder(projectFolder), 'AudioFX:ProjectFolder', ...
    'No existe la carpeta del proyecto: %s', projectFolder);
projectFile = fullfile(projectFolder, 'MATLAB-AudioFX.prj');
alreadyLoaded = false;
try
    p = currentProject;
    if strcmpi(char(p.RootFolder), char(projectFolder))
        alreadyLoaded = true;
    else
        error('AudioFX:OtherProjectLoaded', ...
            'Cierre el proyecto MATLAB abierto antes de generar MATLAB-AudioFX.');
    end
catch cause
    if strcmp(cause.identifier, 'AudioFX:OtherProjectLoaded')
        rethrow(cause);
    end
end
if ~alreadyLoaded
    if isfile(projectFile) || isfile(fullfile(projectFolder, 'matlab.toml'))
        p = openProject(projectFolder);
    else
        p = matlab.project.createProject('Name', 'MATLAB-AudioFX', ...
            'Folder', projectFolder);
    end
end
% R2026b permits TOML definitions. Convert the genuine portable project to
% the XML format required for the requested .prj artifact. MathWorks requires
% closing a project before convertDefinitionFiles is called.
if ~isequal(p.DefinitionFilesType, matlab.project.DefinitionFiles.FixedPathMultiFile)
    close(p);
    matlab.project.convertDefinitionFiles(projectFolder, ...
        matlab.project.DefinitionFiles.FixedPathMultiFile);
    p = openProject(projectFolder);
end
cleanupProject = onCleanup(@() closeIfCreated(p, alreadyLoaded));
p.Name = 'MATLAB-AudioFX';
summaryText = 'Procesamiento de WAV, efectos, analisis temporal y FFT, y pruebas del proyecto.';
if isprop(p, 'Summary')
    p.Summary = summaryText;
else
    p.Description = summaryText;
end
p.ProjectStartupFolder = projectFolder;
addFolderIncludingChildFiles(p, projectFolder);
pathFolders = {'', 'src', 'effects', 'analysis', 'app'};
existingPaths = string(p.PathFolders);
for k = 1:numel(pathFolders)
    folderToAdd = fullfile(projectFolder, pathFolders{k});
    if isfolder(folderToAdd) && ~any(strcmpi(existingPaths, string(folderToAdd)))
        addPath(p, folderToAdd);
        existingPaths(end+1) = string(folderToAdd); %#ok<AGROW>
    end
end
shortcutFiles = {'iniciarAudioFX.m', 'tests/run_tests.m', 'generarEntregables.m'};
shortcutNames = {'Iniciar AudioFX', 'Ejecutar pruebas', 'Generar entregables nativos'};
for k = 1:numel(shortcutFiles)
    fileToAdd = fullfile(projectFolder, shortcutFiles{k});
    if ~isfile(fileToAdd), continue; end
    existing = p.Shortcuts;
    if ~isempty(existing) && any(strcmpi(string({existing.File}), string(fileToAdd)))
        continue;
    end
    shortcut = addShortcut(p, fileToAdd);
    shortcut.Name = shortcutNames{k};
end
if ~alreadyLoaded
    close(p);
end
assert(isfile(projectFile), 'AudioFX:ProjectDescriptor', ...
    'MATLAB no genero el descriptor esperado: %s', projectFile);
assert(isfolder(fullfile(projectFolder, 'resources', 'project')) || ...
    isfolder(fullfile(projectFolder, '.SimulinkProject')), ...
    'AudioFX:ProjectMetadata', 'MATLAB no genero los metadatos del proyecto.');
fprintf('NATIVE_PROJECT_OK: %s\n', projectFile);
end

function closeIfCreated(project, wasAlreadyLoaded)
if ~wasAlreadyLoaded
    try
        if isLoaded(project), close(project); end
    catch
        % Preserve any more useful build error during cleanup.
    end
end
end
