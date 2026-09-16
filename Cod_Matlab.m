clc;
clear; 
close all;

%% PARAMETRI
PORT = 'COM3';
BAUD = 115200;
N = 512;
SAMPLE_US = 700;
fs = 1e6 / SAMPLE_US;
MIN_FREQ = 80;
ACCESS_DURATION = 3;

SEQ_FREQS = [440, 550, 660];
SEQ_TOLERANCE = 25;
CONFIRM_NEEDED = 2;
SEQ_TIMEOUT = 6;
NOISE_THRESH = 0.08;

fprintf('=== Sistem detectie secventa frecvente ===\n');
fprintf('Secventa: %d Hz → %d Hz → %d Hz\n\n', ...
        SEQ_FREQS(1), SEQ_FREQS(2), SEQ_FREQS(3));
fprintf('fs: %.0f Hz | Nyquist: %.0f Hz\n\n', fs, fs/2);

%% Conectare serial
fprintf('Conectare la %s @ %d baud...\n', PORT, BAUD);
s = serialport(PORT, BAUD);
s.Timeout = 10;
flush(s);
pause(2);

%% Sincronizare inițială
fprintf('Sincronizare...\n');
flush(s);
synced = false;
tries  = 0;
while ~synced && tries < 10000
    b = read(s, 1, 'uint8'); tries = tries + 1;
    if b == 255
        b2 = read(s, 1, 'uint8'); tries = tries + 1;
        if b2 == 255, synced = true; end
    end
end
if ~synced, error('Nu s-a putut sincroniza.'); end
read(s, N * 2, 'uint8');
fprintf('Sincronizat!\n\n');

%% Axa frecvențe & fereastră
f        = (0 : N/2-1) * (fs/N);
win      = hanning(N)';
fMin_idx = find(f >= MIN_FREQ, 1);

%% Interfață grafică
fig = figure('Name', 'Sistem Detectie Secventa Frecvente', ...
             'NumberTitle', 'off', 'Position', [50 50 1100 900]);

