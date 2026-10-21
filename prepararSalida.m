function [y, factor, pico] = prepararSalida(x)
%PREPARARSALIDA Normalización global segura antes de escuchar o exportar.
% Mantiene el balance entre canales. La señal de análisis no se modifica.
validateattributes(x,{'numeric'},{'real','finite','nonempty','2d'},mfilename,'x');
x = double(x);
pico = max(abs(x(:)));
factor = 1;
if pico > 1
    factor = 1/pico;
end
y = x .* factor;
end
