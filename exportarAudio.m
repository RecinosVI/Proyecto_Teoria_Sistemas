function info = exportarAudio(x, Fs, ruta)
%EXPORTARAUDIO Guarda un WAV PCM de 24 bits sin recorte por sobrecarga.
validateattributes(Fs,{'numeric'},{'scalar','real','finite','positive','integer'},mfilename,'Fs');
if ~(ischar(ruta) || (isstring(ruta) && isscalar(ruta)))
    error('AudioFX:Ruta','Indique una ruta válida para exportar.');
end
ruta = char(ruta);
[carpeta,~,extension] = fileparts(ruta);
if ~strcmpi(extension,'.wav')
    error('AudioFX:Formato','El archivo de salida debe tener extensión .wav.');
end
if ~isempty(carpeta) && ~isfolder(carpeta)
    error('AudioFX:Carpeta','La carpeta de salida no existe.');
end
[segura,factor,pico] = prepararSalida(x);
try
    audiowrite(ruta,segura,Fs,'BitsPerSample',24);
catch causa
    error('AudioFX:Escritura','No se pudo guardar el WAV: %s',causa.message);
end
info = struct('ruta',ruta,'Fs',Fs,'muestras',size(segura,1), ...
    'canales',size(segura,2),'picoOriginal',pico, ...
    'factorAplicado',factor,'normalizado',factor<1);
end
