import vapoursynth as vs
import os
from datetime import datetime
import functools
import havsfunc
core = vs.core

MODULE_NAME = 'rof'

def BeforeIVTC(clip, show=False, hq=True):
    
    bot_quick = core.znedi3.nnedi3(clip, field=0, nsize=0, nns=2, qual=1)
    top_quick = core.znedi3.nnedi3(clip, field=1, nsize=0, nns=2, qual=1)
    
    if hq:
        bot_hq = core.znedi3.nnedi3(clip, field=0, nsize=3, nns=4, qual=2)    
        top_hq = core.znedi3.nnedi3(clip, field=1, nsize=3, nns=4, qual=2)
        bot_hq = havsfunc.QTGMC(bot_hq, Preset="placebo", FPSDivisor=2, TFF=True)
        top_hq = havsfunc.QTGMC(top_hq, Preset="placebo", FPSDivisor=2, TFF=True)
    else:
        bot_hq = bot_quick   
        top_hq = top_quick
        bot_hq = havsfunc.QTGMC(bot_hq, Preset="fast", FPSDivisor=2, TFF=True)
        top_hq = havsfunc.QTGMC(top_hq, Preset="fast", FPSDivisor=2, TFF=True)
    
    if show == True:
        bot_hq = core.text.Text(bot_hq, "Recovered frame (B)", alignment=5, scale=3)
        top_hq = core.text.Text(top_hq, "Recovered frame (T)", alignment=5, scale=3)
        
    return bot_quick, top_quick, bot_hq, top_hq
      
    
def RecoverOrphanFields(clip, rof_frames, clean_clip=None, sensitivity=3, chroma=False, scene_change=True, ovr="", log="", details=False):

    bot_quick, top_quick, bot_hq, top_hq = rof_frames 
    
    if chroma:
        if clean_clip:
            testclip = clean_clip
        else:
            testclip = clip
    else:
        if clean_clip:
            testclip = core.std.ShufflePlanes(clean_clip, planes=0, colorfamily=vs.GRAY)
        else:
            testclip = core.std.ShufflePlanes(clip, planes=0, colorfamily=vs.GRAY)
        
        bot_quick = core.std.ShufflePlanes(bot_quick, planes=0, colorfamily=vs.GRAY)
        top_quick = core.std.ShufflePlanes(top_quick, planes=0, colorfamily=vs.GRAY)

                
    c_mask = core.std.Prewitt(testclip).std.Minimum().std.Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
    p_mask = core.std.DuplicateFrames(testclip, 0).std.Prewitt().std.Minimum().std.Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
    n_mask = testclip[1::1].std.Prewitt().std.Minimum().std.Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
    b_mask = core.std.Prewitt(bot_quick).std.Minimum().std.Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
    t_mask = core.std.Prewitt(top_quick).std.Minimum().std.Convolution(matrix=[1, 1, 1, 1, 0, 1, 1, 1, 1])
    
    cb_test = core.std.PlaneStats(c_mask, b_mask, plane=0)
    pb_test = core.std.PlaneStats(p_mask, b_mask, plane=0)
    nb_test = core.std.PlaneStats(n_mask, b_mask, plane=0)
    ct_test = core.std.PlaneStats(c_mask, t_mask, plane=0)
    pt_test = core.std.PlaneStats(p_mask, t_mask, plane=0)
    nt_test = core.std.PlaneStats(n_mask, t_mask, plane=0)
    
    frames = [clip, cb_test, pb_test, nb_test, ct_test, pt_test, nt_test]
    clips = [clip, bot_hq, top_hq]
    
    _ReadOverrides(ovr)
    
    if not 'rof_globals_framedata' in globals():
        global rof_globals_framedata
        rof_globals_framedata = []

    clip = core.std.FrameEval(clip, functools.partial(_GetFrame, clips=clips, sens=sensitivity, scn=scene_change, log=log, details=details), prop_src=frames, clip_src=clips)

    return clip
    
#
# helper functions below
#

