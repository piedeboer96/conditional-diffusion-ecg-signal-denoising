import numpy as np
import torch
# import pickle
import matplotlib.pyplot as plt
from tqdm import tqdm  # Corrected import statement
from pyts.image import MarkovTransitionField
from torch.utils.data import Dataset, DataLoader
from sklearn.model_selection import train_test_split

# Further Reading: 
#       https://medium.com/analytics-vidhya/encoding-time-series-as-images-b043becbdbf3
class EmbeddingGAF:
    def __init__(self):
        pass

    def rescale_time_series(self, X, VMIN=-1, VMAX=1):
        """
        Rescale the time series X to fall within the interval [-1, 1].

        Parameters:
        X (array-like): The input time series.
        VMIN (float): Minimum value for rescaling.
        VMAX (float): Maximum value for rescaling.

        Returns:
        X_rescaled (array-like): The rescaled time series.
        """
        # Min-Max scaling:
        min_ = np.amin(X)
        max_ = np.amax(X)
        scaled_serie = (2 * X - max_ - min_) / (max_ - min_)
        
        # Use np.core.umath.maximum and np.core.umath.minimum for faster rescaling
        X_rescaled = np.core.umath.maximum(np.core.umath.minimum(scaled_serie, VMAX), VMIN)

        return X_rescaled

    def ecg_to_GAF(self, X):
        
        X = X[:128]         # dirty

        # Rescale
        X = self.rescale_time_series(X)

        # Calculate the angular values 'phi' using the rescaled time series
        phi = np.arccos(X)

        # Compute GASF matrix
        N = len(X)
        phi_matrix = np.tile(phi, (N, 1))
        GASF = np.cos((phi_matrix + phi_matrix.T) / 2)

        # Return Tensor (1,x,x) for GASF
        x = torch.tensor(GASF).unsqueeze(0)

        # print('GAF life...')
        # print(x.shape)

        return x

    # Reconstruct
    def GAF_to_ecg(self, gaf):

        # print(gaf.shape)
        restored_ecg = gaf.detach().cpu().numpy()
        
        diagonals = np.diagonal(restored_ecg)

        return diagonals

    def visualize_tensor(self,tensor):
        
        print('Shape', tensor.shape)

        # Convert the tensor to a NumPy array
        image_array = tensor.numpy()

        # Transpose the array to (H, W, C) format
        image_array = image_array.transpose(1, 2, 0)

        # Display the image using Matplotlib
        plt.imshow(image_array)
        plt.axis('off')  # Turn off axis
        plt.show()

    def plot_multiple_timeseries(signals, names):
        num_signals = len(signals)
        
        plt.figure(figsize=(5 * num_signals, 4))

        for i, (signal, name) in enumerate(zip(signals, names), 1):
            plt.subplot(1, num_signals, i)
            plt.plot(signal)
            plt.title(name)
            plt.xlabel('Sample')
            plt.ylabel('Amplitude')

        plt.tight_layout()
        plt.show()