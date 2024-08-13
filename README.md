# RecoverOrphanFields

VapourSynth script to recover animation frames which only exist in a single orphaned field, IVTC processes will drop these as they are unable to match them to another field to produce a full frame, resulting in jerky animation when this happens on panning scenes. This script looks for these orphaned fields and interpolates them into full frames in order to recover them and reproduce the original smoother animation

### Usage
Two functions are required for this to work 

##### frames = RecoverOrphanFields.BeforeIVTC(clip, show=False, HQ=True)
run this before the IVTC process takes place, as it needs to inspect the original un-matched frames to find the orphan fields. returns a list of frames needed by the recovery function, do not use these for anything other than feeding into the next function

```
clip
    input clip
    
show=False
    set this to True to highlight on the final output, in large text, when a frame is a recovered orphaned field

HQ=True
    recovered frames are interpolated with high quality settings then cleaned up with QTGMC placebo.
    set to False to reduce these to much faster settings. recommended set to True for final output
```

##### output = RecoverOrphanFields.RecoverOrphanFields(clip, frames, chroma=False, scene_change=True, ovr="", log="")
run this after the IVTC process to recover the orphans. 
must be given the 'frames' output from the earlier function. 
returns a new clip with the recovered orphans included

```
clip
    input clip

frames
    the list of frames returned by BeforeIVTC()

chroma=False
    enable or disable chroma detection

scene_change=True
    scene changes can cause false positives. if enabled then frames with the properties '_SceneChangePrev' or '_SceneChangeNext'
    set to 1 will be counted as scene changes, this greatly improves reliability and is recommended. you will need a way to
    apply these properties, this script does not detect scene changes by itself

ovr=""
    path to an overrides file in this format:
        # comments are ignored
        1234          # single frame override
        1234-1237     # range of frames override
        1234 -        # do not recover the detected orphan on this frame
        1234 t        # recover the top field
        1234 b        # recover the bottom field

log=""
    path to an output log file, all recovered frames will be written here. recommended to use this to check the output as
    recovered orphans will not always be an improvement over the original frame
```

### Notes
The function is pretty stable especially when given scene change information, and doesn't tend to produce false positives that match an already exsiting frame. However quite often some of the orphans it detects are not an improvement over the original frame, and since the recovery process requires interpolating a single field, half of the vertical resolution is lost when compared to a full frame. So while these orphans can't be called "false positives" it's sometimes still preferable to keep the original full-resolution frame instead of the interpolated orphan. So it's recommended to check the output using a log file, and then use an overrides file to remove any orphans you don't want to keep. Personally I only keep those that definitely add a missing frame of original animation, and remove any where it's just the frame has shifted a bit or there's a glitch in the frame
