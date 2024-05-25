% noise_removal_functions.m

function aligned_signal = vertical_align_by_mean(clean_signal, noisy_signal)
    % Function to vertically align signals based on mean difference
    mean_clean = mean(clean_signal);
    mean_noisy = mean(noisy_signal);
    mean_diff = mean_clean - mean_noisy;
    aligned_signal = noisy_signal + mean_diff;
end

function aligned_signal = vertical_align_reconstructed(clean_signal, rec_signal)
    % Function to vertically align reconstructed signals based on mean difference
    vertical_shift_rec = mean(clean_signal) - mean(rec_signal);
    aligned_signal = rec_signal + vertical_shift_rec;
    aligned_signal = double(aligned_signal'); % Transpose and convert to double
end

function y_r = load_and_align_signals(path_to_files, clean_signal)
    % Function to load and align signals from a given path
    files = dir(fullfile(path_to_files, '*.mat'));
    y_r = cell(1, numel(files));
    for i = 1:numel(files)
        file_name = fullfile(path_to_files, files(i).name);
        loaded_data = load(file_name);
        y_r{i} = loaded_data.sig_rec;
    end
    for i = 1:numel(y_r)
        y_r{i} = vertical_align_reconstructed(clean_signal, y_r{i});
    end
end

function [mean_values, std_dev_values] = compute_avg_and_std_dev_MAE(clean_signal, reconstructed_signals)
    % Function to compute MAE from clean and reconstructions, and calculate mean and standard deviation
    num_signals = length(reconstructed_signals);
    MAE_values = zeros(1, num_signals);
    for i = 1:num_signals
        MAE_values(i) = mean(abs(clean_signal' - reconstructed_signals{i}'));
    end
    mean_values = mean(MAE_values);
    std_dev_values = std(MAE_values);
end

function y_LPF = low_pass_filter(x)
    % Function to use low pass filter
    fs = 128; % Sampling rate (Hz)
    fc = 40.60449; % Cutoff frequency (Hz)  - adapted for changed sampling frequency
    N = 14; % Filter length
    phi_d = 0.1047; % Phase delay (rad/Hz)
    fc_norm = fc / fs;
    beta = 0; % Kaiser window parameter
    fir_coeffs = fir1(N-1, fc_norm, 'low', kaiser(N, beta));
    delay = floor((N-1) / 2);
    x = x(:);
    y_LPF = filter(fir_coeffs, 1, [x; zeros(delay, 1)]);
    y_LPF = y_LPF(delay+1:end);
    y_LPF = y_LPF';
end

function y_LMS = lms_filter(x, d)
    % Function to use LMS filter
    x = x(:);
    d = d(:);
    lms = dsp.LMSFilter();
    [y_LMS, ~, ~] = lms(x, d);
    y_LMS = y_LMS';
end

function y_hybrid = hybrid_filter_lms_lpf(x, d)
    % Function to use Hybrid Filter (LMS then LPF)
    y_LMS = lms_filter(x, d);
    y_hybrid = low_pass_filter(y_LMS);
end

function y_hybrid = hybrid_filter_lpf_lms(x, d)
    % Function to use Hybrid Filter (LPF then LMS)
    y_LPF = low_pass_filter(x);
    y_hybrid = lms_filter(y_LPF, d);
end

% yes... 
% - there is a paper : https://ietresearch.onlinelibrary.wiley.com/doi/10.1049/iet-spr.2020.0104#:~:text=For%20base%2Dline%20wander%2C%20and,methods%20for%20composite%20noise%20removal.
function y_wt = wavelet_denoise(x)
    % Function to use wavelet denoising
    y_wt = wdenoise(x, 'DenoisingMethod', 'Sure', 'Wavelet', 'sym6', 'ThresholdRule', 'Soft');
end

function y_MA = moving_average_filter(x)
    % Define the coefficients of the transfer function H(z)
    b = 1/4 * ones(1, 4);  % Numerator coefficients (1/4 * ones(1, 4))
    a = 1;                 % Denominator coefficients (1 - z^-1)

    % Apply filter
    y_MA = filter(b, a, x);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Clean Signal
d = load('noisy_samples/ardb_sig_HR.mat').sig_HR;

% Noise sample
noise = load('noisy_samples/slices/em_slice_ind.mat');

% Noisy Signals at SNR 0, 5, 10 and 15
x0 = load('noisy_samples/samples/ardb_sig_SR_em_snr_00.mat').ardb_sig_SR_em_snr_00;
x1 = load('noisy_samples/samples/ardb_sig_SR_em_snr_05.mat').ardb_sig_SR_em_snr_05;
x2 = load('noisy_samples/samples/ardb_sig_SR_em_snr_10.mat').ardb_sig_SR_em_snr_10;
x3 = load('noisy_samples/samples/ardb_sig_SR_em_snr_15.mat').ardb_sig_SR_em_snr_15;

% Model 1 - Reconstructions
m1_snr_00 = 'reconstructions/model_1/ardb_em_snr_00';
m1_snr_05 = 'reconstructions/model_1/ardb_em_snr_05';
m1_snr_10 = 'reconstructions/model_1/ardb_em_snr_10';
m1_snr_15 = 'reconstructions/model_1/ardb_em_snr_15';

% Model 2 - Reconstructions
m2_snr_00 = 'reconstructions/model_2/ardb_em_snr_00';
m2_snr_05 = 'reconstructions/model_2/ardb_em_snr_05';
m2_snr_10 = 'reconstructions/model_2/ardb_em_snr_10';
m2_snr_15 = 'reconstructions/model_2/ardb_em_snr_15';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Aligning the noisy signals vertically to the clean signal
x0 = vertical_align_by_mean(d, x0);
x1 = vertical_align_by_mean(d, x1);
x2 = vertical_align_by_mean(d, x2);
x3 = vertical_align_by_mean(d, x3);

% Aligning the reconstructed signals to the clean signal - Model 1
m1_y0_list = load_and_align_signals(m1_snr_00, d);
m1_y1_list = load_and_align_signals(m1_snr_05, d);
m1_y2_list = load_and_align_signals(m1_snr_10, d);
m1_y3_list = load_and_align_signals(m1_snr_15, d);

% Aligning the reconstructed signals to the clean signal - Model 2
m2_y0_list = load_and_align_signals(m2_snr_00, d);
m2_y1_list = load_and_align_signals(m2_snr_05, d);
m2_y2_list = load_and_align_signals(m2_snr_10, d);
m2_y3_list = load_and_align_signals(m2_snr_15, d);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Apply LFP
y0_LMS = lms_filter(x0,d);
y1_LMS = lms_filter(x1,d);
y2_LMS = lms_filter(x2,d);
y3_LMS = lms_filter(x3,d);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Visualize the results
figure;

% Plot clean signal
subplot(4, 1, 1);
plot(d);
title('Clean Signal');
xlabel('Sample Index');
ylabel('Amplitude');

% Plot hybrid_lpf_lms signals
subplot(3, 1, 2);
hold on;
plot(y0_LMS);
plot(y1_LMS);
plot(y2_LMS);
plot(y3_LMS);
title('LMS');
xlabel('Sample Index');
ylabel('Amplitude');
legend('SNR 0', 'SNR 5', 'SNR 10', 'SNR 15');
hold off;

% Plot all reconstructions for m1_y{i}_list for i=0,1,2,3
subplot(3, 1, 3);
hold on;
for i = 1:numel(m1_y0_list)
    plot(m1_y0_list{i}, 'DisplayName', 'SNR 0');
end
for i = 1:numel(m1_y1_list)
    plot(m1_y1_list{i}, 'DisplayName', 'SNR 5');
end
for i = 1:numel(m1_y2_list)
    plot(m1_y2_list{i}, 'DisplayName', 'SNR 10');
end
for i = 1:numel(m1_y3_list)
    plot(m1_y3_list{i}, 'DisplayName', 'SNR 15');
end
hold off;
title('Model 1');
xlabel('Sample Index');
ylabel('Amplitude');
legend;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Model 1 - MAE computation
mae_m1_snr_00 = mae(d - m1_y0_list{1});
mae_m1_snr_05 = mae(d - m1_y1_list{1});
mae_m1_snr_10 = mae(d - m1_y2_list{1});
mae_m1_snr_15 = mae(d - m1_y3_list{1});

% Hybrid (LPF -> LMS) - MAE computation]
mae_lms_snr_00 = mae(d - y0_LMS);
mae_lms_snr_05 = mae(d - y1_LMS);
mae_lms_snr_10 = mae(d - y2_LMS);
mae_lms_snr_15 = mae(d - y3_LMS);

% Visualize the MAE results in grouped bar charts
snrs = [0, 5, 10, 15];
mae_model_1 = [mae_m1_snr_00, mae_m1_snr_05, mae_m1_snr_10, mae_m1_snr_15];
mae_LMS = [mae_lms_snr_00, mae_lms_snr_05, mae_lms_snr_10, mae_lms_snr_15];

figure;
bar(snrs, [mae_LMS', mae_model_1']);
xlabel('SNR');
ylabel('Mean Absolute Error (MAE)');
title('Mean Absolute Error (MAE) for Different Models and SNRs');
legend('LMS','Model 1');
grid on;