def _GetFrame(n, f, clips, sens=3, scn=True, log="", details=False):
    c, bot_hq, top_hq = clips
        
    override = ""
    use_b = False
    use_t = False
   
    if 'rof_globals_overrides' in globals():     
        for ovr in rof_globals_overrides:
            if ovr['start_frame'] == -1 and ovr['argument'] == "s":
                sens = ovr['value']
                
            if n >= ovr['start_frame'] and n <= ovr['end_frame']:
                override = ovr['argument']
                val = ovr['value']              

    if override == "s":
        sens = value
        
    prev = 0
    next = 0
    if scn:
        if '_SceneChangePrev' in f[0].props:
            prev = f[0].props['_SceneChangePrev']
        if '_SceneChangeNext' in f[0].props:
            next = f[0].props['_SceneChangeNext']
            
    if prev == 1 or next == 1:
        scene_change = True
    else:
        scene_change = False
        
        
    cb = f[1].props['PlaneStatsDiff'] * 1000
    pb = f[2].props['PlaneStatsDiff'] * 1000
    nb = f[3].props['PlaneStatsDiff'] * 1000
    ct = f[4].props['PlaneStatsDiff'] * 1000
    pt = f[5].props['PlaneStatsDiff'] * 1000
    nt = f[6].props['PlaneStatsDiff'] * 1000    
                        
    min_b = min(cb, pb, nb)
    min_t = min(ct, pt, nt)
    while len(rof_globals_framedata) < n + 1:
        rof_globals_framedata.append([0, 0, False])
        
    rof_globals_framedata[n] = [min_b, min_t, False]
                           
    if n > 0:
        data_n1 = rof_globals_framedata[n - 1]
    else:
        data_n1 = [min_b, min_t, False]
    
    if n > 1:
        data_n2 = rof_globals_framedata[n - 2]
    else:
        data_n2 = data_n1            

    if n > 2:
        data_n3 = rof_globals_framedata[n - 3]
    else:
        data_n3 = data_n2

    if data_n1 == [0, 0, False]:
        data_n1 = [min_b, min_t]
    if data_n2 == [0, 0, False]:
        data_n2 = data_n1
    if data_n3 == [0, 0, False]:
        data_n3 = data_n2

    thresh_b = (sens * 2 + data_n1[0] + data_n2[0] + data_n3[0]) / 2
    thresh_t = (sens * 2 + data_n1[1] + data_n2[1] + data_n3[1]) / 2
    
    if min_b > thresh_b:
        use_b = True
        
    if min_t > thresh_t:
        use_t = True
        
    # treat scene changes differently
    if scene_change:
        
        # if there's a match, mark as recovered even if it's going to be cancelled, as we will need to cancel the next match as well
        if use_b or use_t:
            rof_globals_framedata[n][2] = True              

        # if both fields reveal data on a scene change then only allow through a strong match
        if use_b and use_t:
            max_both = max(min_b, min_t)
            min_both = min(min_b, min_t)
            thresh_both = (thresh_b + thresh_t) / 2
            if max_both - min_both < thresh_both:
                use_b = False
                use_t = False
                
        # otherwise recalculate with higher thresholds
        else:
            thresh_b += 3
            thresh_t += 3
            use_b = False
            use_t = False
            if min_b > thresh_b:
                use_b = True
        
            if min_t > thresh_t:
                use_t = True
      
    
    # if not a scene change and both fields reveal data, pick the strongest
    if use_b and use_t:
        if min_b - thresh_b > min_t - thresh_t:
            use_b = True
            use_t = False
        else:
            use_b = False
            use_t = True
    
    # if recovery is found on 2 frames in a row
    if n > 0:
        if (use_b == True or use_t == True) and rof_globals_framedata[n - 1][2] == True:
            use_b = False
            use_t = False

    if override == "b":
        use_b = True
        use_t = False
    elif override == "t":
        use_b = False
        use_t = True
    elif override == "-":
        use_b = False
        use_t = False
        
    if use_b:
        output = bot_hq
        rof_globals_framedata[n][2] = True        
    elif use_t:
        output = top_hq
        rof_globals_framedata[n][2] = True
    elif override == "-":
        output = c
    else:
        output = c
               
    # debug
    if details:
        msg = "sens: " + str(sens) + "\n\n"
        msg += "B:\n"
        msg += f"x: {min_b:.2f} \n"
        msg += f"th: {thresh_b:.2f} \n\n"
        msg += "T:\n"
        msg += f"x: {min_t:.2f} \n"
        msg += f"th: {thresh_t:.2f} \n\n"
        if scene_change == 1:
            msg += "scene change\n"
        if 'min_both' in locals():
            msg += "Both: " + str(max_both - min_both) + "\n"
            msg += "th: " + str(thresh_both) + "\n"
            
        output = core.text.Text(output, msg, alignment=9)
    
    if log != "":
        dir = os.path.dirname(log)
        if not os.path.exists(dir):
            os.makedirs(dir)
            
        if n == 0:
            f = open(log, "w")
            now = datetime.now()
            s = now.strftime("%d/%m/%Y %H:%M:%S ")
            f.write(s + "Frames with recovered fields\n")
            f.close()
            
        if use_b or use_t:
            s = ""
            if use_b:
                s = "b"
            elif use_t:
                s = "t"
                
            if override == "b" or override == "t":
                s += " (ovr)"
                
            f = open(log, "a")
            f.write(str(n) + " " + s + "\n")
            f.close()
            
    output = core.std.CopyFrameProps(output, clips[0])
    return output
   
