# RecoverOrphanFields v0.1
# by Statick
#
# AVS script to find hidden animation frames dropped by IVTC pattern matching
# call RecoverOrphanFields_Setup() immediately before IVTC
# call RecoverOrphanFields() immediately after IVTC

Function RecoverOrphanFields_Setup(clip c, bool "show")
{
    global rof_show = Default(show, false)
    global rof_hq_b = rof_show ? nnedi3(c, field = 0, qual = 2, nns = 4).Subtitle("Recovered frame (B)", align = 5, size = 30) : nnedi3(c, field = 0, qual = 2, nns = 4)
    global rof_test_b = nnedi3(c, field = 0, nns = 2)
    global rof_hq_t = rof_show ? nnedi3(c, field = 1, qual = 2, nns = 4).Subtitle("Recovered frame (T)", align = 5, size = 30) : nnedi3(c, field = 1, qual = 2, nns = 4)
    global rof_test_t = nnedi3(c, field = 1, nns = 2)
}

Function RecoverOrphanFields(clip c, int "thresh", int "dthresh", bool "show", bool "merge", string "ovr", clip "input", string "output")
{
    global rof_thresh = Default(thresh, 30)
    global rof_dthresh = Default(dthresh, rof_thresh)
    global rof_details = Default(show, false)
    global rof_merge = Default(merge, false)
    ovr = Default(ovr, "")
    global rof_input = input
    global rof_output = Default(output, "")
    rof_output != "" ? WriteFileStart(c, rof_output, """ "# Frames replaced by RecoverOrphanFields" """) : c

    
    ScriptClip(c, """
        input = IsClip(rof_input) ? rof_input : last
        orig = last
        repaired = rof_show ? nnedi3(field = -1, qual = 2, nns = 4).Subtitle("Repaired frame", align = 5, size = 30) : nnedi3(field = -1, qual = 2, nns = 4)
        
        args = MidStr(override, 2)
        value = Value(args)
        thresh = (LeftStr(override, 1) == "v") ? value : rof_thresh
        dthresh = rof_dthresh
        merge = rof_merge
        
        c = input.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        p = input.SelectEvery(1, -1).mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        n = input.SelectEvery(1, 1).mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        b = rof_test_b.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        t = rof_test_t.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        cb_diff = LumaDifference(b, c)
        pb_diff = LumaDifference(b, p)
        nb_diff = LumaDifference(b, n)
        ct_diff = LumaDifference(t, c)
        pt_diff = LumaDifference(t, p)
        nt_diff = LumaDifference(t, n)
        
        cp_diff = LumaDifference(c, p)
        cn_diff = LumaDifference(c, n)
        frames_diff = Abs(cp_diff - cn_diff)
        
        min_b = Min(cb_diff, pb_diff, nb_diff)
        min_t = Min(ct_diff, pt_diff, nt_diff)
        max_b = Max(cb_diff, pb_diff, nb_diff)
        max_t = Max(ct_diff, pt_diff, nt_diff)
        
        use_b = false
        use_t = false
            
        use_b = (((min_b > thresh) || (override == "b")) && (override != "-")) ? true : false
        use_t = (((min_t > thresh) || (override == "t")) && (use_b == false) && (override != "-")) ? true : false
        
        falsepos = (use_b && ((max_b - min_b) > dthresh)) || (use_t && ((max_t - min_t) > dthresh)) ? true : false
        
        use_b = use_b && (falsepos == false) ? use_b : false
        use_t = use_t && (falsepos == false) ? use_t : false
        
        use_b && !merge ? rof_hq_b : last
        use_t && !merge ? rof_hq_t : last
        use_b && merge ? Merge(last.Greyscale(), rof_hq_b, 0.7) : last
        use_t && merge ? Merge(last.Greyscale(), rof_hq_t, 0.7) : last
        
        (override == "+") ? repaired : last
        
        report = ""
        report = use_b ? " # bottom field (" + String(min_b) + " - " + String(max_b) + ")" : report
        report = use_t ? " # top field (" + String(min_t) + " - " + String(max_t) + ")" : report
        report = falsepos ? " # false positive removed" : report
        
        
        rof_output != "" ? WriteFileIf(last, rof_output, "(use_b == true) || (use_t == true) || (falsepos == true)", "current_frame", "report") : last

        text = "Thresh: " + String(thresh) + "\n\n" + \
                "top c: " + String(ct_diff) + "\n" + "top p: " + String(pt_diff) + "\n" + "top n: " + String(nt_diff) + "\n\n" + \
                "bot c: " + String(cb_diff) + "\n" + "bot p: " + String(pb_diff) + "\n" + "bot n: " + String(nb_diff) + "\n\n" + \
                "Frames diff: " + String(frames_diff) + "\n\n"
                
        text = use_t ? text + "Top field interpolated" : text
        text = use_b ? text + "Bottom field interpolated" : text
        text = falsepos ? text + "False positive removed" : text
                
        rof_details ? Subtitle(text, lsp=10, align=9) : last        
    """)
    output = (ovr != "") ? ConditionalReader(ovr, "override") : FrameEvaluate(""" override = "" """)
    return output
}