#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Jul 19 10:18:40 2025

@author: simon
"""

import os
import ospath
import matplotlib.pyplot as plt
import librosa
import librosa.display
from tqdm import tqdm
import numpy as np

#%% compare two sets of files
def normalize_lims(axs, which='xy'):
    """
    Synchronize axis and/or color (clim) limits across a collection of Matplotlib Axes.

    Parameters
    ----------
    axs : sequence of matplotlib.axes.Axes
        Axes to normalize. Can be a single Axes, list/tuple, or array (e.g., from plt.subplots()).
    which : {'x','y','v','xy','xv','yv','xyv','both','all'}, default 'xy'
        Characters indicate which limits to synchronize:
            'x'  -> xlim
            'y'  -> ylim
            'v'  -> color limits (clim) of the most recently added image on each Axes.
            'z'  -> synonym of v.
            'c'  -> synonym of v.
        Combinations are allowed by concatenation (e.g., 'xy', 'xv', 'yv', 'xyv').
        Back-compat: 'both' == 'xy'.
        Convenience: 'all'  == 'xyv'.

    Notes
    -----
    * For 'v', only the newest image in each Axes (`ax.images[-1]`) is considered/updated.
    * Axes without images are ignored for the global color range calculation.
    * When possible, the image's underlying array is inspected (np.nanmin / np.nanmax).
      If that fails, the current clim from the image is used as a fallback.
    """
    # Flatten / normalize the axes input to a simple list.
    if hasattr(axs, 'flat'):  # numpy array of Axes
        axs = [ax for ax in axs.flat]

    for axis in which:
        if not axis in 'xyzvc':
            raise ValueError(f'Unknown {axis=} in parameter which, only allowed are xyzvc, with v==z')

    # z is synonym with v
    which = which.replace('z', 'v')
    which = which.replace('c', 'v')

    spec = which.lower()
    if spec == 'both':
        spec = 'xy'
    elif spec == 'all':
        spec = 'xyv'

    # canonical order: x, y, v
    spec = ''.join(ch for ch in 'xyv' if ch in spec)

    # --- X limits ---
    if 'x' in spec:
        xlims = [ax.get_xlim() for ax in axs]
        xmin = min(l[0] for l in xlims)
        xmax = max(l[1] for l in xlims)
        for ax in axs:
            ax.set_xlim(xmin, xmax)

    # --- Y limits ---
    if 'y' in spec:
        ylims = [ax.get_ylim() for ax in axs]
        ymin = min(l[0] for l in ylims)
        ymax = max(l[1] for l in ylims)
        for ax in axs:
            ax.set_ylim(ymin, ymax)

    # --- Color limits (v) ---
    if 'v' in spec:
        # Gather all scalar-mappables and their data-driven mins/maxs
        def mappables(ax):
            items = []
            items.extend(ax.images)  # imshow, matshow
            # pcolormesh/quadmesh, scatter with array, etc.
            items.extend([c for c in ax.collections if hasattr(c, 'get_array') and c.get_array() is not None])
            # contourf returns a ContourSet; treat its collections together via its mappable API if present
            # Many ContourSets store a ScalarMappable-like norm and array on the first collection.
            return items

        vmins, vmaxs = [], []
        per_ax_mappables = []
        for ax in axs:
            mapps = mappables(ax)
            per_ax_mappables.append(mapps)
            for m in mapps:
                try:
                    arr = np.asarray(m.get_array())
                    vmins.append(np.nanmin(arr))
                    vmaxs.append(np.nanmax(arr))
                except Exception:
                    try:
                        v0, v1 = m.get_clim()
                        vmins.append(v0); vmaxs.append(v1)
                    except Exception:
                        pass

        if vmins:
            vmin = np.nanmin(vmins)
            vmax = np.nanmax(vmaxs)
            # Avoid degenerate range
            if not np.isfinite(vmin) or not np.isfinite(vmax) or vmin == vmax:
                return
            for ax, mapps in zip(axs, per_ax_mappables):
                for m in mapps:
                    # Works for Normalize/LogNorm; BoundaryNorm may need more bespoke handling
                    m.set_clim(vmin, vmax)
                    # m.changed() is called by set_clim internally; keeps colorbars in sync
    return

# Define both folders
folder1 = './original/'
folder2 = './version_julia/'
out_folder = './spectrograms_comparison/'

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
    # assert sr1==sr2


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
                                      vmin=vmin,
                                      vmax=-vmin,
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


    normalize_lims(axs)
    normalize_lims(axs[:2], 'v')

    # Colorbars
    # fig.colorbar(axs[0].collections[0], ax=axs[0:2], format='%+2.0f dB', location='right')
    # fig.colorbar(im, ax=axs[2], format='%+2.0f dB', location='right')

    plt.tight_layout()
    plt.savefig(out_folder + basename + '_comparison.png')
    # plt.close(fig)

#%%
