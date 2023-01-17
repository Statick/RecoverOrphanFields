# RecoverOrphanFields v0.2
# by Statick
#
# AVS script to find hidden animation frames dropped by IVTC pattern matching
# call RecoverOrphanFields_Setup() immediately before IVTC
# call RecoverOrphanFields() immediately after IVTC

Function RecoverOrphanFields_Setup(clip c, bool "show")
{
    global rof_show = Default(show, false)
    global rof_hq_b = rof_show ? nnedi3(c, field = 0, qual = 2, nns = 4, nsize = 3).Subtitle("Recovered frame (B)", align = 5, size = 30) : nnedi3(c, field = 0, qual = 2, nns = 4, nsize = 3)
    global rof_test_b = nnedi3(c, field = 0, nns = 2)
    global rof_hq_t = rof_show ? nnedi3(c, field = 1, qual = 2, nns = 4, nsize = 3).Subtitle("Recovered frame (T)", align = 5, size = 30) : nnedi3(c, field = 1, qual = 2, nns = 4, nsize = 3)
    global rof_test_t = nnedi3(c, field = 1, nns = 2)
}

Function RecoverOrphanFields(clip c, int "sens", bool "show", bool "merge", string "ovr", clip "input", string "output")
{
    global rof_sens = Default(sens, 30)
    global rof_show = Default(show, false)
    global rof_merge = Default(merge, false)
    ovr = Default(ovr, "")
    global rof_input = input
    global rof_output = Default(output, "")
    
    global rof_text = "# Frames replaced by RecoverOrphanFields" + Chr(10) + \
        "# sens: " + String(rof_sens) 
        
    rof_output != "" ? WriteFileStart(c, rof_output, "rof_text") : c

    
    ScriptClip(c, """
        input = IsClip(rof_input) ? rof_input : last
        orig = last
        
        ovrL = LeftStr(override, 1)
        args = TrimAll(MidStr(override, 2))
        value = Value(args)
        sens = (ovrL == "s") ? value : rof_sens
        merge = rof_merge
        sc_thresh = 70
        sc_sens = 10
        delta_thresh = 40
        
        simple_check = (sens < 0) ? true : false
        sens = Abs(sens)
        
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
        mid_b = 0
        mid_t = 0
        mid_b = ((max_b == cb_diff) && (min_b == pb_diff)) || ((max_b == pb_diff) && (min_b == cb_diff)) ? nb_diff : mid_b
        mid_b = ((max_b == cb_diff) && (min_b == nb_diff)) || ((max_b == nb_diff) && (min_b == cb_diff)) ? pb_diff : mid_b
        mid_b = ((max_b == pb_diff) && (min_b == nb_diff)) || ((max_b == nb_diff) && (min_b == pb_diff)) ? cb_diff : mid_b
        mid_t = ((max_t == ct_diff) && (min_t == pt_diff)) || ((max_t == pt_diff) && (min_t == ct_diff)) ? nt_diff : mid_t
        mid_t = ((max_t == ct_diff) && (min_t == nt_diff)) || ((max_t == nt_diff) && (min_t == ct_diff)) ? pt_diff : mid_t
        mid_t = ((max_t == pt_diff) && (min_t == nt_diff)) || ((max_t == nt_diff) && (min_t == pt_diff)) ? ct_diff : mid_t
        
        tot_b = cb_diff + pb_diff + nb_diff
        tot_t = ct_diff + pt_diff + nt_diff
                
        # check for scene change
        sc_b = (max_b > sc_thresh) && (max_b - mid_b > mid_b - min_b) && (max_t - mid_t > mid_t - min_t) ? true : false
        sc_t = (max_t > sc_thresh) && (max_t - mid_t > mid_t - min_t) && (max_b - mid_b > mid_b - min_b) ? true : false
        
        # detect algo
        xb = sc_b ? Min(Abs(cb_diff - pb_diff), Abs(cb_diff - nb_diff)) + sens + sc_sens : Abs(cb_diff - pb_diff) + Abs(cb_diff - nb_diff) + sens
        xt = sc_t ? Min(Abs(ct_diff - pt_diff), Abs(ct_diff - nt_diff)) + sens + sc_sens : Abs(ct_diff - pt_diff) + Abs(ct_diff - nt_diff) + sens
        thresh_b = min_b
        thresh_t = min_t
        use_b = (xb < thresh_b || (simple_check && min_b > sens) || ovrL == "b") && (ovrL != "t") && (ovrL != "-") ? true : false
        use_t = (xt < thresh_t || (simple_check && min_t > sens) || ovrL == "t") && (ovrL != "b") && (ovrL != "-") ? true : false
                        
        # check deltas
        dx_b = max_b - mid_b
        dy_b = mid_b - min_b
        delta_b = dy_b / dx_b
        dx_t = max_t - mid_t
        dy_t = mid_t - min_t
        delta_t = dy_t / dx_t
        
        # remove frames that match on both fields
        falsepos_dbl = (use_b && use_t && override != "+" && override != "b" && override != "d") ? true : false

        # remove likely matches with a high delta (this means two highest metrics are far away from the lowest metric, indicating a likely frame match)
        falsepos_delta = (((use_b && (delta_b > delta_thresh && thresh_b - xb < sens)) || (use_t && (delta_t > delta_thresh && thresh_t - xt < sens))) && ovrL != "+" && ovrL != "b" && ovrL != "t") ? true : false    

        # remove false positives
        falsepos = (falsepos_dbl || falsepos_delta) ? true : false
        use_b = (use_b && !falsepos) ? true : false
        use_t = (use_t && !falsepos) ? true : false
        
        # replace frame
        (use_b && !merge) ? rof_hq_b : last
        (use_t && !merge) ? rof_hq_t : last
        (use_b && merge) ? Merge(Greyscale(last), rof_hq_b, 0.8) : last
        (use_t && merge) ? Merge(Greyscale(last), rof_hq_t, 0.8) : last
                
        # log output
        report = ""
        report = use_b ? " # bottom field (x:" + String(xb) + " - th:" + String(thresh_b) + ")" : report
        report = use_t ? " # top field (x:" + String(xt) + " - th:" + String(thresh_t) + ")" : report    
        report = (use_b || use_t) && (override != "") ? report + " ovr: '" + override + "'" : report
        
        rof_output != "" ? WriteFileIf(last, rof_output, "(use_b == true) || (use_t == true)", "current_frame", "report") : last

        # on screen metrics
        text = ((!use_b && xb < thresh_b + 5) || (!use_t && xt < thresh_t + 5)) ? "* " : ""
        text = text + "sens: " + String(sens)
        text = simple_check ? text + " (simple)\n\n" : text + "\n\n"
        
        text = text + "top:\n" + \
                "X: " + String(xt) + "\n" + \
                "thresh: " + String(thresh_t) + "\n\n"                 
                
        text = text + "bot:\n" + \
                "X: " + String(xb) + "\n" + \
                "thresh: " + String(thresh_b) + "\n\n"         
                        
        text = falsepos_dbl ? text + "false pos removed (double match)\n" : text
        text = falsepos_delta ? text + "false pos removed (confidence)\n" : text
        text = (override != "") ? text + "ovr: " + override + "\n" : text
        
        text = (sc_b || sc_t) ? text + "sc\n" : text
                       
        text = use_t ? text + "Top field interpolated\n" : text
        text = use_b ? text + "Bottom field interpolated\n" : text
       
                
        rof_show ? Subtitle(text, lsp=10, align=9) : last        
    """, after_frame = true)
    output = (ovr != "") ? ConditionalReader(ovr, "override") : FrameEvaluate(""" override = "" """)
    return output
}