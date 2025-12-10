# ManyBeds-MATLAB

MATLAB files of ManyBeds study - SART and Cueing GUI

This code runs with psychtoolbox [Release 3.0.19.17 ](https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/tag/3.0.19.17)

Read here how to install: [Psychtoolbox-3 - Download, Installation, and Update](http://psychtoolbox.org/download.html)

#### Version history

```
25.08.2025 v1.0 - initial versioning start
26.08.2025 v1.1 - change white noise to pink noise, add as parameter, fix char<->string issue
27.08.2025 v1.2 - add exception for C11 for sending only a specific trigger. Fix path encoding string/char arrays problems
03.09.2025 v1.3 - add support for flexible baseline sound assignment. Needs new anticlust files with two columns.
09.10.2025 v1.4 - fix errors in logfile output
16.10.2025 v1.5 - fix printing, improve GUI, new sounds, add better output to SART
10.12.2025 v1.6 - fix displaying of japanese and chinese characters
```

## Triggers SART

the following triggers are sent:

| trigger id         | description                                    |
| ------------------:| ---------------------------------------------- |
| **16**             | Probe question                                 |
| **17 – 21**        | Probe answers (keys 1–5 → 17–21)               |
| **32**             | Stimulus shown: *lure* (non-target)            |
| **33**             | Stimulus shown: *target*                       |
| **64**             | Key press detected                             |
| **128 – 178, 227** | Cue onset (*cue IDs 1–51 and 99*: 128 + index) |
| **6**              | Break screen starts                            |
| **7**              | Break finished / task resumes                  |
| **254**            | Experiment start                               |
| **255**            | Experiment end                                 |

## Triggers CUEING

| trigger id         | description                                    |
| ------------------:| ---------------------------------------------- |
| **6**              | Stimulation stopped                            |
| **7**              | Stimulation resumes/starts                     |
| **8**              | Background sound started (manually)            |
| **9**              | Background sound stopped (manually)            |
| **10**             | test sound played (manually)                   |
| **128 – 178, 227** | Cue onset (*cue IDs 1–51 and 99*: 128 + index) |
| **254**            | Experiment start                               |
| **255**            | Experiment end                                 |
