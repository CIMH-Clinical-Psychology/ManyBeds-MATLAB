# -*- coding: utf-8 -*-
"""
Created on Tue Sep 23 14:05:06 2025

@author: Simon.Kern
"""

import os
import math
import wave
import audioop
import pandas as pd
from natsort import natsorted
import matplotlib.pyplot as plt

def wav_props(path):
    """Return (length_seconds, max_dbfs) for a WAV file.

    Handles 8/16/24/32-bit PCM; multi-channel OK.
    """
    with wave.open(path, 'rb') as wf:
        fr = wf.getframerate()
        nframes = wf.getnframes()
        sw = wf.getsampwidth()
        # Read in chunks to avoid large memory usage
        max_amp = 0
        chunk = 1024 * 32
        while True:
            data = wf.readframes(chunk)
            if not data:
                break
            # WAV 8-bit is unsigned; audioop expects signed. Bias if needed.
            if sw == 1:
                data = audioop.bias(data, 1, -128)
            max_amp = max(max_amp, audioop.max(data, sw))
        length_sec = nframes / float(fr) if fr else 0.0
        # Full-scale per sample width (signed range)
        full_scale = (1 << (8 * sw - 1)) - 1
        if max_amp <= 0 or full_scale <= 0:
            max_db = float('-inf')
        else:
            max_db = 20.0 * math.log10(max_amp / float(full_scale))
        return length_sec, max_db


def compare_wav_dirs(dir1, dir2):
    """Create dataframe comparing same-named WAVs in two directories."""
    files1 = {f for f in os.listdir(dir1) if f.lower().endswith('.wav')}
    files2 = {f for f in os.listdir(dir2) if f.lower().endswith('.wav')}
    common = natsorted(files1 & files2)

    rows = []
    for fname in common:
        p1 = os.path.join(dir1, fname)
        p2 = os.path.join(dir2, fname)
        len1, db1 = wav_props(p1)
        len2, db2 = wav_props(p2)
        rows.append({
            'file': fname[:-4],
            'length_orig': len1,
            'length_clean': len2,
            'lendiff': abs(len1 - len2),
            'maxdb_orig': db1,
            'maxdb_clean': db2,
            'maxdbdiff': abs(db1 - db2) if all(math.isfinite(x) for x in (db1, db2)) else float('nan'),
        })

    df = pd.DataFrame(rows)
    return df


which = 'clean'

# Set your directories here
dir_a = './original/'
dir_b = './version_julia_2'

df = compare_wav_dirs(dir_a, dir_b)
print(df)

df.to_csv('sounds_lengths.csv')

import seaborn as sns
plt.rcParams.update({"font.size": 12})
fig, axs = plt.subplot_mosaic('AB\nCC')
plt.sca(axs['A'])
sns.barplot(df.sort_values(f'maxdb_{which}'), x='file', y=f'maxdb_{which}', ax=axs['A'])
plt.title('Maximum decibel', fontsize=18)
plt.xticks(rotation=90)
plt.ylim(-15, 0)

plt.sca(axs['B'])
sns.barplot(df.sort_values(f'length_{which}'), x='file', y=f'length_{which}', ax=axs['B'])
plt.xticks(rotation=90)
plt.title('Length (seconds)', fontsize=18)
plt.ylim(0, 0.8)

#%%

import os
import math
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.io import wavfile
from scipy.signal import welch


def list_wavs(folder):
    """Return sorted list of .wav file paths in folder."""
    return sorted(
        os.path.join(folder, f)
        for f in os.listdir(folder)
        if f.lower().endswith(".wav")
    )


def load_wav_mono(path):
    """Load WAV as float32 mono in [-1, 1], return (sr, x)."""
    sr, x = wavfile.read(path)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if np.issubdtype(x.dtype, np.integer):
        # Normalize integer PCM to [-1, 1]
        max_abs = np.iinfo(x.dtype).max
        x = x.astype(np.float32) / max_abs
    else:
        x = x.astype(np.float32)
    return sr, x


def power_spectrum_welch(x, sr):
    """Compute Welch PSD; returns (freqs, psd_db_per_hz)."""
    if len(x) == 0:
        return np.array([]), np.array([])
    # Choose segment length adaptively; minimum 2048
    nperseg = 1 << int(np.clip(math.log2(len(x)) - 3, 11, 16))
    nperseg = min(128, len(x))

    freqs, pxx = welch(
        x,
        fs=sr,
        window="hann",
        nperseg=nperseg,
        noverlap=nperseg // 2,
        detrend="constant",
        return_onesided=True,
        scaling="density",
    )
    pxx = np.maximum(pxx, 1e-20)
    psd_db = 10.0 * np.log10(pxx)
    return freqs, psd_db

folder = "./version_julia_2/"

wavs = list_wavs(folder)

df = pd.DataFrame()

for path in natsorted(wavs):
    sr, x = load_wav_mono(path)
    freqs, psd_db = power_spectrum_welch(x, sr)
    df_file = pd.DataFrame({'file': os.path.basename(path[:-4]),
                            'freq': freqs,
                            'db': psd_db})
    df = pd.concat([df, df_file])


sns.lineplot(df, x='freq', y='db', hue='file', ax=axs['C'])
axs['C'].legend(ncols=4, loc='lower right', fontsize=10)
axs['C'].set_title('Power Spectrum', fontsize=18)
axs['C'].set_ylim(-120, 50)
plt.pause(0.1)
plt.tight_layout()
plt.savefig(f'sounds_characteristics_{which}.png')
