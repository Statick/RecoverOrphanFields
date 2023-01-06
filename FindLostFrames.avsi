# FindLostFrames v0.1
#
# script to find hidden animation frames dropped by IVTC pattern matching
# call FindLostFrames_Setup() immediately before IVTC
# call FindLostFrames() immediately after IVTC

Function FindLostFrames_Setup(clip c, bool "show")
{
    global flf_show = Default(show, false)
    global interpolate_hq_b = flf_show ? nnedi3(c, field = 0, qual = 2, nns = 4).Subtitle("Recovered frame (bottom)", align = 5, size = 30) : nnedi3(c, field = 0, qual = 2, nns = 4)
    global interpolate_test_b = nnedi3(c, field = 0, nns = 2)
    global interpolate_hq_t = flf_show ? nnedi3(c, field = 1, qual = 2, nns = 4).Subtitle("Recovered frame (top)", align = 5, size = 30) : nnedi3(c, field = 1, qual = 2, nns = 4)
    global interpolate_test_t = nnedi3(c, field = 1, nns = 2)
}

Function FindLostFrames(clip c, int "thresh", bool "show", string "ovr", clip "input")
{
    global flf_thresh = Default(thresh, 30)
    global int_details = Default(show, false)
    ovr = Default(ovr, "")
    global int_input = input
    
    ScriptClip(c, """
        input = IsClip(int_input) ? int_input : last
        orig = last
        repaired = flf_show ? nnedi3(field = 1, qual = 2, nns = 4).Subtitle("Repaired frame", align = 5, size = 30) : nnedi3(field = 1, qual = 2, nns = 4)
        
        args = MidStr(override, 2)
        value = Value(args)
        thresh = (LeftStr(override, 1) == "v") ? value : flf_thresh
        
        int_c = input.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        int_p = input.SelectEvery(1, -1).mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        int_n = input.SelectEvery(1, 1).mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        test_b = interpolate_test_b.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        test_t = interpolate_test_t.mt_edge(mode = "prewitt", thy1=10, thy2=10).mt_inpand()
        int_c_diff_b = LumaDifference(test_b, int_c)
        int_p_diff_b = LumaDifference(test_b, int_p)
        int_n_diff_b = LumaDifference(test_b, int_n)
        int_c_diff_t = LumaDifference(test_t, int_c)
        int_p_diff_t = LumaDifference(test_t, int_p)
        int_n_diff_t = LumaDifference(test_t, int_n)
        
        ((int_c_diff_b < thresh) || (int_p_diff_b < thresh) || (int_n_diff_b < thresh)) ? last : interpolate_hq_b
        ((int_c_diff_t < thresh) || (int_p_diff_t < thresh) || (int_n_diff_t < thresh)) ? last : interpolate_hq_t
        (override == "b") ? interpolate_hq_b : last
        (override == "t") ? interpolate_hq_t : last
        (override == "-") ? orig : last
        (override == "+") ? repaired : last

        int_details ? \
            Subtitle("Thresh: " + String(thresh) + "\n" + \
                "Cb: " + String(int_c_diff_b) + "\n" + "Pb: " + String(int_p_diff_b) + "\n" + "Nb: " + String(int_n_diff_b) + "\n" + \
                "Ct: " + String(int_c_diff_t) + "\n" + "Pt: " + String(int_p_diff_t) + "\n" + "Nt: " + String(int_n_diff_t), \
                lsp=10, align=9) : last        
    """)
    output = (ovr != "") ? ConditionalReader(ovr, "override") : FrameEvaluate(""" override = "" """)
    return output
}