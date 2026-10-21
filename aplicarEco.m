function y = aplicarEco(x, Fs, delaySeg, alpha)
%APLICARECO Eco FIR: y[n] = x[n] + alpha*x[n-D].
%   D = round(delaySeg*Fs). La entrada fuera de 0..N-1 vale cero. La salida
%   conserva la cola completa y tiene N+D muestras, incluso si alpha=0.
%   D=0 produce (1+alpha)*x. Cada canal se procesa por separado.
%   Para D y alpha fijos: lineal, causal, invariante en el tiempo y BIBO
%   estable. Tiene memoria cuando D>0 y alpha~=0. No normaliza la salida.

x = validarAudio(x);
if ~isnumeric(Fs) || ~isscalar(Fs) || ~isreal(Fs) || ~isfinite(Fs) || Fs <= 0
    error('AudioFX:FrecuenciaMuestreoInvalida', 'Fs debe ser un escalar real positivo y finito.');
end
if ~isnumeric(delaySeg) || ~isscalar(delaySeg) || ~isreal(delaySeg) || ...
        ~isfinite(delaySeg) || delaySeg < 0
    error('AudioFX:RetardoInvalido', 'El tiempo de eco debe ser un escalar finito mayor o igual que cero.');
end
if ~isnumeric(alpha) || ~isscalar(alpha) || ~isreal(alpha) || ~isfinite(alpha) || ...
        alpha < 0 || alpha > 1
    error('AudioFX:IntensidadEcoInvalida', 'La intensidad del eco debe estar entre 0 y 1.');
end
D = round(double(delaySeg) * double(Fs));
N = size(x, 1);
if ~isfinite(D) || D > flintmax - N
    error('AudioFX:RetardoInvalido', 'El retardo es demasiado grande para representar sus índices.');
end
y = zeros(N + D, size(x, 2));
y(1:N, :) = x;
y((1:N) + D, :) = y((1:N) + D, :) + double(alpha) .* x;
if any(~isfinite(y), 'all')
    error('AudioFX:ResultadoNoFinito', 'El eco produce valores fuera del rango numérico.');
end
end
