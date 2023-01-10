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

Function RecoverOrphanFields(clip c, int "thresh", bool "show", bool "merge", string "ovr", clip "input", string "output")
{
    global rof_thresh = Default(thresh, 30)
    global rof_details = Default(show, false)
    global rof_merge = Default(merge, false)
    ovr = Default(ovr, "")
    global rof_input = input
    global rof_output = Default(output, "")
    rof_output != "" ? WriteFileStart(c, rof_output, """ "# Frames replaced by RecoverOrphanFields" """) : c

    
    ScriptClip(c, """
        input = IsClip(rof_input) ? rof_input : last
        orig = last
        
        args = MidStr(override, 2)
        value = Value(args)
        thresh = (LeftStr(override, 1) == "v") ? value : rof_thresh
        dthresh = 100
        merge = rof_merge
        
        falsemin = 0.15
        falsemax = 0.5
        
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
        
        min_b = Min(cb_diff, pb_diff, nb_diff)
        min_t = Min(ct_diff, pt_diff, nt_diff)
        max_b = Max(cb_diff, pb_diff, nb_diff)
        max_t = Max(ct_diff, pt_diff, nt_diff)
        tot_b = cb_diff + pb_diff + nb_diff
        tot_t = ct_diff + pt_diff + nt_diff
        
        use_b = false
        use_t = false
            
        # basic algorithm - are all 3 metrics over threshold, if true for both fields choose the one with highest metrics
        use_b = (((min_b > thresh) && !(min_t > thresh && tot_t > tot_b) && (override != "-")) || (override == "b")) ? true : false
        use_t = (((min_t > thresh) && !(min_b > thresh && tot_b > tot_t) && (override != "-")) || (override == "t")) ? true : false
        
        # simple false pos detect - is maximum diff higher than minimum diff by more than dthresh 
        falsepos_1 = (use_b && ((max_b - min_b) > dthresh)) || (use_t && ((max_t - min_t) > dthresh)) ? true : false
        
        # complex false pos detect - is one frame diff significantly lower than the other 2 diff, if so it's probably a match
        # higher 2 diffs must be within falsemin of each other and falsemax higher than minimum diff
        
        falsepos_2 = false
        falsepos_2 = (use_b && (cb_diff == min_b) && (Abs(pb_diff - nb_diff) < Min(pb_diff, nb_diff) * falsemin) && (Min(pb_diff, nb_diff) - cb_diff > cb_diff * falsemax)) ? true : falsepos_2
        falsepos_2 = (use_b && (pb_diff == min_b) && (Abs(cb_diff - nb_diff) < Min(cb_diff, nb_diff) * falsemin) && (Min(cb_diff, nb_diff) - pb_diff > pb_diff * falsemax)) ? true : falsepos_2
        falsepos_2 = (use_b && (nb_diff == min_b) && (Abs(cb_diff - pb_diff) < Min(cb_diff, pb_diff) * falsemin) && (Min(cb_diff, pb_diff) - nb_diff > nb_diff * falsemax)) ? true : falsepos_2
        falsepos_2 = (use_t && (ct_diff == min_t) && (Abs(pt_diff - nt_diff) < Min(pt_diff, nt_diff) * falsemin) && (Min(pt_diff, nt_diff) - ct_diff > ct_diff * falsemax)) ? true : falsepos_2
        falsepos_2 = (use_t && (pt_diff == min_t) && (Abs(ct_diff - nt_diff) < Min(ct_diff, nt_diff) * falsemin) && (Min(ct_diff, nt_diff) - pt_diff > pt_diff * falsemax)) ? true : falsepos_2
        falsepos_2 = (use_t && (nt_diff == min_t) && (Abs(ct_diff - pt_diff) < Min(ct_diff, pt_diff) * falsemin) && (Min(ct_diff, pt_diff) - nt_diff > nt_diff * falsemax)) ? true : falsepos_2

        falsepos = ((falsepos_1 || falsepos_2) && (override != "+")) ? true : false
        
        use_b = use_b && (falsepos == false) ? use_b : false
        use_t = use_t && (falsepos == false) ? use_t : false
        
        use_b && !merge ? rof_hq_b : last
        use_t && !merge ? rof_hq_t : last
        use_b && merge ? Merge(Greyscale(last), rof_hq_b, 0.7) : last
        use_t && merge ? Merge(Greyscale(last), rof_hq_t, 0.7) : last
                
        # log output
        report = ""
        report = use_b ? " # bottom field (" + String(min_b) + " - " + String(max_b) + ")" : report
        report = use_t ? " # top field (" + String(min_t) + " - " + String(max_t) + ")" : report        
        rof_output != "" ? WriteFileIf(last, rof_output, "(use_b == true) || (use_t == true) || (falsepos == true)", "current_frame", "report") : last

        # on screen metrics
        text = "Thresh: " + String(thresh) + "\n\n" + \
                "top c: " + String(ct_diff) + "\n" + "top p: " + String(pt_diff) + "\n" + "top n: " + String(nt_diff) + "\n\n" + \
                "bot c: " + String(cb_diff) + "\n" + "bot p: " + String(pb_diff) + "\n" + "bot n: " + String(nb_diff) + "\n\n" 
                
        text = use_t ? text + "Top field interpolated" : text
        text = use_b ? text + "Bottom field interpolated" : text
        text = (falsepos && falsepos_1) ? text + "false positive removed (dthresh " + String(dthresh) + ")\n" : text
        text = (falsepos && falsepos_2) ? text + "false positive removed (smart)\n" : text
                
        rof_details ? Subtitle(text, lsp=10, align=9) : last        
    """)
    output = (ovr != "") ? ConditionalReader(ovr, "override") : FrameEvaluate(""" override = "" """)
    return output
}