ax1 = subplot(3,1,1);
hTimePlot = plot(1:N, zeros(1,N), 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
title('Semnal brut – ADC (neprocesat)');
xlabel('Esantion nr.'); ylabel('Valoare ADC (0-1023)');
ylim([0 1023]); xlim([1 N]); grid on;

ax3 = subplot(3,1,2);
hProcPlot = plot(1:N, zeros(1,N), 'Color', [0.2 0.4 0.8], 'LineWidth', 1);
title('Semnal procesat – dupa DC removal, filtrare spike-uri, fereastra Hanning');
xlabel('Esantion nr.'); ylabel('Amplitudine normalizata');
ylim([-1 1]); xlim([1 N]); grid on;

ax2 = subplot(3,1,3);
hFreqPlot = plot(f, zeros(1,N/2), 'Color', [0.2 0.6 0.2], 'LineWidth', 1.5);
hold on;
colors = {[0.2 0.8 0.2], [0.2 0.6 0.8], [0.8 0.4 0.2]};
labels = {'Ton 1: 440Hz', 'Ton 2: 550Hz', 'Ton 3: 660Hz'};
for i = 1:3
    fill([SEQ_FREQS(i)-SEQ_TOLERANCE SEQ_FREQS(i)+SEQ_TOLERANCE ...
          SEQ_FREQS(i)+SEQ_TOLERANCE SEQ_FREQS(i)-SEQ_TOLERANCE], ...
         [0 0 1 1], colors{i}, 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    xline(SEQ_FREQS(i), '--', 'LineWidth', 1.5, 'Color', colors{i}, ...
          'Label', labels{i}, 'LabelVerticalAlignment', 'bottom');
end
hPeakDot    = scatter(0, 0, 120, 'r', 'filled');
hThreshLine = yline(NOISE_THRESH, 'r:', 'LineWidth', 1.5, ...
                    'Label', 'Prag zgomot', 'LabelVerticalAlignment', 'top');
hold off;
title('Spectru FFT (Hanning window) – Detectie secventa');
xlabel('Frecventa [Hz]'); ylabel('Amplitudine normalizata');
xlim([0 min(fs/2, 1500)]); ylim([0 1]); grid on;

hStatus = annotation('textbox', [0.25 0.01 0.5 0.05], ...
    'String', 'ASTEPT TON 1: 440 Hz', 'FontSize', 13, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'EdgeColor', 'none', ...
    'Color', [0.5 0.5 0.5]);

%% Buclă principală
fprintf('=== Sistem activ. Ctrl+C pentru oprire ===\n\n');
fprintf('%-12s %-12s %-8s %-8s %-25s\n', ...
        'Varf [Hz]', 'Amplitudine', 'Pas', 'Conf.', 'Status');
fprintf('%s\n', repmat('-', 1, 65));

seqStep      = 1;
confirmCount = 0;
lastToneTime = tic;

while true
    % A. Sincronizare și citire bloc
    synced = false;
    tries  = 0;
    while ~synced && tries < 10000
        b = read(s, 1, 'uint8'); tries = tries + 1;
        if b == 255
            b2 = read(s, 1, 'uint8'); tries = tries + 1;
            if b2 == 255, synced = true; end
        end
    end
    if ~synced, continue; end
    rawBytes = read(s, N * 2, 'uint8');

    % B. Decodificare
    raw = double(uint16(rawBytes(1:2:end)) * 256 + ...
                 uint16(rawBytes(2:2:end)));

    % C. Pre-procesare
    x = raw - mean(raw);

    sigma = std(x);
    for k = 1:N
        if abs(x(k)) > 4*sigma
            if k > 1 && k < N
                x(k) = (x(k-1) + x(k+1)) / 2;
            else
                x(k) = 0;
            end
        end
    end

    x = x / (max(abs(x)) + 1e-10);
    x = x .* win;
    x_display = x;

    % D. FFT
    X    = fft(x);
    Xmag = abs(X(1:N/2)) * 2 / N;

    % E. Detecție vârf
    searchRange = fMin_idx : N/2;
    [peakVal, relIdx] = max(Xmag(searchRange));
    peakIdx  = relIdx + fMin_idx - 1;
    peakFreq = f(peakIdx);

    % F. Actualizare grafic
    set(hTimePlot, 'YData', raw);
    set(hProcPlot, 'YData', x_display);
    set(hFreqPlot, 'YData', Xmag);
    set(hPeakDot,  'XData', peakFreq, 'YData', peakVal);
    ax2.YLim = [0, max(0.1, peakVal * 1.3)];
    drawnow limitrate;

    % G. Timeout
    if seqStep > 1 && toc(lastToneTime) > SEQ_TIMEOUT
        fprintf('  [TIMEOUT] Secventa resetata!\n\n');
        write(s, 'T', 'char');
        seqStep      = 1;
        confirmCount = 0;
        set(hStatus, 'String', 'TIMEOUT! ASTEPT TON 1: 440 Hz', ...
            'Color', [0.8 0.1 0.1]);
        drawnow;
        pause(0.5);
        set(hStatus, 'String', 'ASTEPT TON 1: 440 Hz', ...
            'Color', [0.5 0.5 0.5]);
        continue;  % sare direct la următoarea iterație
    end

    % H. Logică secvență
    currentTarget = SEQ_FREQS(seqStep);
    delta         = abs(peakFreq - currentTarget);
    isFreqMatch   = delta < SEQ_TOLERANCE;
    isAboveNoise  = peakVal > NOISE_THRESH;

    if isFreqMatch && isAboveNoise
        confirmCount = confirmCount + 1;
        lastToneTime = tic;
    else
        confirmCount = 0;
    end

    % H2. Verificare secvență invalidă (doar de la pasul 2 încolo)
    if seqStep > 1 && isAboveNoise && ~isFreqMatch
        otherFreqs   = SEQ_FREQS(SEQ_FREQS ~= currentTarget);
        isWrongTone  = any(abs(peakFreq - otherFreqs) < SEQ_TOLERANCE);
        if isWrongTone
            fprintf('  [RESPINS] Frecventa gresita: %.0f Hz in loc de %d Hz!\n\n', ...
                    peakFreq, currentTarget);
            write(s, 'T', 'char');
            seqStep      = 1;
            confirmCount = 0;
            set(hStatus, 'String', 'ACCES RESPINS! SECVENTA INVALIDA', ...
                'Color', [0.8 0.1 0.1]);
            drawnow;
            pause(0.5);
            set(hStatus, 'String', 'ASTEPT TON 1: 440 Hz', ...
                'Color', [0.5 0.5 0.5]);
            continue;  % sare direct la următoarea iterație
        end
    end

    % I. Avansare în secvență
    if confirmCount >= CONFIRM_NEEDED
        fprintf('  >>> TON %d detectat: %.0f Hz <<<\n', seqStep, peakFreq);
        seqStep      = seqStep + 1;
        confirmCount = 0;
        lastToneTime = tic;

        pause(0.8);
        flush(s);

        if seqStep > length(SEQ_FREQS)
            fprintf('\n=============================\n');
            fprintf('  ACCESS GRANTED – %s\n', ...
                    char(datetime('now', 'Format', 'HH:mm:ss')));
            fprintf('=============================\n\n');
            write(s, 'G', 'char');
            set(hStatus, 'String', 'ACCESS GRANTED!', 'Color', [0 0.7 0]);
            drawnow;
            pause(ACCESS_DURATION);
            flush(s);
            seqStep      = 1;
            confirmCount = 0;
            set(hStatus, 'String', 'ASTEPT TON 1: 440 Hz', ...
                'Color', [0.5 0.5 0.5]);
        else
            nextFreq = SEQ_FREQS(seqStep);
            set(hStatus, ...
                'String', sprintf('TON %d OK! ASTEPT TON %d: %d Hz', ...
                                  seqStep-1, seqStep, nextFreq), ...
                'Color', [0.1 0.6 0.8]);
        end
    else
        if seqStep == 1
            statusStr   = sprintf('ASTEPT TON 1: %d Hz', SEQ_FREQS(1));
            statusColor = [0.5 0.5 0.5];
        else
            statusStr   = sprintf('TON %d OK! ASTEPT TON %d: %d Hz  [%.1fs]', ...
                                   seqStep-1, seqStep, SEQ_FREQS(seqStep), ...
                                   toc(lastToneTime));
            statusColor = [0.1 0.6 0.8];
        end
        set(hStatus, 'String', statusStr, 'Color', statusColor);
    end

    % J. Afișare consolă
    fprintf('%-12.1f %-12.4f %-8d %-8d %s\n', ...
            peakFreq, peakVal, seqStep, confirmCount, ...
            sprintf('Astept ton %d: %d Hz', seqStep, SEQ_FREQS(seqStep)));
end