function app = main(modo)
%MAIN Punto de entrada de MATLAB AudioFX desde src o MATLAB Project.
% MAIN abre la interfaz. MAIN('demo') genera WAV y gráficas sin abrir la app.
clc;
raiz = fileparts(fileparts(mfilename('fullpath')));
addpath(raiz);
addpath(fullfile(raiz,'src'),fullfile(raiz,'effects'),fullfile(raiz,'analysis'));
if nargin > 0
    if strcmpi(modo,'demo')
        app = generarDemostracion();
        return;
    end
    error('AudioFX:Modo','Use main o main(''demo'').');
end
app = iniciarAudioFX();
if nargout == 0
    clear app
end
end
