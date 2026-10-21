function y = aplicarFiltro(x, Fs, tipo, fc, orden)
%APLICARFILTRO Butterworth causal pasa bajos, pasa altos o pasa banda.
%   Y = APLICARFILTRO(X,FS,TIPO,FC,ORDEN) usa orden 4 por defecto. FC es
%   escalar para pasa bajos/altos y [fInferior fSuperior] para pasa banda;
%   todas sus frecuencias deben estar estrictamente entre 0 y FS/2.
%   En pasa banda, BUTTER produce orden total 2*ORDEN.
%   TIPO admite pasabajos, pasaaltos, pasabanda y lowpass/highpass/bandpass.
%   Secciones de segundo orden diseñadas con BUTTER y ejecutadas con FILTER
%   evitan formar un único polinomio de orden alto. Estado inicial cero;
%   no se usa FILTFILT, no se suprime el transitorio ni se normaliza.
%   Para parámetros fijos: lineal, causal, con memoria, invariante en el
%   tiempo y BIBO estable en el modelo ideal Butterworth.

if nargin < 5
    orden = 4;
end
x = validarAudio(x);
if ~isnumeric(Fs) || ~isscalar(Fs) || ~isreal(Fs) || ~isfinite(Fs) || Fs <= 0
    error('AudioFX:FrecuenciaMuestreoInvalida', 'Fs debe ser un escalar real positivo y finito.');
end
if ~(ischar(tipo) && isrow(tipo)) && ~(isstring(tipo) && isscalar(tipo) && ~ismissing(tipo))
    error('AudioFX:TipoFiltroInvalido', 'Seleccione pasa bajos, pasa altos o pasa banda.');
end
tipo = lower(strtrim(char(tipo)));
switch tipo
    case {'pasabajos', 'pasa bajos', 'lowpass', 'low'}
        diseno = 'low';
        numeroCortes = 1;
    case {'pasaaltos', 'pasa altos', 'highpass', 'high'}
        diseno = 'high';
        numeroCortes = 1;
    case {'pasabanda', 'pasa banda', 'bandpass', 'band'}
        diseno = 'bandpass';
        numeroCortes = 2;
    otherwise
        error('AudioFX:TipoFiltroInvalido', 'El tipo de filtro no es reconocido: %s.', tipo);
end
if ~isnumeric(fc) || ~isreal(fc) || ~isvector(fc) || numel(fc) ~= numeroCortes || ...
        any(~isfinite(fc), 'all') || any(fc <= 0, 'all') || any(fc >= double(Fs)/2, 'all')
    error('AudioFX:FrecuenciaCorteInvalida', ...
        'La frecuencia de corte debe estar estrictamente entre 0 y Fs/2; pasa banda requiere dos frecuencias.');
end
fc = double(fc(:).');
if numeroCortes == 2 && fc(1) >= fc(2)
    error('AudioFX:FrecuenciaCorteInvalida', 'En pasa banda, la frecuencia inferior debe ser menor que la superior.');
end
if ~isnumeric(orden) || ~isscalar(orden) || ~isreal(orden) || ~isfinite(orden) || ...
        orden < 1 || orden ~= fix(orden)
    error('AudioFX:OrdenFiltroInvalido', 'El orden del filtro debe ser un entero positivo.');
end
if exist('butter', 'file') == 0 || exist('zp2sos', 'file') == 0
    error('AudioFX:ToolboxNoDisponible', 'El filtrado requiere Signal Processing Toolbox.');
end
[z, p, k] = butter(double(orden), fc / (double(Fs)/2), diseno);
[sos, g] = zp2sos(z, p, k);
y = g .* x;
for seccion = 1:size(sos, 1)
    y = filter(sos(seccion, 1:3), sos(seccion, 4:6), y, [], 1);
end
if any(~isfinite(y), 'all')
    error('AudioFX:ResultadoNoFinito', 'El filtro produjo valores no finitos; revise su orden y frecuencias.');
end
end
