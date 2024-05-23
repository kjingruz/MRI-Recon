folder_path = '/Users/kjingruz/Library/CloudStorage/OneDrive-McMasterUniversity/Portfolio/MRI Reconstruction/singlecoil_test/';
files = dir(fullfile(folder_path, '*.h5'));

% Number of files to process (limited to 10 for better visualization)
num_files_to_process = min(10, length(files));

for i = 1:num_files_to_process
    file_path = fullfile(folder_path, files(i).name);

    % Read and process k-space data
    kspace_data_struct = h5read(file_path, '/kspace');
    kspace_data_real = kspace_data_struct.r;
    kspace_data_imag = kspace_data_struct.i;

    % Check if the data is stored as cell arrays and handle accordingly
    if iscell(kspace_data_real)
        kspace_data_real = cell2mat(kspace_data_real);
    end
    if iscell(kspace_data_imag)
        kspace_data_imag = cell2mat(kspace_data_imag);
    end

    kspace_data = kspace_data_real + 1i * kspace_data_imag;
    kspace_data = double(kspace_data);

    % Read and process mask data
    mask_data_struct = h5read(file_path, '/mask');
    mask_data = strcmp(mask_data_struct, 'TRUE');
    
    % Ensure the mask data is a 2D logical array
    if ndims(mask_data) > 2
        mask_data = mask_data(:,:,1); % Take the first slice if it's 3D
    end

    % Check dimensions of mask_data and kspace_data
    if ~isequal(size(mask_data), size(kspace_data))
        warning('Mask data dimensions do not match k-space data dimensions for file %s. Mask will not be applied.', files(i).name);
        mask_data = []; % Set mask_data to empty if dimensions do not match
    end

    % Perform reconstruction (example using inverse FFT)
    reconstructed_image = ifftshift(ifft2(ifftshift(kspace_data)));

    % Apply mask if necessary
    if ~isempty(mask_data)
        reconstructed_image = reconstructed_image .* mask_data;
    end

    % Ensure the reconstructed image is 2D
    if ndims(reconstructed_image) > 2
        reconstructed_image = reconstructed_image(:,:,1); % Take the first slice if it's 3D
    end

    % Convert to magnitude image
    magnitude_image = abs(reconstructed_image);

    % Denoise the magnitude image using Non-Local Means (NLM) denoising
    nlm_denoised_image = imnlmfilt(magnitude_image);

    % Automated Quality Assessment (e.g., calculating SNR and MSE)
    signal_power = mean(magnitude_image(:).^2);
    noise_power = var(magnitude_image(:));
    snr = 10 * log10(signal_power / noise_power);
    disp(['SNR for ', files(i).name, ': ', num2str(snr), ' dB']);
    
    mse = immse(magnitude_image, nlm_denoised_image);
    disp(['MSE between original and denoised image for ', files(i).name, ': ', num2str(mse)]);
    
    % Display the reconstructed image and denoised image in separate figures
    figure;
    subplot(1, 3, 1);
    imshow(magnitude_image, []);
    title(['Reconstructed Image: ', files(i).name], 'Interpreter', 'none', 'FontSize', 8);
    
    subplot(1, 3, 2);
    imshow(nlm_denoised_image, []);
    title(['NLM Denoised Image: ', files(i).name], 'Interpreter', 'none', 'FontSize', 8);
    
    subplot(1, 3, 3);
    imshow(abs(magnitude_image - nlm_denoised_image), []);
    title(['Difference Image: ', files(i).name], 'Interpreter', 'none', 'FontSize', 8);
end
