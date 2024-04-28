import matplotlib.pyplot as plt
import torch
import pickle
from torch.optim import Adam
from tqdm import tqdm
from torch.utils.data import DataLoader, Dataset
from torch import device
from sklearn.model_selection import train_test_split

from diffusion import GaussianDiffusion
from unet_SR3 import UNet


# Check if CUDA is available
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

# *************************
# STEP 1: MODELS 
# *************************
   
# # Define parameters of the U-Net (denoising function)
in_channels = 1*2                       # 2x GrayScale 'concat'
out_channels = 1                        # Output will also be GrayScale
inner_channels = 32                     # Depth feature maps, model complexity 
norm_groups = 32                            # Granularity of normalization, impacting convergence
channel_mults = (1, 2, 4, 8, 8)
attn_res = [8]
res_blocks = 3
dropout = 0
with_noise_level_emb = True
image_size = 64

# Instantiate the UNet model
denoise_fn = UNet(
    in_channel=in_channels,
    out_channel=out_channels,
    inner_channel=inner_channels,
    norm_groups=norm_groups,
    channel_mults=channel_mults,
    attn_res=attn_res,
    res_blocks=res_blocks,
    dropout=dropout,
    with_noise_level_emb=with_noise_level_emb,
    image_size=image_size
)

# Define diffusion model parameters
image_size = (64, 64)     # Resized image size
channels = 1              
loss_type = 'l1'
conditional = True        # Currently, the implementation only works conditional

# Noise Schedule from: https://arxiv.org/pdf/2306.01875.pdf
config_diff = {
    'beta_start': 0.0001,
    'beta_end': 0.5,
    'num_steps': 10,      # Reduced number of steps
    'schedule': "quad"
}

# Initialize the Diffusion model 
model = GaussianDiffusion(
    denoise_fn=denoise_fn,
    image_size=image_size,
    channels=channels,
    loss_type=loss_type,
    conditional=conditional,
    config_diff=config_diff
)

# Move models to the GPU if available
denoise_fn.to(device)
model.to(device)

print('STATUS --- Model loaded on device:', device)

# # **************************************
# # STEP 2: DATA LOADING (SMALL)
# # **************************************

# Load specs_clean from pickle
with open('specs_clean_normalized_small.pkl', 'rb') as f:
    specs_clean_original = pickle.load(f)

# Load specs_noisy from pickle
with open('specs_noisy_normalized_small.pkl', 'rb') as f:
    specs_noisy_original = pickle.load(f)

# print('Loaded...')
# exit()

# Dummy....
specs_clean = specs_clean_original[:100]
specs_noisy = specs_noisy_original[:100]

# Remove from memory 
del specs_clean_original
del specs_noisy_original


# Model works with single-point float
specs_clean = [tensor.float() for tensor in specs_clean]  # float.64 --> float.32
specs_noisy = [tensor.float() for tensor in specs_noisy]

print('STATUS --- Data pickle loaded')

# Define a custom PyTorch dataset 
class SpectrogramDataset(Dataset):
    def __init__(self, specs_clean, specs_noisy, transform=None):
        self.specs_clean = specs_clean
        self.specs_noisy = specs_noisy
        self.transform = transform

    def __len__(self):
        return len(self.specs_clean)

    def __getitem__(self, idx):
        spec_clean = self.specs_clean[idx]
        spec_noisy = self.specs_noisy[idx]

        if self.transform:
            spec_clean = self.transform(spec_clean)
            spec_noisy = self.transform(spec_noisy)

        return spec_clean, spec_noisy

# Split the data into training and validation sets
specs_clean_train, specs_clean_val, specs_noisy_train, specs_noisy_val = train_test_split(
    specs_clean, specs_noisy, test_size=0.2, random_state=42)

# Create datasets for training and validation
train_dataset = SpectrogramDataset(specs_clean_train, specs_noisy_train)
val_dataset = SpectrogramDataset(specs_clean_val, specs_noisy_val)

## THIS WILL BE THE DATA FOR MY MODEL TRAINED BELOW
x_in_train = {'HR': specs_clean_train, 'SR': specs_noisy_train}
x_in_test = {'HR': specs_clean_val, 'SR': specs_noisy_val}

# COPY TO VERIFY WITH INFERENCE
x_in_train_original = {'HR': specs_clean_train, 'SR': specs_noisy_train}

# # **************************************
# # STEP 2: TRANING
# # **************************************

# Training Config
config_train = {            ## check this...
    'feats':40,
    'epochs':40,
    'batch_size':8,
    'lr':1.0e-3
}

train_model = 0
save_model = 0
name_diff_model_save  = "diff_model_small_CPU.pth"
name_denoise_fn_save = "denoise_fn_small_CPU.pth"

