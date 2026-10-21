function result = buildAppDesigner(projectFolder)
%BUILDAPPDESIGNER Genera y valida AudioFX.mlapp editable en App Designer.
% Uso: addpath('src'); buildAppDesigner;
% Requiere MATLAB R2026b y una licencia valida. Usa el serializador y el
% parser nativos de App Designer; estas APIs internas pueden cambiar entre
% versiones. Conserva una copia legible de la fuente en resources/source.
if nargin < 1
    projectFolder = fileparts(fileparts(mfilename('fullpath')));
end
sourceFile = fullfile(projectFolder, 'app', 'AudioFX.m');
sourceArchive = fullfile(projectFolder, 'resources', 'source');
if ~isfile(sourceFile)
    archivedSource = fullfile(sourceArchive, 'AudioFX.m');
    assert(isfile(archivedSource), 'AudioFX:MissingSource', ...
        'Source missing: %s', archivedSource);
    % Rebuild from the source archive using the same app location, so that
    % mfilename/which-based project discovery continues to work.
    copyfile(archivedSource, sourceFile);
end
assert(isfile(sourceFile), 'AudioFX:MissingSource', 'Source missing: %s', sourceFile);
if ~isfolder(projectFolder), mkdir(projectFolder); end
destination = fullfile(projectFolder, 'app', 'AudioFX.mlapp');
if ~isfolder(fileparts(destination)), mkdir(fileparts(destination)); end
rawCode = fileread(sourceFile);
% MTreeCodeParser reports zero-based block lines, but the R2026b plain-text
% parser starts a managed block one line earlier. Separate class blocks so
% that editable extraction cannot drop a preceding user block's final end.
rawCode = regexprep(rawCode, '\r\n?', newline);
rawCode = regexprep(rawCode, ...
    '\n(?:[ \t]*\n)*(    (?:methods|properties)(?=[ \t(]))', ...
    [newline newline '$1']);
sourceWriter = fopen(sourceFile, 'w', 'n', 'UTF-8');
assert(sourceWriter >= 0, 'AudioFX:SourceWrite', ...
    'No se pudo normalizar la fuente: %s', sourceFile);
fprintf(sourceWriter, '%s', rawCode);
fclose(sourceWriter);
sourceFolder = fileparts(sourceFile);
originalPath = path;
restorePath = onCleanup(@() path(originalPath));
originalFolder = pwd;
restoreFolder = onCleanup(@() cd(originalFolder));
cd(projectFolder);
addpath(sourceFolder, '-begin');
addpath(projectFolder);
if isfolder(fullfile(projectFolder, 'src'))
    addpath(fullfile(projectFolder, 'src'));
end
if isfolder(fullfile(projectFolder, 'effects'))
    addpath(fullfile(projectFolder, 'effects'));
end
if isfolder(fullfile(projectFolder, 'analysis'))
    addpath(fullfile(projectFolder, 'analysis'));
end
% MATLAB prefers .mlapp over .m when both use the same name in a folder.
% Preserve the previous native artifact, then make the source resolvable.
% Restore that artifact if construction, serialization or validation fails.
backupNative = '';
hadPreviousNative = isfile(destination);
backupReady = false;
app = [];
loaded = [];
try
if hadPreviousNative
    backupNative = [tempname '.mlapp'];
    copyfile(destination, backupNative);
    backupReady = true;
    delete(destination);
end
clear AudioFX;
rehash;
assert(strcmpi(which('AudioFX'), sourceFile), 'AudioFX:SourceShadowed', ...
    'Otra clase AudioFX oculta la fuente utilizada para regenerar la app.');
app = AudioFX();
cleanupApp = onCleanup(@() safeDelete(app));
app.UIFigure.Visible = 'off';
drawnow;

% Assign design-time names to every supported UI component. Prefer the
% actual app property names, and give unexposed labels stable unique names.
adapterMap = appdesigner.internal.application.getComponentAdapterMap();
allComponents = findall(app.UIFigure);
publicNames = properties(app);
usedNames = {};
for k = 1:numel(publicNames)
    try
        item = app.(publicNames{k});
        if isscalar(item) && isgraphics(item) && isKey(adapterMap, class(item))
            setDesignTimeName(item, publicNames{k});
            usedNames{end+1} = publicNames{k}; %#ok<AGROW>
        end
    catch
        % Ordinary data properties are unrelated to visual components.
    end
end
for k = 1:numel(allComponents)
    item = allComponents(k);
    if ~isKey(adapterMap, class(item)), continue; end
    if isprop(item, 'DesignTimeProperties') && ...
            isfield(item.DesignTimeProperties, 'CodeName') && ...
            ~isempty(item.DesignTimeProperties.CodeName)
        continue;
    end
    suffix = k;
    generatedName = sprintf('UIComponent%d', suffix);
    while ismember(generatedName, usedNames)
        suffix = suffix + 1;
        generatedName = sprintf('UIComponent%d', suffix);
    end
    setDesignTimeName(item, generatedName);
    usedNames{end+1} = generatedName; %#ok<AGROW>
