function [y, FsSalida, info] = procesarCadena(x, Fs, p)
%PROCESARCADENA Procesa siempre la entrada original con orden determinista.
% Ganancia -> eco -> distorsión -> filtro -> cambio de velocidad -> inversión temporal.
% No normaliza aquí: conserva la interpretación matemática de los sistemas.
if nargin < 3
    p = parametrosPorDefecto();
end
validateattributes(x,{'numeric'},{'real','finite','nonempty','2d'},mfilename,'x');
validateattributes(Fs,{'numeric'},{'scalar','real','finite','positive'},mfilename,'Fs');
if ~isstruct(p) || ~isscalar(p)
    error('AudioFX:Parametros','Los parámetros deben ser una estructura escalar.');
end
% Compatibilidad con configuraciones guardadas antes del sexto efecto.
if ~isfield(p,'invertirActivo'), p.invertirActivo = false; end
necesarios = fieldnames(parametrosPorDefecto());
for k = 1:numel(necesarios)
    if ~isfield(p,necesarios{k})
        error('AudioFX:Parametros','Falta el parámetro %s.',necesarios{k});
    end
end
for campo = {'ecoActivo','distorsionActiva','filtroActivo','invertirActivo'}
    v = p.(campo{1});
    if ~isscalar(v) || ~(islogical(v) || (isnumeric(v) && isfinite(v) && (v==0 || v==1)))
        error('AudioFX:Parametros','%s debe ser un indicador lógico.',campo{1});
    end
end
y = aplicarGanancia(x,p.ganancia);
orden = {'ganancia'};
if p.ecoActivo
    y = aplicarEco(y,Fs,p.delaySeg,p.alpha);
    orden{end+1} = 'eco';
end
if p.distorsionActiva
    y = aplicarDistorsion(y,p.intensidad);
    orden{end+1} = 'distorsion';
end
if p.filtroActivo
    y = aplicarFiltro(y,Fs,p.tipoFiltro,p.fc,p.orden);
    orden{end+1} = 'filtro';
end
[y,FsSalida] = cambiarVelocidad(y,Fs,p.velocidad);
orden{end+1} = 'velocidad';
if p.invertirActivo
    y = invertirAudio(y);
    orden{end+1} = 'invertir';
end
if any(~isfinite(y(:)))
    error('AudioFX:SalidaInvalida','La cadena produjo muestras no finitas. Reduzca los parámetros.');
end
info = struct('picoEntrada',max(abs(x(:))),'picoSalida',max(abs(y(:))), ...
    'muestrasEntrada',size(x,1),'muestrasSalida',size(y,1),'canales',size(x,2), ...
    'duracionEntrada',size(x,1)/Fs,'duracionSalida',size(y,1)/FsSalida, ...
    'recorteNecesario',any(abs(y(:))>1),'parametros',p,'ordenCadena',{orden});
end
