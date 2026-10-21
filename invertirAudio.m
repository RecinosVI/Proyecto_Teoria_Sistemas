function y = invertirAudio(x)
%INVERTIRAUDIO Invierte el tiempo de una matriz N muestras por C canales.
% y(n,c) = x(N+1-n,c). No intercambia canales ni cambia amplitud o Fs.
% Una fila representa una sola muestra multicanal y queda intacta.
% Usa el mismo contrato DOUBLE y validación que los demás efectos.
x = validarAudio(x);
y = flip(x,1);
end