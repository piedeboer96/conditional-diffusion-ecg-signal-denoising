%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to vertically align signals based on mean difference
function aligned_signal = vertical_align_by_mean(clean_signal, noisy_signal)
    mean_clean = mean(clean_signal);
    mean_noisy = mean(noisy_signal);
    mean_diff = mean_clean - mean_noisy;
    aligned_signal = noisy_signal + mean_diff;
end

% Function to vertically align reconstructed signals based on mean difference
function aligned_signal = vertical_align_reconstructed(clean_signal, rec_signal)
    vertical_shift_rec = mean(clean_signal) - mean(rec_signal);
    aligned_signal = rec_signal + vertical_shift_rec;
    aligned_signal = double(aligned_signal'); % Transpose and convert to double
end

% Function to load and align signals from a given path
function y_r = load_and_align_signals(path_to_files, clean_signal)
    % Initialize an array to store the loaded data
    y_r = cell(1, 6);

    % Load each file and store the data in the array
    for i = 0:5
        % Construct the file name
        file_name = fullfile(path_to_files, sprintf('sig_rec_%d.mat', i));
        % Load the file
        loaded_data = load(file_name);
        % Store the loaded data in the array
        y_r{i+1} = loaded_data.sig_rec;
    end
    
    % Align each signal to the clean signal
    for i = 1:length(y_r)
        y_r{i} = vertical_align_reconstructed(clean_signal, y_r{i});
    end
end

% Function to compute MAE from clean and reconstructions, and calculate mean and standard deviation
function [mean_values, std_dev_values] = compute_avg_and_std_dev_MAE(clean_signal, reconstructed_signals)
    num_signals = length(reconstructed_signals);
    MAE_values = zeros(1, num_signals);
    for i = 1:num_signals
        MAE_values(i) = mean(abs(clean_signal' - reconstructed_signals{i}'));
    end
    mean_values = mean(MAE_values);
    std_dev_values = std(MAE_values);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Clean Signal
d = load('results/ardb/EM/m1_em_snr_3/sig_HR.mat').sig_HR;

% Noisy Signals at SNR 1,3,5
x0 = load('results/ardb/EM/m1_em_snr_1/sig_SR.mat').sig_SR;
x1 = load('results/ardb/EM/m1_em_snr_3/sig_SR.mat').sig_SR;
x2 = load('results/ardb/EM/m1_em_snr_5/sig_SR.mat').sig_SR;

% Reconstructions Model {x} at SNR {y}
m1_snr_1 = 'results/ardb/EM/m1_em_snr_1/sig_rec';
m1_snr_3 = 'results/ardb/EM/m1_em_snr_3/sig_rec';
m1_snr_5 = 'results/ardb/EM/m1_em_snr_5/sig_rec';
m2_snr_1 = 'results/ardb/EM/m2_em_snr_1/sig_rec';
m2_snr_3 = 'results/ardb/EM/m2_em_snr_3/sig_rec';
m2_snr_5 = 'results/ardb/EM/m2_em_snr_5/sig_rec';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Aligning the noisy signals vertically to the clean signal
x0 = vertical_align_by_mean(d, x0);
x1 = vertical_align_by_mean(d, x1);
x2 = vertical_align_by_mean(d, x2);

% Aligning the reconstructed signals vertically to the clean signal
y0_list = load_and_align_signals(m1_snr_1, d);
y1_list = load_and_align_signals(m1_snr_3, d);
y2_list = load_and_align_signals(m1_snr_5, d);
y3_list = load_and_align_signals(m2_snr_1, d);
y4_list = load_and_align_signals(m2_snr_3, d);
y5_list = load_and_align_signals(m2_snr_5, d);

figure;

% Plot y0_list entries on the first row
for i = 1:length(y0_list)
    subplot(3, 6, i);
    plot(y3_list{i});
    title(sprintf('y0\\_%d', i-1));
end

% Plot y1_list entries on the second row
for i = 1:length(y1_list)
    subplot(3, 6, i+6);
    plot(y4_list{i});
    title(sprintf('y1\\_%d', i-1));
end

% Plot y2_list entries on the third row
for i = 1:length(y2_list)
    subplot(3, 6, i+12);
    plot(y5_list{i});
    title(sprintf('y2\\_%d', i-1));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LMS Adaptive Filter

lms = dsp.LMSFilter();  % MATLAB proprietary LMS filter

[y0_LMS, err0, wts0] = lms(x0', d');
[y1_LMS, err1, wts1] = lms(x1', d');
[y2_LMS, err2, wts2] = lms(x2', d');

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Compute MAE for LMS outputs
MAE_LMS_SNR_1 = mean(abs(d' - y0_LMS)); 
MAE_LMS_SNR_3 = mean(abs(d' - y1_LMS));
MAE_LMS_SNR_5 = mean(abs(d' - y2_LMS));

% Compute MAE for reconstructed signals
[y0_MAE_avg, y0_MAE_std] = compute_avg_and_std_dev_MAE(d, y0_list);
[y1_MAE_avg, y1_MAE_std] = compute_avg_and_std_dev_MAE(d, y1_list);
[y2_MAE_avg, y2_MAE_std] = compute_avg_and_std_dev_MAE(d, y2_list);
[y3_MAE_avg, y3_MAE_std] = compute_avg_and_std_dev_MAE(d, y3_list);
[y4_MAE_avg, y4_MAE_std] = compute_avg_and_std_dev_MAE(d, y4_list);
[y5_MAE_avg, y5_MAE_std] = compute_avg_and_std_dev_MAE(d, y5_list);


% Grouped bar chart plot
SNRs = [1, 3, 5];
model1_MAE = [y0_MAE_avg, y1_MAE_avg, y2_MAE_avg];
model2_MAE = [y3_MAE_avg, y4_MAE_avg, y5_MAE_avg];
LMS_MAE = [MAE_LMS_SNR_1, MAE_LMS_SNR_3, MAE_LMS_SNR_5]

figure;
bar(SNRs, [model1_MAE', model2_MAE', LMS_MAE'], 'grouped');
xlabel('SNR');
ylabel('MAE');
legend('Model 1', 'Model 2', 'LMS Adaptive Filter');
title('Mean Absolute Error (MAE) Comparison');


% TODO:
% - update cl