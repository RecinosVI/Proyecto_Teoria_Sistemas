function informe = verificarApp
%VERIFICARAPP Revisión programática opcional de la fuente GUI AudioFX.
% Requiere MATLAB con licencia, soporte de uifigure y Signal Processing
% Toolbox. No reproduce sonido ni abre diálogos. No sustituye la revisión
% visual, los callbacks interactivos ni la validación nativa del .mlapp.
% Desde la raíz: addpath('resources'); informe = verificarApp;

raiz = fileparts(fileparts(mfilename('fullpath')));
pathAnterior = path;
rutaSalida = [tempname '.wav'];
rutaMono = [tempname '.wav'];
addpath(fullfile(raiz,'app'),fullfile(raiz,'src'), ...
    fullfile(raiz,'effects'),fullfile(raiz,'analysis'));
app = AudioFX;
limpiarTodo = onCleanup(@() limpiarRecursos(app,rutaSalida,rutaMono,pathAnterior)); %#ok<NASGU>
app.UIFigure.Visible = 'off';
comprobaciones = {};

comprobar(strcmp(app.ProcessButton.Enable,'off'),'Procesar desactivado sin audio');
comprobar(strcmp(app.OriginalButton.Enable,'off'),'Escucha original desactivada sin audio');
comprobar(strcmp(app.ResultButton.Enable,'off'),'Escucha resultado desactivada sin resultado');
comprobar(strcmp(app.ExportButton.Enable,'off'),'Exportar desactivado sin resultado');
exigirError(@() app.procesar(),'AudioFX:SinAudio');
exigirError(@() app.exportarArchivo(rutaSalida),'AudioFX:SinResultado');

rutaEntrada = fullfile(raiz,'audio','prueba.wav');
[x,Fs] = audioread(rutaEntrada);
app.cargarArchivo(rutaEntrada);
visibilidadOriginal = {char(app.OriginalAxes.Visible),char(app.OriginalFFTAxes.Visible)};
comprobar(all(strcmp(visibilidadOriginal,'on')), ...
    ['Los ejes originales son visibles al cargar datos: ' strjoin(visibilidadOriginal,', ')]);
comprobar(strcmp(app.ProcessButton.Enable,'on'),'Procesar activado tras cargar');
comprobar(strcmp(app.OriginalButton.Enable,'on'),'Escucha original activada tras cargar');
comprobar(strcmp(app.ExportButton.Enable,'off'),'Exportar sigue desactivado antes de procesar');
comprobar(numel(findobj(app.OriginalAxes,'Type','line')) == size(x,2), ...
    'Vista temporal contiene una serie por canal');
comprobar(numel(findobj(app.OriginalFFTAxes,'Type','line')) == size(x,2), ...
    'Vista FFT contiene una serie por canal');

[y,FsOut,info] = app.procesar();
visibilidadProcesada = {char(app.ProcessedAxes.Visible),char(app.ProcessedFFTAxes.Visible)};
comprobar(all(strcmp(visibilidadProcesada,'on')), ...
    ['Los ejes procesados son visibles al procesar: ' strjoin(visibilidadProcesada,', ')]);
comprobar(isequal(y,x) && FsOut == Fs,'Valores iniciales conservan el audio');
comprobar(info.canales == size(x,2),'Metadatos GUI conservan canales');
comprobar(strcmp(app.ResultButton.Enable,'on') && strcmp(app.ExportButton.Enable,'on'), ...
    'Escuchar resultado y exportar activados tras procesar');
comprobar(numel(findobj(app.ProcessedAxes,'Type','line')) == size(x,2), ...
    'Vista temporal procesada contiene todos los canales');
comprobar(numel(findobj(app.ProcessedFFTAxes,'Type','line')) == size(x,2), ...
    'Vista FFT procesada contiene todos los canales');

% Sexto efecto: callback, inversión exacta y reprocesamiento desde original.
app.InvertCheck.Value = true;
cb = app.InvertCheck.ValueChangedFcn;
if iscell(cb)
    feval(cb{1},app.InvertCheck,[],cb{2:end});
else
    feval(cb,app.InvertCheck,[]);
end
comprobar(strcmp(app.ExportButton.Enable,'off') && strcmp(app.ResultButton.Enable,'off'), ...
    'Casilla Invertir audio invalida escucha y exportación');
comprobar(isempty(findobj(app.ProcessedAxes,'Type','line')), ...
    'Casilla Invertir audio limpia la gráfica anterior');
[reversa,fsReversa] = app.procesar();
comprobar(isequal(reversa,x(end:-1:1,:)) && fsReversa == Fs, ...
    'Interfaz invierte muestras sin intercambiar canales ni cambiar Fs');
