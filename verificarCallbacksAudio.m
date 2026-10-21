function informe = verificarCallbacksAudio(projectFolder)
%VERIFICAR_CALLBACKS_AUDIO Verificacion tecnica con la app y salida de audio.
% Ejecutar en la sesion MATLAB licenciada. La reproduccion usa el dispositivo
% real, pero este informe no certifica percepcion auditiva humana.
if nargin < 1
    projectFolder = fileparts(fileparts(mfilename('fullpath')));
end
[existeCarpeta,datosCarpeta] = fileattrib(projectFolder);
assert(existeCarpeta && datosCarpeta.directory,'AudioFX:ProjectFolder','No existe la carpeta del proyecto.');
projectFolder = datosCarpeta.Name;
oldPath = path;
addpath(projectFolder, fullfile(projectFolder,'app'), ...
    fullfile(projectFolder,'src'), fullfile(projectFolder,'effects'), ...
    fullfile(projectFolder,'analysis'));
clear AudioFX;
appFile = which('AudioFX');
informe = struct('estado','INICIADO','fechaUTC', ...
    char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')), ...
    'versionMATLAB',version,'archivoApp',appFile, ...
    'archivoNativo',endsWith(appFile,'.mlapp','IgnoreCase',true), ...
    'audicionHumanaObservada',false);
comprobaciones = {};
app = [];
reportFile = fullfile(projectFolder,'docs','verificacion_callbacks_audio.json');
try
    app = AudioFX;
    cleanupResources = onCleanup(@() limpiarRecursos(app,oldPath));
    app.UIFigure.Visible = 'on';
    drawnow;
    [x,fs] = audioread(fullfile(projectFolder,'audio','prueba.wav'));
    app.cargarArchivo(fullfile(projectFolder,'audio','prueba.wav'));
    invocar(app.ProcessButton.ButtonPushedFcn,app.ProcessButton);
    comprobar(strcmp(app.ResultButton.Enable,'on') && ...
        strcmp(app.ExportButton.Enable,'on'), ...
        'Callback Procesar activa escucha y exportacion');
    comprobar(startsWith(app.StatusLabel.Text,'Procesado'), ...
        'Callback Procesar termina sin alerta de error');

    app.GainField.Value = 1.4;
    invocar(app.GainField.ValueChangedFcn,app.GainField);
    comprobar(strcmp(app.ResultButton.Enable,'off') && ...
        strcmp(app.ExportButton.Enable,'off'), ...
        'Callback de parametro invalida el resultado anterior');
    comprobar(isempty(findobj(app.ProcessedAxes,'Type','line')), ...
        'Callback de parametro limpia la grafica procesada');

    app.FilterDropDown.Value = 'pasabanda';
    invocar(app.FilterDropDown.ValueChangedFcn,app.FilterDropDown);
    comprobar(strcmp(app.Cutoff2Field.Enable,'on'), ...
        'Callback Pasa banda habilita el segundo corte');
    app.FilterDropDown.Value = 'pasabajos';
    invocar(app.FilterDropDown.ValueChangedFcn,app.FilterDropDown);
    comprobar(strcmp(app.Cutoff2Field.Enable,'off'), ...
        'Callback Pasa bajos deshabilita el segundo corte');

    app.EchoCheck.Value = true;
    app.DelayField.Value = 0.25;
    app.AlphaField.Value = 0.35;
    app.DistortionCheck.Value = true;
    app.DriveField.Value = 2;
    app.FilterCheck.Value = true;
    app.CutoffField.Value = 2500;
    app.OrderField.Value = 4;
    app.SpeedField.Value = 1.25;
    invocar(app.SpeedField.ValueChangedFcn,app.SpeedField);
    invocar(app.ProcessButton.ButtonPushedFcn,app.ProcessButton);
    comprobar(startsWith(app.StatusLabel.Text,'Procesado') && ...
        strcmp(app.ResultButton.Enable,'on'), ...
        'Callback Procesar acepta la cadena completa');
    comprobar(numel(findobj(app.ProcessedAxes,'Type','line')) == size(x,2) && ...
        numel(findobj(app.ProcessedFFTAxes,'Type','line')) == size(x,2), ...
        'Callbacks conservan series temporales y FFT por canal');

    invocar(app.OriginalButton.ButtonPushedFcn,app.OriginalButton);
    pause(0.2);
    comprobar(startsWith(app.StatusLabel.Text,'Reproduciendo audio original'), ...
        'Callback Escuchar original inicia audioplayer sin error');
    invocar(app.StopButton.ButtonPushedFcn,app.StopButton);
    comprobar(strcmp(app.StatusLabel.Text,'Reproduccion detenida.') || ...
        strcmp(app.StatusLabel.Text,'Reproducción detenida.'), ...
        'Callback Detener finaliza reproduccion original');
    invocar(app.ResultButton.ButtonPushedFcn,app.ResultButton);
    pause(0.2);
    comprobar(startsWith(app.StatusLabel.Text,'Reproduciendo audio procesado'), ...
        'Callback Escuchar resultado inicia audioplayer sin error');
    invocar(app.StopButton.ButtonPushedFcn,app.StopButton);
    comprobar(strcmp(app.StatusLabel.Text,'Reproduccion detenida.') || ...
        strcmp(app.StatusLabel.Text,'Reproducción detenida.'), ...
        'Callback Detener finaliza reproduccion procesada');

    [y,fsSalida] = app.procesar();
    app.AnalysisTabs.SelectedTab = app.TimeTab;
    drawnow;
    timeImage = fullfile(projectFolder,'docs','interfaz_tiempo.png');
    fftImage = fullfile(projectFolder,'docs','interfaz_fft.png');
    exportapp(app.UIFigure,timeImage);
    app.AnalysisTabs.SelectedTab = app.SpectrumTab;
    drawnow;
    exportapp(app.UIFigure,fftImage);
    comprobar(isfile(timeImage) && isfile(fftImage), ...
        'Capturas de la interfaz generadas por exportapp');
    informe.capturas = {'docs/interfaz_tiempo.png','docs/interfaz_fft.png'};

    dispositivos = audiodevinfo;
    comprobar(~isempty(dispositivos.output), ...
        'MATLAB detecta al menos un dispositivo de salida de audio');
    informe.dispositivosSalida = dispositivos.output;
    informe.reproduccionOriginal = reproducirYMedir(x,fs);
    informe.reproduccionResultado = reproducirYMedir(y,fsSalida);
    comprobar(informe.reproduccionOriginal.actividadObservada && ...
        informe.reproduccionResultado.actividadObservada, ...
        'Dispositivo reproduce original y resultado con avance de muestras');

    invocar(app.ResetButton.ButtonPushedFcn,app.ResetButton);
    comprobar(app.GainField.Value == 1 && app.SpeedField.Value == 1 && ...
        ~app.EchoCheck.Value && ~app.DistortionCheck.Value && ...
        ~app.FilterCheck.Value && strcmp(app.ExportButton.Enable,'off'), ...
        'Callback Restablecer recupera parametros neutros');
    closeCallback = app.UIFigure.CloseRequestFcn;
    invocar(closeCallback,app.UIFigure);
    comprobar(~isvalid(app), ...
        'Callback Cerrar destruye la app despues de detener el reproductor');
    informe.estado = 'APROBADO';
    informe.numeroComprobaciones = numel(comprobaciones);
    informe.comprobaciones = comprobaciones;
    guardarInforme(reportFile,informe);
    fprintf('AUDIOFX_CALLBACKS_AUDIO_OK: %d comprobaciones; app=%s\n', ...
        numel(comprobaciones),appFile);
