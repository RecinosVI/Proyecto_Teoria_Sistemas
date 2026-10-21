function y = aplicarGanancia(x, ganancia)
%APLICARGANANCIA Escalamiento lineal y[n] = A*x[n] por todos los canales.
%   A puede ser cero (silencio) o negativo (inversión de polaridad).
%   No limita ni normaliza amplitudes. El llamador vigila el clipping antes
%   de reproducir o exportar. Para A fijo: lineal, causal, sin memoria,
%   invariante en el tiempo y estable BIBO si A es finito.

x = validarAudio(x);
if ~isnumeric(ganancia) || ~isscalar(ganancia) || ~isreal(ganancia) || ~isfinite(ganancia)
    error('AudioFX:GananciaInvalida', 'La ganancia debe ser un escalar real finito.');
end
y = double(ganancia) .* x;
if any(~isfinite(y), 'all')
    error('AudioFX:ResultadoNoFinito', 'La ganancia produce valores fuera del rango numérico.');
end
end