comprobar(isequal(app.procesar(),reversa), ...
    'Reprocesar inversión parte del original');

% Los controles deben alimentar la misma API matemática que usa consola.
app.GainField.Value = 1.4;
app.EchoCheck.Value = true; app.DelayField.Value = 0.02; app.AlphaField.Value = 0.3;
app.DistortionCheck.Value = true; app.DriveField.Value = 2;
app.FilterCheck.Value = true; app.FilterDropDown.Value = 'pasabanda';
app.CutoffField.Value = 1000; app.Cutoff2Field.Value = 2500;
app.OrderField.Value = 4; app.SpeedField.Value = 1.25; app.InvertCheck.Value = true;
p = parametrosPorDefecto();
p.ganancia = 1.4; p.ecoActivo = true; p.delaySeg = 0.02; p.alpha = 0.3;
p.distorsionActiva = true; p.intensidad = 2; p.filtroActivo = true;
p.tipoFiltro = 'pasabanda'; p.fc = [1000 2500]; p.orden = 4; p.velocidad = 1.25; p.invertirActivo = true;
[esperado,FsEsperada] = procesarCadena(x,Fs,p);
[y,FsOut] = app.procesar();
comprobar(isequal(y,esperado) && FsOut == FsEsperada, ...
    'Controles GUI producen la cadena configurada');
[segunda,~] = app.procesar();
comprobar(isequal(y,segunda),'Reprocesar no acumula sobre el resultado previo');
exigirError(@() app.exportarArchivo(rutaEntrada),'AudioFX:ArchivoOriginal');
salida = app.exportarArchivo(rutaSalida);
[wav,FsWav] = audioread(rutaSalida);
[segura,~,~] = prepararSalida(y);
comprobar(isequal(size(wav),size(y)) && FsWav == FsOut, ...
    'Exportación GUI conserva dimensiones y Fs');
comprobar(max(abs(wav(:)-segura(:))) <= 2/2^23, ...
    'Exportación GUI coincide con salida segura dentro de cuantización PCM24');
comprobar(salida.canales == size(x,2),'Exportación GUI informa canales correctos');

app.restablecer();
comprobar(app.GainField.Value == 1 && app.SpeedField.Value == 1, ...
    'Restablecimiento recupera ganancia y velocidad neutras');
comprobar(~app.EchoCheck.Value && ~app.DistortionCheck.Value && ~app.FilterCheck.Value && ~app.InvertCheck.Value, ...
    'Restablecimiento desactiva efectos opcionales');
comprobar(strcmp(app.ResultButton.Enable,'off') && strcmp(app.ExportButton.Enable,'off'), ...
    'Restablecimiento invalida el resultado anterior');

tMono = (0:799)'/8000;
audiowrite(rutaMono,0.2*sin(2*pi*400*tMono),8000,'BitsPerSample',24);
app.cargarArchivo(rutaMono);
[mono,FsMono,infoMono] = app.procesar();
comprobar(size(mono,2) == 1 && FsMono == 8000 && infoMono.canales == 1, ...
    'Carga mono después de estéreo mantiene estado coherente');
app.FilterCheck.Value = true;
app.CutoffField.Value = FsMono/2;
exigirError(@() app.procesar(),'AudioFX:FrecuenciaCorteInvalida');

informe = struct('estado','APROBADO','versionMATLAB',version, ...
    'fechaUTC',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss')), ...
    'numeroComprobaciones',numel(comprobaciones),'comprobaciones',{comprobaciones}, ...
    'audioReproducido',false,'validacionMlappNativa',endsWith(which('AudioFX'),'.mlapp','IgnoreCase',true), ...
    'visibilidadEjesConDatos',{[visibilidadOriginal visibilidadProcesada]});
fprintf('Fuente GUI: %d comprobaciones aprobadas. No se reprodujo audio.\n',numel(comprobaciones));

    function comprobar(condicion,nombre)
        assert(condicion,'AudioFX:VerificacionApp','Falló: %s.',nombre);
        comprobaciones{end+1} = nombre;
    end

    function exigirError(callback,identificador)
        capturado = '';
        try
            callback();
        catch causa
            capturado = causa.identifier;
        end
        comprobar(strcmp(capturado,identificador),['Error controlado: ' identificador]);
    end

end

function limpiarRecursos(app,rutaSalida,rutaMono,pathAnterior)
cerrarApp(app);
borrarTemporales(rutaSalida,rutaMono);
path(pathAnterior);
end

function cerrarApp(app)
if ~isempty(app) && isvalid(app), delete(app); end
end

function borrarTemporales(varargin)
for k = 1:nargin
    if isfile(varargin{k}), delete(varargin{k}); end
end
end
