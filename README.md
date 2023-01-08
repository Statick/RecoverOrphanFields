# FindLostFrames
AviSynth script to find animation frames dropped by IVTC field matching

### The problem
Often when performing IVTC on animated material, where there is animation on every frame things like scrolling backgrounds can end up jerky, and stepping through the frames before decimating reveals that instead of producing the expected 4 animated frames and 1 duplicated frame, the IVTC has generated additional duplicated frames which randomly interrupt the animation, replacing frames which look like they should have been animated. With a correct pattern of 4 animated frames and 1 dup, a scrolling background will move the same amount each frame, pausing on the dup frame, then continuing to move the same amount. But with these additional duplicated frames, the scrolling background will get "stuck" and then jump double the distance after the dup - suggesting that a frame of animation has been lost. You can also see this after decimation, when on certain frames a scrolling background will jump twice as far compared to the other frames, as if a frame is simply missing entirely. This script is designed to find those "lost" frames and insert them back into the video

### The cause
The reason for this is that the "lost" frame of animation only existed on a single field in the original video, so the IVTC field matcher was unable to find a match for it. These single-field images would have been displayed on an interlaced CRT display, but an IVTC looking to match up full frames will discard these and replace them with a duplicate of a neighbouring frame, which it matched from the other field. This is most commonly visible in scrolling backgrounds that get "stuck" as random frames get replaced with duplicates, although they can appear anywhere where there is animation on every frame. If you find one of these duplicated frames, and manually override the field match without post-processing, one of the match options will give you a heavily combed frame with the "missing" frame visible in the combing - key details in the image won't match up with either neighbouring frame - but because it only exists as one field, the IVTC will normally drop it. You can sometimes manually override these matches and then let the post-processing clean it up, and it will interpolate that field to produce the missing frame in your output - but as the post processing follows the field parity of the video, this only works if the missing frame exists in the correct field (i.e if your video is TFF then the post processor will interpolate the top field, which is great if that's where your missing frame is, but no good at all if your missing frame is in the bottom field). Not to mention that manually finding these duplicate frames in a video where 20% of frames are already duplicates, and much of the video won't have animation on every frame anyway, is very time consuming!

### The solution
This script is designed to find these missing frames and insert them back into the video. It works by performing a very basic (fast) interpolation of each field of a frame, producing a full frame from each, and then comparing these with the output of your IVTC to see if they match with the current frame, or with either of the nearest neighbours. If one of the interpolated frames has no matches in the IVTC output then it's considered a "missing" frame, and a higher-quality (slower) interpolation is created and overwritten to the output. A faster interpolation is done initially as this has to be done twice for every frame so it will impact processing speed, the slower interpolation only needs to be done as needed

### More info
These "missing" frames are sometimes very noisy, particularly in chroma, as they were missing half the information that other frames had, and they often land near scene changes as well. To help with cleaning this up, it's possible to generate an output file that lists all the frames that were replaced, you could use this information to process those frames separately from the rest of the video. Because of how noisy these frames can be, I've found that the best way of identifying matches has been by comparing edge masks rather than complete images - for this reason I don't think this script will work at all on footage that is not animation (I don't think this problem really exists outside of animation anyway though). The script works very well on the videos I'm working on, finding hundreds of missing frames resulting in much smoother and cleaner animation, while generating a small number of false positives. 

### False positives
This script does not give a flawless output without some manual intervention, and you will need to clean up a few false positives. It's very easy to spot these while inspecting the output if you enable show=true and merge=true - false positives will match visually with a neighbouring frame - so it doesn't take long to inspect the results and clean these up using an override file. It's generally whole specific scenes that confuse the algorithm the most, and you'll suddenly get many false positives in a short range of frames, so it's usually easiest to override the whole scene. Also note that if you have field matching overrides in your IVTC you can end up dropping whole good frames from your IVTC, this script will find these and insert them back twice (once per field) - this will look like 2 identical replaced frames in a row. If you find this happening, check your IVTC settings as that's probably where the problem lies

### How to use it
There are two functions that must both be called, the first one goes immediately before your IVTC function (TFM / Telecide / etc) to interpolate the two fields into new frames, and the second function goes immediately after your IVTC to see if either of these frames are in fact missing from the output. The script uses NNEDI3 to interpolate fields so this must exist in your Avisynth plugins path. The default settings work well on the videos I'm working on, I have no idea how effective it will be on other sources
```
# example usage
FindLostFields_Setup()
Telecide()
FindLostFields()
```

##### FindLostFields_Setup(clip c, bool "show")

This must be called immediately before your IVTC function, it interpolates the fields before IVTC rearranges them into full frames. It doesn't change the output and won't affect the IVTC in any way, just make sure this is called immediately before your IVTC, and as with all IVTC functions there must be no processing beforehand that could affect the fields (no cropping smoothing etc)

```
show - 
    if true then recovered frames will be highlighted "Recovered frame" in large lettering, to make it easy 
    to check the results to find false positives
    
    default: false
```

##### FindLostFields(clip c, int "thresh", int "dthresh", bool "show", bool "merge", string "ovr", clip "input")

This must be called immediately after the IVTC and does the job of replacing duplicate frames with the lost 
frames that it finds

```
thresh -
    the threshold that determines whether the interpolated frame matches with the existing frames, lower 
    values result in more frames being found. increase this value if you're getting a lot of false positives
    
    default: 30
    
dthresh -
    an upper threshold used to remove false positives from the detection, lower values will prevent more false
    positives. if unspecified, will be the same as `thresh`. raising this to a very high value like 100 will
    prevent false positives from being detected
    
    default: same as thresh
    
show - 
    shows metrics for field matching, the values represent how closely each field matches with the 
    current/previous/next frames. lower values are closer matches, if all 3 values are greater than thresh
    then that field doesn't have a match so is considered a "missing" frame, and will be inserted into the 
    output. however if the difference between the highest and lowest values is higher than dthresh then 
    it's considered a false positive and won't be used. replaced frames and removed false positives will 
    also be indicated with the metrics. this info is displayed top-right so as not to interfere with metrics 
    being displayed by TFM or Telecide
    
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
    here you can send a different clip to be inspected for frame matches, while the output will still be derived 
    from the main clip "c". this is useful if you want to display TFM/Telecide metrics while you work on the 
    video, as normally that text being imposed on the video will interfere with the frame matching - instead you 
    can send a "clean" output from TFM here so that the matching is correct, while still allowing the TFM metrics 
    to be visible in the output
    
    default: null

    # example usage if you want to show TFM metrics on screen
    FindLostFrames_Setup(show = true)
    tfm_visible = TFM(show = true)
    tfm_clean = TFM(show = false)
    tfm_visible.FindLostFrames(show = true, input = tfm_clean)
    
output -
    path to a plain text output file. any frames that are replaced by this script will be logged to this file 
    
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
  