def _ReadOverrides(ovr = ""):
  
    if ovr == "":
        return False
        
    if not os.path.exists(ovr):
        return False
        
    global rof_globals_overrides
    rof_globals_overrides = []
        
    f = open(ovr, "r")
    for line in f:
        if not line.startswith("#"):
            ovr_line = _ReadOverrideLine(line.strip())
            if ovr_line != False:
                rof_globals_overrides.append(ovr_line)
            
    f.close()
    return True

def _ReadOverrideLine(line=""):
    if line == "":
        return False

    i_space = line.find(" ")
    i_dash = line.find("-")
    i_default = line.find("default")
    
    # no space - invalid line
    if i_space == -1:
        return False
        
    # default setting
    if i_default > -1 and i_space > -1:
        i_space2 = line.find(" ", i_space + 1)
        if i_space2 == -1:
            arg = line[i_space + 1]
            value = 0
        else:
            arg = line[i_space + 1:i_space2]
            v_str = line[i_space2 + 1:]
            try:
                value = int(v_str)
            except:
                return False     
        
        ovr = {
            'start_frame': -1, 
            'end_frame': -1, 
            'argument': arg, 
            'value': value
        }
        return ovr     

    # single frame override
    if i_dash == -1 or (i_dash > -1 and i_space < i_dash):
        f_str = line[:i_space]
        try:
            frame = int(f_str)
        except:
            return False
            
        i_space2 = line.find(" ", i_space + 1)
        if i_space2 == -1:
            arg = line[i_space + 1]
            value = 0
        else:
            arg = line[i_space + 1:i_space2]
            v_str = line[i_space2 + 1:]
            try:
                value = int(v_str)
            except:
                return False
            
        ovr = {
            'start_frame': frame, 
            'end_frame': frame, 
            'argument': arg, 
            'value': value
        }
        return ovr     

    # range override
    if i_dash > -1 and i_space > i_dash:
        f1_str = line[:i_dash]
        try:
            frame1 = int(f1_str)
        except:
            return False
            
        f2_str = line[i_dash + 1:i_space]
        try:
            frame2 = int(f2_str)
        except:
            return False
            
        i_space2 = line.find(" ", i_space + 1)
        if i_space2 == -1:
            arg = line[i_space + 1]
            value = 0
        else:
            arg = line[i_space + 1:i_space2]
            v_str = line[i_space2 + 1:]
            try:
                value = int(v_str)
            except:
                return False
   
        #ovr = [frame1, frame2, arg, value]
        ovr = {
            'start_frame': frame1, 
            'end_frame': frame2, 
            'argument': arg, 
            'value': value
        }
        return ovr
    return False
   
