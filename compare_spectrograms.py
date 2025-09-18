#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Jul 19 10:18:40 2025

@author: simon
"""
import os
import ospath
import json
import matplotlib.pyplot as plt
import librosa
import librosa.display
import numpy as np

folder = '/home/simon/zi_nextcloud/Shares/Matlabstuff/sounds_standardized_Amherst/'
# folder = '../'
out_folder = folder + '/spectrograms/'
file_list = ospath.list_files(folder, exts='wav')

assert len(file_list)==50
# data = [v[''] for v in norms.values()]




# List to store (filename, spectrogram_dB, sample_rate)
spectrograms = []

# Compute spectrograms
for f in file_list:
    y, sr = librosa.load(f, sr=None)
    S = np.abs(librosa.stft(y, n_fft=1024, hop_length=512))
    S_db = librosa.amplitude_to_db(S, ref=np.max)
    spectrograms.append((f, S_db, sr))

# Determine global vmin and vmax
vmin = min(S_db.min() for _, S_db, _ in spectrograms)
vmax = max(S_db.max() for _, S_db, _ in spectrograms)

os.makedirs(out_folder, exist_ok=True)

#%% Plot individually
for filename, S_db, sr in spectrograms:
    plt.figure()
    plt.title(basename:=ospath.basename(filename))
    librosa.display.specshow(
        S_db,
        sr=sr,
        hop_length=512,
        x_axis='time',
        y_axis='hz',
        vmin=vmin,
        vmax=vmax
    )
    plt.colorbar(format='%+2.0f dB')
    plt.tight_layout()
    plt.pause(0.1)
    plt.savefig(out_folder + basename + '.png')
plt.show()
fig, axs = plt.subplots(7, 8, share_x=True, share_y=True)

#%% Plot in one big
for filename, S_db, sr in enumerate(spectrograms):
    plt.figure()
    plt.title(basename:=ospath.basename(filename))
    librosa.display.specshow(
        S_db,
        sr=sr,
        hop_length=512,
        x_axis='time',
        y_axis='hz',
        vmin=vmin,
        vmax=vmax
    )
    # plt.colorbar(format='%+2.0f dB')
    plt.tight_layout()
    plt.pause(0.1)
    plt.savefig(out_folder + basename + '.png')


stop
#%% compare two sets of files

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Jul 19 10:18:40 2025
Modified to compare spectrograms from two folders side by side.

@author: simon
"""
import os
import ospath
import matplotlib.pyplot as plt
import librosa
import librosa.display
from tqdm import tqdm
import numpy as np

# Define both folders
folder1 = '/home/simon/zi_nextcloud/Shares/Matlabstuff/sounds_original/'
folder2 = '/home/simon/zi_nextcloud/Shares/Matlabstuff/sounds_standardized_Amherst/'
out_folder = folder1 + '/spectrograms_comparison/'

file_list1 = ospath.list_files(folder1, exts='wav')
file_list2 = ospath.list_files(folder2, exts='wav')

# Make sure same files exist in both
assert len(file_list1) == len(file_list2), "Folders must contain same number of files"
assert sorted([ospath.basename(f) for f in file_list1]) == sorted([ospath.basename(f) for f in file_list2]), "Filenames differ"

# Compute spectrograms for both folders
spectrograms1, spectrograms2 = [], []
for f1, f2 in zip(sorted(file_list1), sorted(file_list2)):
    y1, sr1 = librosa.load(f1, sr=None)
    y2, sr2 = librosa.load(f2, sr=None)

    S1 = np.abs(librosa.stft(y1, n_fft=1024, hop_length=512))
    S2 = np.abs(librosa.stft(y2, n_fft=1024, hop_length=512))

    S1_db = librosa.amplitude_to_db(S1, ref=np.max)
    S2_db = librosa.amplitude_to_db(S2, ref=np.max)

    spectrograms1.append((f1, S1_db, sr1))
    spectrograms2.append((f2, S2_db, sr2))

# Determine global vmin and vmax across both folders
vmin = min(S_db.min() for _, S_db, _ in spectrograms1 + spectrograms2)
vmax = max(S_db.max() for _, S_db, _ in spectrograms1 + spectrograms2)

os.makedirs(out_folder, exist_ok=True)
fig, axs = plt.subplots(1, 3, figsize=(18, 5))

# Plot side-by-side comparisons with difference
for (f1, S1_db, sr1), (f2, S2_db, sr2) in zip(tqdm(spectrograms1), spectrograms2):
    basename = ospath.basename(f1)


    for ax in axs: ax.clear()
    fig.suptitle(basename)

    # Folder 1
    librosa.display.specshow(S1_db, sr=sr1, hop_length=512,
                             x_axis='time', y_axis='hz',
                             vmin=vmin, vmax=vmax, ax=axs[0])
    axs[0].set_title("Original")

    # Folder 2
    librosa.display.specshow(S2_db, sr=sr2, hop_length=512,
                             x_axis='time', y_axis='hz',
                             vmin=vmin, vmax=vmax, ax=axs[1])
    axs[1].set_title("Amherst")

    # Difference
    try:
        diff = S1_db - S2_db
        if np.abs(diff).max()>0:
            im = librosa.display.specshow(diff, sr=sr1, hop_length=512,
                                      x_axis='time', y_axis='hz',
                                      cmap='coolwarm',
                                      # vmin=-np.max(np.abs(diff)),
                                      # vmax=np.max(np.abs(diff)),
                                      ax=axs[2])
            axs[2].set_title("Difference")
        else:
            axs[2].text(0.5, 0.5, 'NO DIFFERENCE', ha='center', fontsize=18)

    except ValueError as e:
        axs[2].set_title(f"{e}")
        axs[2].text(0.5, 0.5, 'VALUE ERROR', ha='center', fontsize=18)

        # diff = np.zeros_like(S1_db)


    # Colorbars
    # fig.colorbar(axs[0].collections[0], ax=axs[0:2], format='%+2.0f dB', location='right')
    # fig.colorbar(im, ax=axs[2], format='%+2.0f dB', location='right')

    plt.tight_layout()
    plt.savefig(out_folder + basename + '_comparison.png')
    # plt.close(fig)
