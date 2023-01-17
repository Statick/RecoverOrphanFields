# RecoverOrphanFields
AviSynth script to find single-field animation frames dropped by IVTC field matching

### The problem
You may find when performing IVTC on telecined animation, that in sections with animation on every frame (such as scrolling backgrounds) you will get additional duplicate frames beyond the expected 1-in-5, and on these additional duplicates the animation seems to get "stuck" and will then jump double the distance on the next frame. Step through the video, and if a scrolling background moves say 20 pixels each frame, then when it gets "stuck" it will move around 40 pixels the next frame - and what you see on playback is a jerky scrolling background - this is because a frame of animation only appeared as a single field in the telecine, and the IVTC couldn't find a match for that field so it got dropped in favour of a dup. That frame would have appeared on an interlaced CRT, and is a part of the animation, but the IVTC has removed it resulting in a jerky animation. This script is designed to find these orphaned fields, interpolate them into full frames, and insert them back into the video. The result should be smoother, cleaner animation on those sections where animation frames got dropped. If your videos do not exhibit this problem, then this script won't do anything to help you. The output isn't perfect with one setting over a whole video, you will need to check over the whole output and use overrides to tweak the settings on different sections, if you're not interested in spending a bit of time doing a few overrides then this script isn't for you. Usually my override files are about 15 lines long and I get about 100-200 orphaned frames recovered in a 20 minute episode, so it's not excessive but it's also not fully automatic

### How it works
The script interpolates both top and bottom fields of the current frame before the IVTC rearranges them, then compares these to the previous, current, and next frames from the output of the IVTC to see if they match with any existing frames. If no match is found then it's assumed to be a dropped frame and is inserted into the video over the current frame. It does need some manual intervention so a few tools are given to assist with that. Initial interpolations are done using fast settings as these have to be done twice for every frame, orphaned fields are interpolated using high quality settings to try and generate the best output possible

### How to use it
There are two functions that must both be called, the first one must go immediately before your IVTC function (TFM / Telecide / etc) to capture the two fields before they get turned into frames by the IVTC, and the second function must go immediately after your IVTC, before your decimation, to see if either of these interpolated frames are in fact missing from the output. Adjust 'sens' to tweak the sensitivity of the algorithm, lower values will find more missing frames and more false positives. The default 30 is a good starting place, you may need to increase it to 35 on noisier scenes, a good value should produce nothing but stable results, but may need adjusting for different scenes. Sensible values are between 15 and 40, depending on the scene. Below 15 the output is increasingly chaotic and unusable, over 40 will probably find nothing at all. Set show=true to display metrics on screen, and merge=true to merge the recovered frames with the existing frames so you can check if it's really a new frame (if it's a genuine missing frame then you'll see ghosting of a neighbouring frame, this is the original dup getting replaced, if you don't see ghosting then it actually matches the current frame and you'll want to change something). The metrics are shown for both fields, X is how likely that field has a matching frame, threshold is how high it has to be to count as a match. So if X is below the threshold then no match is found - it's a missing frame. The value of sens is added to X internally to give the value shown, so if you increase sens by 5 then the values you get for X will increase by 5. Threshold is calculated for each field and cannot be adjusted

### Overrides and false positives
The basic algorithm isn't perfect and some of the frames it finds will be false positives, so there's also some checks to try and identify these and remove them. Currently there are two ways it can find and remove false positives - a "double match" is simply when both top and bottom fields produce a missing frame, if both fields are missing then you don't have an orphan (this is usually a full frame that's been dropped from the IVTC by manual overrides). "Confidence" is a second check that tries to intelligently spot if there's a matching frame that didn't get found using the main test. This second test isn't good enough to find matches on its own, but it's very good at finding matches that were missed, and is rarely wrong. If you think you have a missing frame getting caught as a false positive, use an override file to force it

### Dependencies
Needs NNEDI3 and Masktools2 in your AVS+ plugins path. The script uses ScriptClip() which is unstable in multithreading, I can't get this script to behave in MT and I'm not sure how to fix that, so I don't recommend multithreading sorry

### Usage
```
# example usage
RecoverOrphanFields_Setup()
Telecide()
RecoverOrphanFields()
Decimate()
```

##### RecoverOrphanFields_Setup(clip c, bool "show")

This must be called immediately before your IVTC function, it captures the fields before IVTC rearranges them into full frames. It doesn't change the output and won't affect the IVTC in any way, just make sure this is called immediately before your IVTC, and as with all IVTC functions there must be no processing beforehand that could affect the fields (no cropping smoothing etc)

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
    changes the sensitivity of the algorithm, lower values will find more missing frames (and more false 
    positives). if you display metrics using show=true, this value directly changes the values shown for X. 
    the value for sens is simply added to X internally to give the value actually shown, so if you increase 
    sens by 5 then the values shown for X will be increased by 5. negative values activate a second algorithm
    (sens will still use a positive value), see below for details
    
    default: 30
    
show - 
    shows metrics for field matching, values are shown for top and bottom fields. X is how likely that field
    matches an existing frame, threshold determines how high it must be to count as a match. so if X is below 
    threshold then no match was found - it's a missing frame. threshold is calculated per field and cannot be 
    adjusted. occasionally a scene can generate very difficult metrics, with very low thresholds that would 
    require a very low sens value, making it impossible to get stable results. in these cases a second, simple
    algorithm can be used by giving a negative sens value, this will find a missing frame if the threshold goes 
    higher than sens and this works well only on those low-metric scenes
    
    default: false
    
merge -
    merges recovered frames with the original video instead of overwriting entirely - use this when testing, 
    if the recovered frame is a genuine missing frame then you will see ghosting of a neighbour frame (which
    is the dup getting overwritten). if you don't see ghosting of a neighbour frame then that means the recovered 
    frame perfectly matches the existing frame 
    
    default: false
    
ovr - 
    path to an overrides file, must be enclosed in quotes. see "overrides" section later
    
    default: ""
    
input -
    here you can send a different clip to be inspected for field matches, while the output will still 
    be derived from the main clip "c". the field matching is influenced by noise in particular dot 
    crawl, so you may find it helpful to send a denoised clip here. personally I remove dot crawl before 
    running IVTC and find doing that makes this script a lot more stable. also if you want to display TFM 
    metrics on screen, this would also screw up the field matching, so send a clean clip here and you can
    still display those metrics
    
    default: null

    # example usage if you want to show TFM metrics on screen
    RecoverOrphanFields_Setup()
    tfm_visible = TFM(show = true)
    tfm_clean = TFM(show = false)
    tfm_visible.RecoverOrphanFields(input = tfm_clean)
  
output -
    path to a plain text output file. any frames that are replaced by this script will be logged to this 
    file, along with the x and threshold values for each frame, it's a good idea to check this log and
    inspect every frame and its neighbours to make sure you're happy
    
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
  