end

callbackNames = {'LoadButtonPushed','ProcessButtonPushed','ResetButtonPushed', ...
    'ExportButtonPushed','OriginalButtonPushed','ResultButtonPushed', ...
    'StopButtonPushed','ParameterChanged','CloseRequested'};
callbackNames = callbackNames(cellfun(@(name) ~isempty(regexp(rawCode, ...
    ['\<function\s+(?:[^\n=]*=\s*)?' name '\s*\('], 'once')), callbackNames));
assert(~isempty(callbackNames), 'AudioFX:CallbackSource', ...
    'No se encontraron callbacks de la interfaz en la fuente.');
assignments = struct('AssignedCallbacks', [], 'Children', []);
for k = 1:numel(callbackNames)
    assignments.Children(k).AssignedCallbacks = struct('Name', callbackNames{k});
    assignments.Children(k).Children = [];
end
startupName = "";
if ~isempty(regexp(rawCode, '\<function\s+startupFcn\s*\(', 'once'))
    startupName = "startupFcn";
end
parser = appdesigner.internal.serialization.PlainTextCodeParser( ...
    string(sourceFile), string(rawCode));
codeData = parser.parseCodeData(assignments, startupName, false, "Standard");
assert(strcmp(codeData.ClassName, 'AudioFX'), 'AudioFX:WrongClass', ...
    'Expected the AudioFX class in the app source.');
actualCallbacks = {codeData.Callbacks.Name};
assert(all(ismember(callbackNames, actualCallbacks)), 'AudioFX:CallbackParse', ...
    'The native parser did not preserve all required callbacks.');
assert(all(ismember(actualCallbacks, callbackNames)), 'AudioFX:CallbackLayout', ...
    ['Keep helper methods in editable methods blocks before the dedicated ' ...
     'callback methods block. The parser classified helpers as callbacks.']);
% App Designer regenerates source from this editable fragment on Save.
% Validate its syntax independently of rawCode before serializing the app.
editableText = strjoin(codeData.EditableSectionCode, newline);
editableTree = mtree(sprintf('classdef AudioFXEditableValidation\n%s\nend\n', ...
    editableText), '-com');
assert(~(editableTree.count == 1 && strcmp(editableTree.kind(), 'ERR')), ...
    'AudioFX:EditableCodeSyntax', ...
    'La seccion editable extraida no forma bloques completos de la clase.');

% Design-time callback values must contain method names, while executable
% runtime code continues to use createCallbackFcn or app-bound handles.
lines = splitlines(string(rawCode));
for k = 1:numel(lines)
    match = regexp(char(lines(k)), ...
        'app\.([A-Za-z]\w*)\.([A-Za-z]\w*Fcn)\s*=\s*(.*)', 'tokens', 'once');
    if isempty(match) || ~isprop(app, match{1}), continue; end
    item = app.(match{1});
    for j = 1:numel(callbackNames)
        if ~isempty(regexp(match{3}, ['\<' callbackNames{j} '\>'], 'once'))
            item.(match{2}) = callbackNames{j};
            break;
        end
    end
end
if ismember('CloseRequested', callbackNames)
    app.UIFigure.CloseRequestFcn = 'CloseRequested';
end
% Some callbacks are supplied as uibutton/uieditfield constructor options.
% Assign these known app controls explicitly rather than relying on layout
% source syntax or serializing app-bound function handles.
buttonNames = {'LoadButton','ProcessButton','ResetButton','ExportButton', ...
    'OriginalButton','ResultButton','StopButton'};
buttonMethods = {'LoadButtonPushed','ProcessButtonPushed','ResetButtonPushed', ...
    'ExportButtonPushed','OriginalButtonPushed','ResultButtonPushed','StopButtonPushed'};
for k = 1:numel(buttonNames)
    if isprop(app, buttonNames{k}) && ismember(buttonMethods{k}, callbackNames)
        app.(buttonNames{k}).ButtonPushedFcn = buttonMethods{k};
    end
end
parameterControls = {'GainField','EchoCheck','DelayField','AlphaField', ...
    'DistortionCheck','DriveField','FilterCheck','FilterDropDown', ...
    'CutoffField','Cutoff2Field','OrderField','SpeedField','InvertCheck'};
for k = 1:numel(parameterControls)
    if isprop(app, parameterControls{k}) && ismember('ParameterChanged', callbackNames)
        app.(parameterControls{k}).ValueChangedFcn = 'ParameterChanged';
    end
end

