# -*- coding: utf-8 -*-
"""
Created on Wed Apr 15 10:40:08 2026

@author: Simon.Kern

Creates a single-file HTML report for a raw EEG file, including:
- annotation counts
- trigger event counts
- per-channel spectrograms
"""
import mne
import sleep_utils  # pip install git+https://github.com/skjerns/sleep-utils
from pathlib import Path
from collections import Counter
import matplotlib.pyplot as plt
import numpy as np
from tqdm import tqdm


file = sleep_utils.gui.choose_file(exts=['edf', 'bdf', 'vhdr', 'fif'])
raw = mne.io.read_raw(file, preload=True)
fname = Path(file).stem

report = mne.Report(title=f'Data Report: {fname}', verbose=False)

# --- Raw overview (PSD + butterfly) ---
report.add_raw(raw, title='Raw Overview', psd=True, butterfly=False)

# --- Annotations summary ---
annotations = raw.annotations
ann_counts = Counter(annotations.description)
total = len(annotations)

ann_html = f'<h3>Annotations ({total} total)</h3>\n<table class="table table-striped">\n'
ann_html += '<tr><th>Description</th><th>Count</th></tr>\n'
for desc, count in sorted(ann_counts.items(), key=lambda x: -x[1]):
    ann_html += f'<tr><td>{desc}</td><td>{count}</td></tr>\n'
ann_html += '</table>'
report.add_html(ann_html, title='Annotations')

# --- Events from triggers ---
try:
    events = mne.find_events(raw, min_duration=3 / raw.info['sfreq'])
    event_counts = Counter(events[:, 2])
    total_events = len(events)

    ev_html = f'<h3>Trigger Events ({total_events} total)</h3>\n<table class="table table-striped">\n'
    ev_html += '<tr><th>Event ID</th><th>Count</th></tr>\n'
    for eid, count in sorted(event_counts.items()):
        ev_html += f'<tr><td>{eid}</td><td>{count}</td></tr>\n'
    ev_html += '</table>'
    report.add_html(ev_html, title='Trigger Events')
except Exception as e:
    report.add_html(f'<p>Could not extract trigger events: {e}</p>',
                    title='Trigger Events')

# --- Interactive topomap + spectrograms ---
import base64
from io import BytesIO
from mne.channels.layout import _find_topomap_coords

eeg_raw = raw.copy().pick('eeg')
ch_names = eeg_raw.ch_names

# try to get 2D topomap coords; fall back to a grid if digitization missing
try:
    pos = _find_topomap_coords(eeg_raw.info, picks='eeg')
    if not np.all(np.isfinite(pos)) or np.allclose(pos, 0):
        raise ValueError('invalid positions')
    has_montage = True
except Exception:
    # try applying a standard montage by name match
    try:
        eeg_raw.set_montage('standard_1020', match_case=False,
                            on_missing='ignore')
        pos = _find_topomap_coords(eeg_raw.info, picks='eeg')
        if not np.all(np.isfinite(pos)):
            raise ValueError
        has_montage = True
    except Exception:
        has_montage = False
        # fall back to a grid layout
        n = len(ch_names)
        cols = int(np.ceil(np.sqrt(n)))
        rows = int(np.ceil(n / cols))
        xs, ys = np.meshgrid(np.arange(cols), np.arange(rows))
        pos = np.column_stack([xs.ravel()[:n], -ys.ravel()[:n]]).astype(float)

# pre-render all spectrograms as base64
spectrograms = {}
fig, ax = plt.subplots(1, 1, figsize=(10, 3))

for ch in tqdm(ch_names, 'creating specgrams'):
    data = eeg_raw.get_data(picks=ch).squeeze()
    ax.clear()
    sleep_utils.specgram_multitaper(data, sfreq=raw.info['sfreq'],
                                    title=str(ch), ax=ax)
    fig.tight_layout()
    plt.pause(0.1)
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=100, bbox_inches='tight')
    buf.seek(0)
    spectrograms[ch] = base64.b64encode(buf.read()).decode('utf-8')
plt.close(fig)

# build SVG topomap
# normalize positions to SVG coordinates
svg_w, svg_h = 400, 400
margin = 40
x_min, x_max = pos[:, 0].min(), pos[:, 0].max()
y_min, y_max = pos[:, 1].min(), pos[:, 1].max()
x_range = x_max - x_min or 1
y_range = y_max - y_min or 1
scale = min((svg_w - 2 * margin) / x_range, (svg_h - 2 * margin) / y_range)

cx, cy = svg_w / 2, svg_h / 2
pos_svg = np.column_stack([
    (pos[:, 0] - pos[:, 0].mean()) * scale + cx,
    -(pos[:, 1] - pos[:, 1].mean()) * scale + cy,  # flip y
])

svg_parts = [
    f'<svg width="{svg_w}" height="{svg_h}" xmlns="http://www.w3.org/2000/svg">',
]
if has_montage:
    head_r = scale * max(x_range, y_range) / 2 + 25
    nose_y = cy - head_r
    svg_parts.append(
        f'<circle cx="{cx}" cy="{cy}" r="{head_r}" fill="none" '
        f'stroke="#888" stroke-width="2"/>'
    )
    svg_parts.append(
        f'<polyline points="{cx-10},{nose_y} {cx},{nose_y-12} {cx+10},{nose_y}" '
        f'fill="none" stroke="#888" stroke-width="2"/>'
    )

for i, ch in enumerate(ch_names):
    x, y = pos_svg[i]
    svg_parts.append(
        f'<circle cx="{x:.1f}" cy="{y:.1f}" r="8" fill="#4a90d9" stroke="#fff" '
        f'stroke-width="1.5" style="cursor:pointer" '
        f'onclick="showSpec(\'{ch}\')" '
        f'onmouseover="this.setAttribute(\'r\',\'11\')" '
        f'onmouseout="this.setAttribute(\'r\',\'8\')"/>'
    )
    svg_parts.append(
        f'<text x="{x:.1f}" y="{y - 12:.1f}" text-anchor="middle" '
        f'font-size="10" fill="#333" style="pointer-events:none">{ch}</text>'
    )

svg_parts.append('</svg>')
svg_str = '\n'.join(svg_parts)

# build JS data object with base64 spectrograms
js_data = ',\n'.join(f'"{ch}": "{b64}"' for ch, b64 in spectrograms.items())

first_ch = ch_names[0]
interactive_html = f"""
<div style="display:flex; flex-direction:column; align-items:center;">
  <p style="color:#666; margin-bottom:5px;">
    Click a channel to view its spectrogram
    {'' if has_montage else '(no digitization available — grid layout)'}
  </p>
  {svg_str}
  <div id="spec-container" style="margin-top:15px; text-align:center;">
    <img id="spec-img" style="max-width:100%;" />
  </div>
</div>
<script>
var specData = {{{js_data}}};
function showSpec(ch) {{
    var img = document.getElementById('spec-img');
    img.src = 'data:image/png;base64,' + specData[ch];
    img.style.display = 'block';
}}
showSpec('{first_ch}');
</script>
"""
report.add_html(interactive_html, title='Channel Spectrograms')

# --- Save ---
out_path = str(Path(file).with_suffix('.html'))
report.save(out_path, open_browser=True, overwrite=True)
print(f'Report saved to {out_path}')
