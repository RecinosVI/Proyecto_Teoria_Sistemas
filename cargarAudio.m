function [x, Fs, info] = cargarAudio(ruta)
%CARGARAUDIO Lee WAV mono o multicanal y caracteriza la entrada.
if ~(ischar(ruta) || (isstring(ruta) && isscalar(ruta)))
    error('AudioFX:Ruta','Seleccione una ruta de archivo WAV válida.');
end
ruta = char(ruta);
[~,nombre,extension] = fileparts(ruta);
if ~strcmpi(extension,'.wav')
    error('AudioFX:Formato','Solo se aceptan archivos WAV.');
end
if ~isfile(ruta)
    error('AudioFX:Archivo','El archivo WAV no existe: %s',ruta);
end
try
    [x,Fs] = audioread(ruta);
catch causa
    error('AudioFX:Lectura','No se pudo leer el archivo WAV: %s',causa.message);
end
validateattributes(x,{'numeric'},{'real','finite','nonempty','2d'},mfilename,'x');
validateattributes(Fs,{'numeric'},{'scalar','positive','finite'},mfilename,'Fs');
info = struct('ruta',ruta,'nombre',[nombre extension],'Fs',Fs, ...
    'muestras',size(x,1),'canales',size(x,2),'duracion',size(x,1)/Fs, ...
    'pico',max(abs(x(:))));
end