% Keep runtime visibility explicit for the design-time model as well.
allAxes = [app.OriginalAxes app.ProcessedAxes ...
    app.OriginalFFTAxes app.ProcessedFFTAxes];
for k = 1:numel(allAxes)
    allAxes(k).Visible = 'on';
    if isprop(allAxes(k), 'AD_AliasedVisible')
        allAxes(k).AD_AliasedVisible = 'on';
    end
end

serializer = appdesigner.internal.serialization.MLAPPSerializer( ...
    destination, app.UIFigure);
serializer.MatlabCodeText = rawCode;
serializer.EditableSectionCode = codeData.EditableSectionCode;
serializer.Callbacks = codeData.Callbacks;
serializer.StartupCallback = codeData.StartupFcn;
serializer.InputParameters = codeData.InputParameters;
serializer.OverwriteTargetFile = true;
serializer.Metadata.Name = 'AudioFX';
serializer.Metadata.Summary = 'Procesador de audio con efectos y analisis espectral';
serializer.Metadata.Description = 'Proyecto MATLAB-AudioFX';
serializer.Metadata.MinimumSupportedMATLABRelease = 'R2026b';
serializer.Metadata.ScreenshotMode = 'none';
fileHash = serializer.save();

% Reload through the same validators used when opening App Designer files.
deserializer = appdesigner.internal.serialization.SerializationFactory.createDeserializer(destination);
loaded = deserializer.getAppData();
cleanupLoaded = onCleanup(@() safeDelete(loaded.components.UIFigure));
assert(strcmp(deserializer.getAppClassdefCode(), rawCode), ...
    'AudioFX:SerializationCode', 'El codigo del archivo nativo no coincide con la fuente.');
assert(strcmp(loaded.code.ClassName, 'AudioFX'), 'AudioFX:SerializationClass', ...
    'The native artifact contains an unexpected app class.');
assert(isfield(loaded.code, 'EditableSectionCode') && ...
    ~isempty(loaded.code.EditableSectionCode), 'AudioFX:SerializationEditable', ...
    'Editable user code was not serialized.');
assert(all(ismember(callbackNames, {loaded.code.Callbacks.Name})), ...
    'AudioFX:SerializationCallbacks', 'Some callbacks were not serialized.');
for k = 1:numel(loaded.code.Callbacks)
    assert(~isempty(loaded.code.Callbacks(k).ComponentData), ...
        'AudioFX:SerializationBindings', 'Callback sin componente: %s', ...
        loaded.code.Callbacks(k).Name);
end
result = struct('AppFile', destination, 'Hash', fileHash, ...
    'CallbackNames', {callbackNames}, 'NamedComponents', numel(usedNames), ...
    'Warnings', deserializer.Warnings);
if ~isfolder(sourceArchive), mkdir(sourceArchive); end
archiveFile = fullfile(sourceArchive, 'AudioFX.m');
% Validate first, then remove the app-path .m to prevent it from shadowing
% the .mlapp. The original source is preserved in resources/source.
safeDelete(loaded.components.UIFigure);
safeDelete(app);
if ~strcmpi(sourceFile, archiveFile)
    copyfile(sourceFile, archiveFile);
    assert(strcmp(fileread(archiveFile), rawCode), 'AudioFX:SourceArchive', ...
        'La copia archivada no coincide con la fuente original.');
    delete(sourceFile);
end
if strcmpi(sourceFolder, sourceArchive), rmpath(sourceFolder); end
addpath(fullfile(projectFolder, 'app'), '-begin');
clear AudioFX;
rehash;
resolvedApp = which('AudioFX');
assert(strcmpi(resolvedApp, destination), 'AudioFX:AppShadowed', ...
    'Otra fuente AudioFX oculta el archivo nativo: %s', resolvedApp);
fprintf('NATIVE_APP_OK: %s; components=%d; callbacks=%d\n', ...
    destination, result.NamedComponents, numel(callbackNames));
if ~isempty(backupNative) && isfile(backupNative), delete(backupNative); end
catch cause
    if isstruct(loaded) && isfield(loaded, 'components')
        safeDelete(loaded.components.UIFigure);
    end
    safeDelete(app);
    if backupReady && isfile(backupNative)
        copyfile(backupNative, destination, 'f');
        delete(backupNative);
    elseif ~hadPreviousNative && isfile(destination)
        delete(destination);
    end
    rethrow(cause);
end
end

function setDesignTimeName(item, name)
if ~isprop(item, 'DesignTimeProperties')
    addprop(item, 'DesignTimeProperties');
end
item.DesignTimeProperties = struct('CodeName', name, 'GroupId', '', ...
    'ComponentCode', {{}}, 'ImageRelativePath', '', 'DirtyProps', struct());
end

function safeDelete(item)
try
    if ~isempty(item) && isvalid(item), delete(item); end
catch
    % Cleanup must not mask a useful build diagnostic.
end
end
