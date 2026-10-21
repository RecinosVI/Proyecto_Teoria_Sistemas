function x = validarAudio(x)
%VALIDARAUDIO Valida muestras organizadas como N muestras por C canales.
%   Devuelve DOUBLE para que todos los módulos tengan un contrato numérico
%   uniforme. No modifica la amplitud ni normaliza la señal.

if ~isnumeric(x) || ~ismatrix(x) || isempty(x) || ~isreal(x) || issparse(x)
    error('AudioFX:AudioInvalido', ...
        'El audio debe ser una matriz numérica real y no vacía de N muestras por C canales.');
end
if any(~isfinite(x), 'all')
    error('AudioFX:AudioNoFinito', 'El audio contiene valores NaN o Inf.');
end
x = double(x);
end
