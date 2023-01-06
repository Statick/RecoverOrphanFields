# FindLostFrames
AviSynth script to find animation frames dropped by IVTC field matching

### The problem
Often when performing IVTC on animated material, scrolling backgrounds can end up jerky, and stepping through the frames before decimating reveals that instead of producing the expected 4 animated frames and 1 duplicated frame, the IVTC has produced additional duplicated frames which interrupt the animation, replacing frames which look like they should have been animated. With a correct pattern of 4 animated frames and 1 dup, a scrolling background will move the same amount each frame, pausing on the dup frame, then continuing to move the same amount. But with these additional duplicated frames, the scrolling background will get "stuck" and then jump double the distance after the dup - indicating that a frame of animation has been lost

### The cause
The reason for this is that the "lost" frame of animation only existed on a single field in the original video, so the IVTC field matcher was unable to find a match for it. These single-field frames would have been displayed on an interlaced CRT display, but an IVTC looking to match up full frames will discard these and replace them with a duplicate of a neighbouring frame. This is most commonly visible in scrolling backgrounds that get "stuck" as random frames get replaced with duplicates, although they can appear anywhere where there is animation on every frame. If you find one of these duplicated frames, and override the field match, one of the match options will give you a heavily combed frame with the "missing" frame visible in the combing - key details won't match up with either neighbouring frame - but because it only exists as one field, it gets dropped. You can sometimes manually override these matches and then let the post-processing clean it up, and it will interpolate that field to produce the missing frame - but as the post processing follows the field parity of the video, this only works if the missing frame exists in the correct field (i.e if your video is TFF then the post processor will interpolate the top field, which is great if that's where your missing frame is, but no good at all if your missing frame is in the bottom field). Not to mention that manually finding these duplicate frames in a video where 20% of frames are already duplicates, and much of the video won't have animation on every frame anyway, is very time consuming!

### The solution
This script is designed to find these missing frames and insert them into the video. It works by performing a very basic (fast) interpolation of each field of a frame, producing a full frame from each, and then comparing these with the output of your IVTC to see if they match with the current frame, or with the nearest neighbours. If one of these interpolated frames has no matches in the IVTC output then it's considered a "missing" frame, and a higher-quality (slower) interpolation is created and overwritten to the output. A faster interpolation is done initially as this has to be done twice for every frame, the slower interpolation only needs to be done as needed

### More info
Because these "missing" frames are usually very noisy, particularly in chroma, the best way of identifying matches I've found has been by comparing edge masks rather than complete images. For this reason I don't think this script will work at all on footage that is not animation (I don't think this problem really exists outside of animation anyway though). The script works very well at finding missing frames while generating a handful of false positives. It's easy to spot false positives - they will match visually with a neighbouring frame - and override them using an override file

### How to use it
There are two functions that must both be called, one immediately before your IVTC function (TFM / Telecide / etc), and one immediately after. The script uses NNEDI3 to interpolate fields so this must exist in your Avisynth plugins path. The default settings work well on the videos I'm working on, I have no idea how effective it will be on other videos
```
# example usage
FindLostFields_Setup()
Telecide()
FindLostFields()
```

##### FindLostFields_Setup(clip c, bool "show")

  This must be called immediately before your IVTC function, it gathers info from the raw fields before IVTC rearranges them into full frames. It doesn't change the output and won't affect the IVTC in any way, just make sure this is called immediately before your IVTC, and as with all IVTC functions there must be no processing beforehand that could affect the fields (no cropping etc)

  show - 
    if true then recovered frames will be labelled "Recovered frame" in large lettering, to make it easy to see when it's working and to find false positives
    
> default: false

##### FindLostFields(clip c, int "thresh", bool "show", string "ovr", clip "input")

  This must be called immediately after the IVTC and does the job of replacing duplicate frames with the lost frames that it finds

  thresh -
    the threshold that determines whether the interpolated frame matches with existing frames, metrics below this value count as matches
    default: 30
    
  show - 
    shows metrics for field matching, for current/previous/next frames and for top/bottom fields. if any of these 6 metrics are below the threshold then that's considered a match and the frame is ignored. metrics are displayed top-right so as not to interfere with metrics being displayed in TFM or Telecide
    
    default: false
    
  ovr - 
    path to an overrides file, must be enclosed in quotes. see "overrides" section later
    
    default: ""
    
  input -
    here you can send a different clip to be inspected for frame matches, while the output will still be derived from the main clip "c". this is useful if you want to display TFM/Telecide metrics while you work on the video, as normally that text being imposed on the video will interfere with the frame matching - instead you can send a "clean" output from TFM here so that the matching is correct, while still allowing the TFM metrics to be visible in the output
    
```
FindLostFrames_Setup(show = true)
tfm_visible = TFM(show = true)
tfm_clean = TFM(show = false)
tfm_visible.FindLostFrames(show = true, input = tfm_clean)
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
  
  a range of overrides are specified with the letter R, a space, the starting frame, a space, and the ending frame, followed by a space and the instruction
  ```
  R 2000 2035 -
  ```
  
the override instructions supported by this script are

  ```
  - (minus sign) : do not overwrite this frame
  b : overwrite this frame by interpolating the bottom field
  t : overwrite this frame by interpolating the top field
  v : use a new threshold value, the new value must be a number and must come after the v and after a space
  + (plus sign) : interpolate a new frame from the bottom field of the IVTC output, this may be useful if you have a frame which exhibits a lot of combing artifcats
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
  
