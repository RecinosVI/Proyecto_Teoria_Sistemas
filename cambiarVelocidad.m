function [y, FsSalida] = cambiarVelocidad(x, Fs, factor)
%CAMBIARVELOCIDAD Cambia velocidad y tono mediante remuestreo de muestras.
%   Factor>1 acelera y acorta; 0<factor<1 ralentiza y alarga. Se aproxima
%   factor=p/q con tolerancia relativa 1e-6 y se usa RESAMPLE(X,q,p).
%   FsSalida=Fs: al reproducir a la misma Fs cambian el tempo Y el tono.
%   No implementa estiramiento temporal que preserve el tono. RESAMPLE
%   aplica su filtro antialias y compensa su retardo. Cada canal conserva
%   su identidad; la longitud es ceil(N*q/p). Factor=1 retorna X idéntica.
%   El operador con factor fijo es lineal y tiene memoria. Para factor~=1
%   no es invariante en el tiempo bajo desplazamientos arbitrarios de una
%   muestra en la escala original; este procesamiento es fuera de línea.

x = validarAudio(x);
if ~isnumeric(Fs) || ~isscalar(Fs) || ~isreal(Fs) || ~isfinite(Fs) || Fs <= 0
    error('AudioFX:FrecuenciaMuestreoInvalida', 'Fs debe ser un escalar real positivo y finito.');
end
if ~isnumeric(factor) || ~isscalar(factor) || ~isreal(factor) || ~isfinite(factor) || factor <= 0
    error('AudioFX:VelocidadInvalida', 'El factor de velocidad debe ser un escalar real positivo y finito.');
end
FsSalida = double(Fs);
factor = double(factor);
if factor == 1
    y = x;
    return;
end
if exist('resample', 'file') == 0
    error('AudioFX:ToolboxNoDisponible', 'El cambio de velocidad requiere Signal Processing Toolbox.');
end
[p, q] = rat(factor, 1e-6 * factor);
if ~isfinite(p) || ~isfinite(q) || p < 1 || q < 1 || p > flintmax || q > flintmax
    error('AudioFX:VelocidadInvalida', 'El factor de velocidad no se puede representar como una razón válida.');
end
% RESAMPLE interpreta una fila multicanal como un vector de muestras.
% Para N=1 se remuestrea cada canal por separado sobre el eje temporal.
if size(x, 1) == 1
    y = zeros(ceil(q / p), size(x, 2));
    for canal = 1:size(x, 2)
        canalRemuestreado = resample(x(:, canal), q, p);
        y(:, canal) = canalRemuestreado(:);
    end
else
    y = resample(x, q, p);
end
if any(~isfinite(y), 'all')
    error('AudioFX:ResultadoNoFinito', 'El cambio de velocidad produjo muestras no finitas.');
end
end
