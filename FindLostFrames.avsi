# FindLostFrames v0.1
# by Statick
#
# AVS script to find hidden animation frames dropped by IVTC pattern matching
# call FindLostFrames_Setup() immediately before IVTC
# call FindLostFrames() immediately after IVTC

Function FindLostFrames_Setup(clip c, bool "show")
{
    global flf_show = Default(show, false)
    global flf_hq_b = flf_show ? nnedi3(c, field = 0, qual = 2, nns = 4).Subtitle("Recovered frame (B)", align = 5, size = 30) : nnedi3(c, field = 0, qual = 2, nns = 4)
    global flf_test_b = nnedi3(c, field = 0, nns = 2)
    global flf_hq_t = flf_show ? nnedi3(c, field = 1, qual = 2, nns = 4).Subtitle("Recovered frame (T)", align = 5, size = 30) : nnedi3(c, field = 1, qual = 2, nns = 4)
    global flf_test_t = nnedi3(c, field = 1, nns = 2)
}

Function FindLostFrames(clip c, int "thresh", bool "show", string "ovr", clip "input", string "output")
{
    global flf_thresh = Default(thresh, 30)
    global flf_details = Default(show, false)
    ovr = Default(ovr, "")
    global flf_input = input
    global flf_output = Default(output, "")
    flf_output != "" ? WriteFileStart(c, flf_output, """ "# Frames replaced by FindLostFrames" """) : c

    
    ScriptClip(c, """
        input = IsClip(flf_input) ? flf_input : last
        orig = last
        repaired = flf_show ? nnedi3(field = -1, qual = 2, nns = 4).Subtitle("Repaired frame", align = 5, size = 30) : nnedi3(field = -1, qual = 2, nns = 4)
        
        args = MidStr(override, 2)
        value = Value(args)
        thresh = (LeftStr(override, 1) == "v") ? value : flf_thresh
        
        c = input.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        p = input.SelectEvery(1, -1).mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        n = input.SelectEvery(1, 1).mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        b = flf_test_b.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        t = flf_test_t.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        cb_diff = LumaDifference(b, c)
        pb_diff = LumaDifference(b, p)
        nb_diff = LumaDifference(b, n)
        ct_diff = LumaDifference(t, c)
        pt_diff = LumaDifference(t, p)
        nt_diff = LumaDifference(t, n)
        
        use_b = false
        use_t = false
            
        use_b = ((((cb_diff > thresh) && (pb_diff > thresh) && (nb_diff > thresh)) || (override == "b")) && (override != "-")) ? true : false
        use_t = ((((ct_diff > thresh) && (pt_diff > thresh) && (nt_diff > thresh)) || (override == "t")) && (use_b == false) && (override != "-")) ? true : false
        
        use_b ? flf_hq_b : last
        use_t ? flf_hq_t : last
        (override == "+") ? repaired : last
        
        report = ""
        report = use_b ? " # bottom field" : report
        report = use_t ? " # top field" : report
        
        flf_output != "" ? WriteFileIf(last, flf_output, "(use_b == true) || (use_t == true)", "current_frame", "report") : last

        text = "Thresh: " + String(thresh) + "\n\n" + \
                "Ct: " + String(ct_diff) + "\n" + "Pt: " + String(pt_diff) + "\n" + "Nt: " + String(nt_diff) + "\n\n" + \
                "Cb: " + String(cb_diff) + "\n" + "Pb: " + String(pb_diff) + "\n" + "Nb: " + String(nb_diff)
                
        flf_details ? Subtitle(text, lsp=10, align=9) : last        
    """)
    output = (ovr != "") ? ConditionalReader(ovr, "override") : FrameEvaluate(""" override = "" """)
    return output
}