# Train model...
if train_model == 1: 

    # Define custom dataset class
    class DictDataset(Dataset):
        def __init__(self, data_dict):
            self.data_dict = data_dict
            self.keys = list(data_dict.keys())

        def __len__(self):
            return len(self.data_dict[self.keys[0]])

        def __getitem__(self, index):
            return {k: v[index] for k, v in self.data_dict.items()}

    # Training Configuration
    feats = config_train['feats']
    epochs = config_train['epochs']
    batch_size = config_train['batch_size']
    lr = config_train['lr']

    # Use custom dataset class for training data
    train_dataset = DictDataset(x_in_train)
    train_loader = DataLoader(dataset=train_dataset, batch_size=batch_size, shuffle=True)

    # Define DataLoader for testing dataset
    test_dataset = DictDataset(x_in_test)
    test_loader = DataLoader(dataset=test_dataset, batch_size=batch_size, shuffle=False)

    # device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print('Training on device', device)

    # Initialize optimizer
    optimizer = Adam(model.parameters(), lr=lr)

    print('Status: Training Model')

    best_loss = float('inf')  # Initialize the best loss as positive infinity

    # Training Loop
    for epoch in range(epochs):
        model.train()
        total_loss = 0.0
        
        # Create tqdm progress bar
        pbar = tqdm(train_loader, desc=f"Epoch {epoch+1}/{epochs}", unit="batch")

        for batch_data in pbar:
            # Move tensors to the GPU if available
            batch_data = {key: val.to(device) for key, val in batch_data.items()}

            # Zero gradients
            optimizer.zero_grad()

            # Forward pass
            loss = model(batch_data)

            # Backward pass
            loss.backward()

            # Update parameters
            optimizer.step()

            # Accumulate total loss
            total_loss += loss.item()

            # Update progress bar description with current loss
            pbar.set_postfix({'Loss': loss.item()})

        # Calculate average loss for the epoch
        avg_loss = total_loss / len(train_loader)

        # Check if current model is the best so far
        if avg_loss < best_loss:
            best_loss = avg_loss
            best_model_state_dict = model.state_dict()

        # Print progress
        print(f"Epoch [{epoch+1}/{epochs}], Avg Loss: {avg_loss:.4f}")

# Save model...  
if save_model ==  1: 
   
    print('Status: Saving Models')

    # Save diffusion model (model)
    torch.save(model.state_dict(), name_diff_model_save)

    # Save denoising model (UNet) (denoise_fn)
    torch.save(model.denoise_fn.state_dict(), name_denoise_fn_save)

# *************************************************
# Step 4: Inference (or continue training)

print('Status: Inference Time...')

# Load a trained denoiser...
denoise_fun = UNet(
    in_channel=2,
    out_channel=1,
    inner_channel=inner_channels,
    norm_groups=norm_groups,
    channel_mults=channel_mults,
    attn_res=[8],
    res_blocks=res_blocks,
    dropout=dropout,
    with_noise_level_emb=with_noise_level_emb,
    image_size=64
).to(device)  # Move the denoising model to the GPU if available

denoise_fun.load_state_dict(torch.load(name_denoise_fn_save, map_location=device))
denoise_fun.eval()

diffusion = GaussianDiffusion(denoise_fun, image_size=(64,64),channels=1,loss_type='l1',conditional=True,config_diff=config_diff).to(device)  # Move the diffusion model to the GPU if available
diffusion.load_state_dict(torch.load(name_diff_model_save, map_location=device))

print('Status: Diffusion and denoising model loaded successfully')

# Visualizaton Methods 
def visualize_tensor(image_tensors, titles=None):
    num_images = len(image_tensors)

    # Check if titles are provided and if their number matches the number of images
    if titles is not None and len(titles) != num_images:
        print("Error: Number of titles does not match the number of images.")
        return

    # Create subplots based on the number of images
    fig, axes = plt.subplots(1, num_images, figsize=(15, 5))

    # Iterate over images and titles to plot them
    for i, (image_tensor, title) in enumerate(zip(image_tensors, titles)):
        ax = axes[i] if num_images > 1 else axes  # Use appropriate subplot
        ax.axis('off')  # Hide axes
        ax.set_title(title) if title else None  # Set subplot title if provided
        image_np = image_tensor.permute(1, 2, 0).cpu().numpy()  # Convert tensor to numpy array
        if len(image_np.shape) == 2:  # If grayscale
            ax.imshow(image_np, cmap='gray')
        else:  # If RGB
            ax.imshow(image_np)

    plt.show()

# Sample Tensor
sampled_tensor = diffusion.p_sample_loop_single(x_in_train['SR'][20])
sampled_tensor = sampled_tensor.unsqueeze(0)

image_tensors= [x_in_train_original['HR'][20],x_in_train_original['SR'][20],sampled_tensor ]
names = ['Original HR', 'Original SR', 'Sampled Image'] 

# Visualize Results
visualize_tensor(image_tensors,names)

