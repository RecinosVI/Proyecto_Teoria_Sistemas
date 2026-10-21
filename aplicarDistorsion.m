function y = aplicarDistorsion(x, G)
%APLICARDISTORSION Saturación suave y[n] = tanh(G*x[n]).
%   G>0 controla la intensidad. La salida está acotada en [-1,1] sin una
%   normalización adicional. Para G fijo: sistema no lineal, causal, sin
%   memoria, invariante en el tiempo y estable BIBO.

x = validarAudio(x);
if ~isnumeric(G) || ~isscalar(G) || ~isreal(G) || ~isfinite(G) || G <= 0
    error('AudioFX:DistorsionInvalida', 'La intensidad de distorsión debe ser un escalar real positivo y finito.');
end
y = tanh(double(G) .* x);
end