catch causa
    informe.estado = 'FALLIDO';
    informe.numeroComprobaciones = numel(comprobaciones);
    informe.comprobaciones = comprobaciones;
    informe.error = causa.message;
    informe.identificadorError = causa.identifier;
    guardarInforme(reportFile,informe);
    cerrarApp(app);
    path(oldPath);
    rethrow(causa);
end

    function comprobar(condicion,nombre)
        assert(condicion,'AudioFX:CallbacksAudio','Fallo: %s',nombre);
        comprobaciones{end+1} = nombre;
    end
end

function invocar(callback,component)
assert(isa(callback,'function_handle'),'AudioFX:CallbackRuntime', ...
    'El componente no tiene un callback ejecutable ligado a la app.');
callback(component,[]);
drawnow;
end

function resultado = reproducirYMedir(x,fs)
[segura,factor] = prepararSalida(x);
player = audioplayer(segura,fs);
cleanupPlayer = onCleanup(@() stop(player)); %#ok<NASGU>
duracion = size(x,1)/fs;
timer = tic;
play(player);
pause(0.03);
activoInicial = isplaying(player);
muestrasObservadas = player.CurrentSample;
while isplaying(player)
    muestrasObservadas(end+1) = player.CurrentSample; %#ok<AGROW>
    assert(toc(timer) <= duracion + 10,'AudioFX:AudioTimeout', ...
        'El dispositivo no termino la reproduccion en el tiempo esperado.');
    pause(0.025);
end
tiempo = toc(timer);
resultado = struct('actividadObservada',activoInicial && ...
    max(muestrasObservadas) > 1,'termino',~isplaying(player), ...
    'DeviceID',player.DeviceID,'frecuenciaMuestreo',player.SampleRate, ...
    'canales',player.NumChannels,'muestrasTotales',player.TotalSamples, ...
    'maxMuestraObservada',max(muestrasObservadas), ...
    'observaciones',numel(muestrasObservadas),'duracionSenalSeg',duracion, ...
    'tiempoReproduccionSeg',tiempo,'factorSeguro',factor, ...
    'audicionHumanaObservada',false);
assert(resultado.actividadObservada && resultado.termino, ...
    'AudioFX:AudioDevice','No se observo avance de muestras en el dispositivo.');
assert(player.TotalSamples == size(x,1) && player.NumChannels == size(x,2), ...
    'AudioFX:AudioDimensions','El reproductor no conserva muestras y canales.');
end

function cerrarApp(app)
if ~isempty(app) && isvalid(app), delete(app); end
end

function limpiarRecursos(app,oldPath)
cerrarApp(app);
path(oldPath);
end

function guardarInforme(ruta,informe)
fid = fopen(ruta,'w','n','UTF-8');
assert(fid >= 0,'AudioFX:AudioReport','No se pudo guardar %s',ruta);
cleanupFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(informe,'PrettyPrint',true));
end
