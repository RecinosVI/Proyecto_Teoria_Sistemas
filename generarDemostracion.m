function informe = generarDemostracion()
%GENERARDEMOSTRACION Audio sintético propio, cadena completa y evidencia.
% Es regenerable; no requiere micrófono ni archivos de terceros.
raiz = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(raiz,'effects'),fullfile(raiz,'analysis'));
fs = 48000;
t = (0:3*fs-1)'/fs;
envolvente = min(1,t/0.08).*min(1,(3-t)/0.12);
izq = 0.22*sin(2*pi*220*t)+0.13*sin(2*pi*440*t)+0.07*sin(2*pi*6000*t);
der = 0.21*sin(2*pi*330*t)+0.12*sin(2*pi*880*t)+0.06*sin(2*pi*7500*t);
pulso = exp(-((t-0.55)/0.012).^2).*sin(2*pi*1700*t);
x = [izq+0.15*pulso,der+0.12*pulso].*envolvente;
entrada = fullfile(raiz,'audio','prueba.wav');
audiowrite(entrada,x,fs,'BitsPerSample',24);
[x,fs] = cargarAudio(entrada); % La demostración procesa la entrada real PCM.
p = parametrosPorDefecto();
p.ganancia = 1.4;
p.ecoActivo = true; p.delaySeg = 0.25; p.alpha = 0.35;
p.distorsionActiva = true; p.intensidad = 2;
p.filtroActivo = true; p.tipoFiltro = 'pasabajos'; p.fc = 2500;
p.velocidad = 1.25;
[y,fsSalida,info] = procesarCadena(x,fs,p);
salida = exportarAudio(y,fsSalida,fullfile(raiz,'audio','resultado_demo.wav'));
fig = figure('Visible','off','Color','white','Position',[100 100 1200 780]);
limpieza = onCleanup(@()close(fig)); %#ok<NASGU>
tiledlayout(fig,2,1);
graficarSenal(x,fs,nexttile); title('Señal original');
graficarSenal(y,fsSalida,nexttile); title('Señal procesada');
exportgraphics(fig,fullfile(raiz,'docs','comparacion_tiempo.png'),'Resolution',150);
clf(fig); tiledlayout(fig,2,1);
[f,m] = calcularFFT(x,fs);
ax = nexttile; plot(ax,f,m); grid(ax,'on'); xlim(ax,[0 fs/2]);
title(ax,'FFT original'); xlabel(ax,'Frecuencia (Hz)'); ylabel(ax,'Magnitud de amplitud');
legend(ax,{'Canal 1','Canal 2'});
[f,m] = calcularFFT(y,fsSalida);
ax = nexttile; plot(ax,f,m); grid(ax,'on'); xlim(ax,[0 fsSalida/2]);
title(ax,'FFT procesada'); xlabel(ax,'Frecuencia (Hz)'); ylabel(ax,'Magnitud de amplitud');
legend(ax,{'Canal 1','Canal 2'});
exportgraphics(fig,fullfile(raiz,'docs','comparacion_fft.png'),'Resolution',150);
informe = struct('entrada',entrada,'procesamiento',info,'exportacion',salida);
fid = fopen(fullfile(raiz,'docs','demostracion_datos.json'),'w','n','UTF-8');
if fid<0, error('AudioFX:Informe','No se pudo guardar la evidencia.'); end
cierre = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(informe,'PrettyPrint',true));
end
