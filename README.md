# ManyBeds-MATLAB

MATLAB files of ManyBeds study - SART and Cueing GUI

This code runs with psychtoolbox [Release 3.0.19.17 ](https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/tag/3.0.19.17)

Read here how to install: [Psychtoolbox-3 - Download, Installation, and Update](http://psychtoolbox.org/download.html)

## SART

the following triggers are sent:

| trigger id    | description                                          |
| -------------:| ---------------------------------------------------- |
| **1, 2, 4-9** | Visual *non-target* digit shown (digit value itself) |
| **11**        | Visual *target* digit 3 shown                        |
| **90**        | Thought-probe screen appears                         |
| **91 – 95**   | Participant’s probe answer (keys 1 to 5 → 91–95)     |
| **100**       | Correct key-press to a non-target digit              |
| **101 – 150** | Auditory cue sounds *s1–s50* (`100 + sound ID`)      |
| **199**       | Baseline noise epoch (`100 + 99`)                    |
| **200**       | Commission error: key-press to target digit 3        |
| **254**       | Break screen starts                                  |
| **255**       | Break finished / task resumes                        |



## Cueing

| trigger id | description                                               |
| ---------: | --------------------------------------------------------- |
| **1 – 50** | Play auditory cue *s1 … s50* (main TMR stimuli)           |
|     **99** | Play *baseline* stimulus (ID 99) during normal cueing     |
|    **150** | Background-noise test ON                                  |
|    **151** | Background-noise test OFF                                 |
|    **199** | “Test Sound Volume” trial (baseline stimulus played once) |
|    **250** | **Stop** stimulation series (also sent at experiment end) |
|    **251** | **Start** stimulation series                              |
|    **253** | Experiment finished (final marker)                        |
|    **254** | Lights-off / sleep period begins                          |
|    **255** | Initial experiment-start marker                           |
