# RecoverOrphanFields
AviSynth script to find single-field animation frames dropped by IVTC field matching

### The problem
You may find when performing IVTC on telecined animation, that in sections with animation on every frame (such as scrolling backgrounds) you will get additional duplicate frames beyond the expected 1-in-5, and on these additional duplicates the animation seems to get "stuck" and will then jump double the distance on the next frame. Step through the video, and if a scrolling background moves around 20 pixels each frame, then when it gets "stuck" it will move around 40 pixels the next frame - and what you see on playback is a jerky scrolling background. This is because a frame of animation only appeared as a single field in the telecine, and the IVTC couldn't find a match for that field so it got dropped in favour of a dup. That frame would have appeared on an interlaced CRT, and is a part of the animation, but the IVTC has removed it resulting in a jerky animation. This script is designed to find these orphaned fields, interpolate them into full frames, and insert them back into the video. The result should be smoother, cleaner animation on those sections where animation frames got dropped. If your videos do not exhibit this problem, then this script won't do anything to help you

### How it works
The script interpolates both top and bottom fields of the current frame before the IVTC rearranges them, then compares these to the previous, current, and next frames from the output of the IVTC to see if they match with any existing frames. If no match is found then it's assumed to be a dropped frame and is inserted over the current frame. The matching is done by comparing edge masks, as this seems to be far more effective than comparing the entire image, so it probably won't work on footage that is not animation (I don't think this problem exists outside of animation anyway). The initial interpolations are done using fast settings, as these have to be done twice for every frame, the frame that gets inserted into the video is recreated using much slower settings to get the best possible results

### How to use it
There are two functions that must both be called, the first one must go immediately before your IVTC function (TFM / Telecide / etc) to capture the two fields before they get turned into frames by the IVTC, and the second function must go immediately after your IVTC, before your decimation, to see if either of these interpolated frames are in fact missing from the output. The main setting to worry about is 'sens' which determines how sensitive the algorithm is. You'll also want to set 'merge' to true while testing, this merges the new frame over the existing frame so you can check if they actually are different - good results will exhibit a ghost of a neighbouring frame when merge=true (the ghost is the original dup that is being overwritten). If you get a recovered frame that doesn't exhibit ghosting when merge=true then it's a false positive and you'll want to change or override settings

Lower sens values will find more missing frames (and more false positives). The default value of 30 is a good starting point. Set 'show' to true on the output to see metrics to help determine a good sens value - a missing frame is found when the X value for a field is below the shown threshold. The threshold is calculated per field for every frame and changes depending on the content (more movement means higher thresholds), the value you give for sens is simply added to X internally to give the value actually shown for X - so if you start with the default sens of 30 then increase it to 35, the values you see for X will be increased by 5 (and so fewer of them will be higher than the thresholds, meaning fewer found frames). A sensible range for sens is around 20-40, values above 45 will not likely find anything ever, and values below about 15 get increasingly chaotic finding more and more false positive. How the algorithm behaves is very dependent on the content, so you'll tend to find overrides need to happen per scene, generally noisier scenes will want slightly higher sens values

The standard algorithm works well on most scenes, the value for sens usually doesn't need adjusting more than by about 5 up or down depending on the scene, or occasionally forcing a detected frame that was removed as a false positive. However occasionally you may find a section with very low thresholds and quite high X values in the metrics, and where you are certain there are missing frames, but you'd need to set sens to be so low that you would just find thousands of false positives. In these situations there is a second, far simpler algorithm that can be enabled simply by using a negative value for sens (the negative is ignored, the sens value will remain positive). This second simple check is not useful for entire videos as it does not adapt to the content, but on these specific scenes with very low thresholds it becomes useful - if a shown threshold value is higher than sens then that is determined to be a missing frame. I've found a couple of scenes where all the thresholds are around 6-8 except for where there's a missing frame and it jumps up to 24-28, so a sens of -20 here means that any threshold over 20 gets detected, and the missing frames get found accurately. You won't want to use this setting unless you specifically encounter this problem 

### Overrides and false positives
The script is designed to try to adapt to different scenes, to reduce the amount of manual intervention needed, and it's also got a couple of ways to try to detect false positives and remove them, but it's still simple and far from perfect and will need some manual overrides, or to be run in sections with different settings. Currently there are two ways it can find and remove false positives - a "double match" is simply when both top and bottom fields produce a missing frame, this is highly unlikely to actually be an orphaned field (in most cases it's a full frame that's been dropped from the IVTC by manual overrides). "Confidence" is a second check that tries to intelligently spot if there's a matching frame that didn't get found using the main test. This second test isn't good enough to find matches on its own, but it's very good at finding matches that were missed, and is almost never wrong. If you think you have a missing frame getting caught as a false positive, use an override file to force it

### Dependencies
Needs NNEDI3 and Masktools2 in your AVS+ plugins path. The script uses ScriptClip() which is unstable in multithreading, I can't get this script to behave in MT and I'm not sure how to fix that, so I don't recommend multithreading sorry

```
# example usage
RecoverOrphanFields_Setup()
Telecide()
RecoverOrphanFields()
Decimate()
```

##### RecoverOrphanFields_Setup(clip c, bool "show")

This must be called immediately before your IVTC function, it interpolates the fields before IVTC rearranges them into full frames. It doesn't change the output and won't affect the IVTC in any way, just make sure this is called immediately before your IVTC, and as with all IVTC functions there must be no processing beforehand that could affect the fields (no cropping smoothing etc)

```
show - 
    if true then recovered frames will be highlighted "Recovered frame" in large lettering, to make it easy 
    to check the results to find false positives. this does not show any metrics, it merely highlights the
    output to help you find frames changed by the script
    
    default: false
```

##### RecoverOrphanFields(clip c, int "sens", bool "show", bool "merge", string "ovr", clip "input", string "output")

This must be called immediately after the IVTC and before the Decimation, and does the job of replacing duplicate 
frames with the lost frames that it finds

```
sens -
    the main setting you are interested in, this changes the sensitivity of the algorithm,  lower values will 
    find more missing frames (and more false positives). if you display metrics using show=true, this value 
    directly changes the values shown for X. the value for sens is simply added to X internally to give the
    value actually shown, so if you increase sens by 5 then the values shown for X will be increased by 5
    
    default: 30
    
show - 
    shows metrics for field matching, values are shown for top and bottom fields. X is how likely that field
    matches an existing frame, if X is below threshold then it's determined to be a missing frame. threshold
    is calculated per frame and cannot be adjusted. recovered frames will be indicated, and false positives
    detected and removed will also be indicated. lastly a * will be shown at the top as a hint, this indicates
    that although a missing frame was not found, reducing sens by 5 would produce a missing frame. may be 
    useful if you're scanning over the video and not finding any missing frames
    
    default: false
    
merge -
    merges recovered frames with the original video instead of overwriting entirely - use this when testing, 
    if the recovered frame is a genuine missing frame then you will see ghosting of a neighbour frame (which
    had been duplicated here). if you don't see ghosting of a neighbour frame then that means the recovered 
    frame perfectly matches the existing frame 
    
    default: false
    
ovr - 
    path to an overrides file, must be enclosed in quotes. see "overrides" section later
    
    default: ""
    
input -
    here you can send a different clip to be inspected for field matches, while the output will still 
    be derived from the main clip "c". the field matching is influenced by noise in particular dot 
    crawl, so you may find it helpful to send a denoised clip here. also if you want to display TFM 
    metrics on screen, this would also influence the field matching, so send a clean clip here
    
    default: null

    # example usage if you want to show TFM metrics on screen
    RecoverOrphanFields_Setup()
    tfm_visible = TFM(show = true)
    tfm_clean = TFM(show = false)
    tfm_visible.RecoverOrphanFields(input = tfm_clean)
  
output -
    path to a plain text output file. any frames that are replaced by this script will be logged to this 
    file, along with the x and threshold values for each frame
    
    default: ""
```
    
### Overrides
You can override decision making using a standard AviSynth ConditionalReader formatted file. It's probably best to read the docs for ConditionalReader() if you don't know what that means - the tldr version is this

comments start with a # and the file can start with comments
the first two non-comment lines must be exactly this :

```
type string
default 
```
after that, single frame overrides are specified with the frame number, a space, and the instruction

```
1578 b
```

a range of overrides are specified with the letter R, a space, the starting frame number, a space, the ending frame number, followed by a space and the instruction
```
R 2000 2035 -
```
  
the override instructions supported by this script are

```
+ (plus sign) : force overwrite this frame if it was found but removed as a false positive
- (minus sign) : ignore this frame (use this to manually remove false positives)
b : overwrite this frame by interpolating the bottom field from the original frame
t : overwrite this frame by interpolating the top field from the original frame
s : use this sens value for this frame (specify the value after a space)
```

```
# example usage
# ignore frame 1500
1500 -

# force frame 2600 to be overwritten despite false positive detection
2600 +

# overwrite frame 1700 with the bottom field and frame 1800 with the top field
1700 b
1800 t

# use sens of 22 for frames 5000 - 8000
R 5000 8000 s 22

```
  
