%% runPolyMult.m
clear; clc; close all;

% Define sizes: n is a power of 2.
nVals = 2.^(2:12);  % n = 2^?
numTrials = 5;      % Number of trials (first trial is a warm-up)

% Preallocate arrays for timings.
foilTimes = zeros(size(nVals));
karatsubaTimes = zeros(size(nVals));
fftTimes = zeros(size(nVals));

for i = 1:length(nVals)
    n = nVals(i);
    % Generate two random polynomials (coefficient vectors) of length n.
    a = rand(1, n);
    b = rand(1, n);
    
    %% Timing FOIL
    t = 0;
    for trial = 1:(numTrials+1)
        tic;
        cfoil = foil(a, b);
        elapsed = toc;
        if trial > 1  % discard first trial (warm-up)
            t = t + elapsed;
        end
    end
    foilTimes(i) = t / numTrials;
    
    %% Timing Karatsuba
    t = 0;
    for trial = 1:(numTrials+1)
        tic;
        ckara = karatsuba(a, b);
        elapsed = toc;
        if trial > 1
            t = t + elapsed;
        end
    end
    karatsubaTimes(i) = t / numTrials;
    
    %% Timing FFT/IFFT
    t = 0;
    for trial = 1:(numTrials+1)
        tic;
        cfft = fftpoly(a, b);
        elapsed = toc;
        if trial > 1
            t = t + elapsed;
        end
    end
    fftTimes(i) = t / numTrials;
    
    % Optional: verify that all three methods yield similar results.
    if norm(cfoil - ckara) > 1e-6 || norm(cfoil - cfft) > 1e-6
       warning('Discrepancy detected in results for n = %d', n);
    end
end

%% Display the timing data
T = table(nVals', foilTimes', karatsubaTimes', fftTimes', ...
    'VariableNames', {'n', 'FOIL', 'Karatsuba', 'FFT'});
disp(T);

%% Plot the timings on a log-log scale.
figure;
loglog(nVals, foilTimes, 'o-', 'LineWidth', 2); hold on;
loglog(nVals, karatsubaTimes, 's-', 'LineWidth', 2);
loglog(nVals, fftTimes, 'd-', 'LineWidth', 2);
xlabel('Polynomial Size n');
ylabel('Average Time (sec)');
legend('Foil', 'Karatsuba', 'FFT', 'Location', 'NorthWest');
title('Timing Comparison for Polynomial Multiplication Methods');
grid on;

