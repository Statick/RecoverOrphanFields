# RecoverOrphanFields
AviSynth script to find single-field animation frames dropped by IVTC field matching

### The problem
I often find when performing IVTC on animated material, that there will be orphaned fields - single fields that don't have a matching field that allow them to be combined into a full frame - that yet contain good frames of animation. The standard IVTC response to these is to drop them in favour of good matches, and this probably makes sense most of the time, but with animated material this can mean good frames of animation get lost and replaced with duplicates of a neighouring frame, and in scenes where there is animation on every frame - such as with scrolling backgrounds - this results in jerky animation as frames get seemingly randomly replaced with duplicates of their neighbours. You can see this if you step through the output of your IVTC on scenes where there is animation on every frame, and if you see additional duplicates beyond the expected 1-in-5, and that after certain duplicates the scrolling background jumps twice as far as it does on the other frames - this indicates a frame has been replaced with a duplicate of a neighbour. 

These animation frames would have been displayed on an interlaced CRT display, and you'll find that if you bob your video to 60fps then these animation frames appear as single frames in the output (when most animation frames will appear for 2 or 3 frames), but when you perform IVTC they are lost and replaced with a dup of a neighbour, resulting in jerky animation. This script is designed to find those lost frames and insert them back into the video. I have tried numerous settings in multiple IVTC functions, including lots of manual work in YATTA, and none of them seem to have a way to reliably recover these orphaned fields and produce the smooth animation that was intended, the best I have achieved is with manual frame matching overrides to force the field into a match, followed by post processing to interpolate that field into a full frame, but post processing will interpolate the same field every time which means half of your orphans still get lost. And this also requires you to find the orphaned fields yourself in the first place, which is not easy

### The solution
This script is designed to find these orphaned fieds automatically, interpolate them into full frames, and insert them back into the video. It works by performing a very basic (fast) interpolation of each field of a frame, producing a full frame from each, and then comparing these with the output of your IVTC to see if they match with the either current frame, or with one of the nearest neighbours. If one of the interpolated frames has no matches in the IVTC output then it's considered a "missing" frame, and a higher-quality (slower) interpolation is created and overwritten to the output. A faster interpolation is done initially as this has to be done twice for every frame,, the slower interpolation only needs to be done as needed

### More info
Recovered frames are sometimes very noisy, as they were missing half the information that other frames had, and they often land near scene changes as well. To help with cleaning this up, it's possible to generate an output file that lists all the frames that were recovered, you could use this information to run additional denoising on those frames if you wish. Because of how noisy these frames can be, I've found that the best way of identifying matches has been by comparing edge masks rather than complete images - for this reason I don't think this script will work at all on footage that is not animation (I don't think this problem actually exists outside of animation anyway though). The script works very well on the videos I'm working on, finding hundreds of missing frames resulting in much smoother and cleaner animation, while generating a small number of false positives. 

### False positives
This is a simple script and it does not give a flawless output without some manual intervention, and you will need to clean up a few false positives. It's very easy to spot these while inspecting the output if you enable show=true and merge=true - false positives will match visually with a neighbouring frame - so it doesn't take long to inspect the results and clean these up using an override file. It's generally very noisy scenes that confuse the algorithm the most, and usually ones that don't have animation on every frame, so generally false positives will be concentrated in a few scenes that you can easily override entirely. Also note that if you have field matching overrides in your IVTC you can accidentally end up dropping whole good frames from your IVTC (i.e frames that do have two matching fields), this script will find these and insert them back twice (once per field) - this will look like 2 identical replaced frames in a row. If you find this happening, check your IVTC settings as it's better to correct it there and output the original frame once

### How to use it
There are two functions that must both be called, the first one goes immediately before your IVTC function (TFM / Telecide / etc) to interpolate the two fields into new frames, and the second function goes immediately after your IVTC, and before your decimation, to see if either of these frames are in fact missing from the output. The script uses NNEDI3 to interpolate fields so this must exist in your Avisynth plugins path. The default settings work well on the videos I'm working on, I have no idea how effective it will be on other sources
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
    to check the results to find false positives
    
    default: false
```

##### RecoverOrphanFields(clip c, int "thresh", int "dthresh", bool "show", bool "merge", string "ovr", clip "input")

This must be called immediately after the IVTC and before the Decimation, and does the job of replacing duplicate 
frames with the lost frames that it finds

```
thresh -
    the threshold that determines whether the interpolated frame matches with the existing frames, lower 
    values result in more frames being found. increase this value if you're getting a lot of false positives
    
    default: 30
    
dthresh -
    an upper threshold used to remove false positives from the detection, lower values will prevent more 
    false positives. if unspecified, will be the same as `thresh`. raising this to a very high value like 
    100 will prevent false positives from being detected
    
    default: same as thresh
    
show - 
    shows metrics for field matching, the values represent how closely each field matches with the 
    current/previous/next frames. lower values are closer matches, if all 3 values are greater than thresh
    then that field doesn't have a match so is considered a "missing" frame, and will be inserted into the 
    output. however if the difference between the highest and lowest values is higher than dthresh then 
    it's considered a false positive and won't be used. replaced frames and removed false positives will 
    also be indicated with the metrics. this info is displayed top-right so as not to interfere with 
    metrics being displayed by TFM or Telecide
    
    default: false
    
merge -
    merges the output with the original video when frames are replaced, with the original video being show
    in greyscale. use this when checking for false positives so you can see how the replaced frane compares
    to the original as well as the nearest neighbours
    
    default: false
    
ovr - 
    path to an overrides file, must be enclosed in quotes. see "overrides" section later
    
    default: ""
    
input -
    here you can send a different clip to be inspected for frame matches, while the output will still be 
    derived from the main clip "c". this is useful if you want to display TFM/Telecide metrics while you 
    work on the video, as normally that text being imposed on the video will interfere with the frame 
    matching - instead you can send a "clean" output from TFM here so that the matching is correct, while 
    still allowing the TFM metrics to be visible in the output
    
    default: null

    # example usage if you want to show TFM metrics on screen
    RecoverOrphanFields_Setup(show = true)
    tfm_visible = TFM(show = true)
    tfm_clean = TFM(show = false)
    tfm_visible.RecoverOrphanFields(show = true, input = tfm_clean)
    
output -
    path to a plain text output file. any frames that are replaced by this script will be logged to this 
    file 
    
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
- (minus sign) : do not overwrite this frame (use this to clean up false positives)
b : overwrite this frame by interpolating the bottom field from the original frame
t : overwrite this frame by interpolating the top field from the original frame
v : use a new threshold value, the new value must be a number and must come after the v and after a space
+ (plus sign) : interpolate a new frame from the IVTC output rather than the original fields
```

```
# example usage
# do not overwrite frame 1500
1500 -

# overwrite frame 1700 with the bottom field and frame 1800 with the top field
1700 b
1800 t

# use threshold of 20 for frames 5000 - 8000
R 5000 8000 v 20
```
  
