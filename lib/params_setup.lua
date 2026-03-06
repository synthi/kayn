-- lib/params_setup.lua v0.516
-- CHANGELOG v0.516:
-- 1. FIX: Añadidos parámetros de Space-Time Core (Mod 9) con mapeo exacto de Encoders.
-- 2. FIX: Reestructuración de Nexus (Mod 10).
-- 3. FIX: Comando m3_ping envía un '1' para evitar crash en Fates.

local Params = {}

function Params.init(G)
    params:add_separator("KAYN CYBERNETICS")
    params:add_group("GLOBAL PHYSICS", 3)
    params:add{type = "control", id = "thermal_drift", name = "System Age", controlspec = controlspec.new(0.0, 1, 'lin', 0.001, 0.02), action = function(x) if not G.booting then engine.set_global_physics("thermal", x) end end}
    params:add{type = "control", id = "morph_time", name = "Morph Time", controlspec = controlspec.new(0.0, 120.0, 'lin', 0.1, 1.0, "s")}
    params:add{type = "control", id = "transformer_drive", name = "Transformer Drive", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.2), action = function(x) if not G.booting then engine.m4_drive(x) end end}

    local function add_node_params(start_id, end_id)
        for i = start_id, end_id do
            local node = G.nodes[i]
            if node then
                params:add{type = "control", id = "node_lvl_" .. i, name = node.name .. " Lvl", controlspec = controlspec.new(-1.0, 1.0, 'lin', 0.01, 0.33), action = function(x) if not G.booting then node.level = x; if node.type == "out" then engine.set_out_level(i, x) else engine.set_in_level(i, x) end end end}
                if node.module == 10 and i >= 57 and i <= 60 then
                    local def_pan = (i == 57 or i == 59) and -1.0 or 1.0
                    params:add{type = "control", id = "node_pan_" .. i, name = node.name .. " Pan", controlspec = controlspec.new(-1.0, 1.0, 'lin', 0.01, def_pan), action = function(x) if not G.booting then node.pan = x; engine.set_in_pan(i, x) end end}
                end
            end
        end
    end

    params:add_group("MOD 1: 1023 DUAL VCO", 24)
    params:add{type = "control", id = "m1_tune1", name = "Osc 1 Tune", controlspec = controlspec.new(0.01, 16000.0, 'exp', 0.001, 100.0, "Hz"), action = function(x) if not G.booting then engine.m1_tune1(x) end end}
    params:add{type = "control", id = "m1_fine1", name = "Osc 1 Fine", controlspec = controlspec.new(-5.0, 5.0, 'lin', 0.001, 0.0, "Hz"), action = function(x) if not G.booting then engine.m1_fine1(x) end end}
    params:add{type = "control", id = "m1_pwm1", name = "Osc 1 PWM", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5), action = function(x) if not G.booting then engine.m1_pwm1(x) end end}
    params:add{type = "control", id = "m1_morph1", name = "Osc 1 Morph", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.001, 0.0), action = function(x) if not G.booting then engine.m1_morph1(x) end end}
    params:add{type = "option", id = "m1_range1", name = "Osc 1 Range", options = {"HI", "LO"}, default = 1, action = function(x) if not G.booting then engine.m1_range1(x - 1) end end}
    params:add{type = "option", id = "m1_pv1_mode", name = "Osc 1 PV Dest", options = {"PWM", "VOCT"}, default = 1, action = function(x) if not G.booting then engine.m1_pv1_mode(x - 1) end end}
    params:add{type = "option", id = "m1_fm1_mode", name = "Osc 1 FM Dest", options = {"LIN", "EXP", "MORPH"}, default = 2, action = function(x) if not G.booting then engine.m1_fm1_mode(x - 1) end end}
    params:add{type = "option", id = "m1_out3_wave", name = "Osc 1 Multi Wave", options = {"SINE", "TRI", "SAW", "SQR", "PULSE"}, default = 1, action = function(x) if not G.booting then engine.m1_out3_wave(x - 1) end end}
    params:add{type = "control", id = "m1_tune2", name = "Osc 2 Tune", controlspec = controlspec.new(0.01, 16000.0, 'exp', 0.001, 101.0, "Hz"), action = function(x) if not G.booting then engine.m1_tune2(x) end end}
    params:add{type = "control", id = "m1_fine2", name = "Osc 2 Fine", controlspec = controlspec.new(-5.0, 5.0, 'lin', 0.001, 0.0, "Hz"), action = function(x) if not G.booting then engine.m1_fine2(x) end end}
    params:add{type = "control", id = "m1_pwm2", name = "Osc 2 PWM", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5), action = function(x) if not G.booting then engine.m1_pwm2(x) end end}
    params:add{type = "control", id = "m1_morph2", name = "Osc 2 Morph", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.001, 0.0), action = function(x) if not G.booting then engine.m1_morph2(x) end end}
    params:add{type = "option", id = "m1_range2", name = "Osc 2 Range", options = {"HI", "LO"}, default = 1, action = function(x) if not G.booting then engine.m1_range2(x - 1) end end}
    params:add{type = "option", id = "m1_pv2_mode", name = "Osc 2 PV Dest", options = {"PWM", "VOCT"}, default = 1, action = function(x) if not G.booting then engine.m1_pv2_mode(x - 1) end end}
    params:add{type = "option", id = "m1_fm2_mode", name = "Osc 2 FM Dest", options = {"LIN", "EXP", "PWM"}, default = 2, action = function(x) if not G.booting then engine.m1_fm2_mode(x - 1) end end}
    params:add{type = "option", id = "m1_out4_wave", name = "Osc 2 Multi Wave", options = {"SINE", "TRI", "SAW", "SQR", "PULSE"}, default = 1, action = function(x) if not G.booting then engine.m1_out4_wave(x - 1) end end}
    add_node_params(1, 8)

    params:add_group("MOD 2: STOCHASTIC CORE", 28)
    params:add{type = "option", id = "m2_cv1_dest", name = "CV 1 Dest", options = {"RISE", "FALL", "CLOCK", "SLOW", "MORPH"}, default = 1, action = function(x) if not G.booting then engine.m2_cv1_dest(x - 1) end end}
    params:add{type = "option", id = "m2_cv2_dest", name = "CV 2 Dest", options = {"RISE", "FALL", "CLOCK", "SLOW", "MORPH"}, default = 2, action = function(x) if not G.booting then engine.m2_cv2_dest(x - 1) end end}
    params:add{type = "control", id = "m2_tilt1", name = "Noise 1 Tilt", controlspec = controlspec.new(-1.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m2_tilt1(x) end end}
    params:add{type = "control", id = "m2_tilt2", name = "Noise 2 Tilt", controlspec = controlspec.new(-1.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m2_tilt2(x) end end}
    params:add{type = "option", id = "m2_type1", name = "Noise 1 Type", options = {"Pink", "White", "Crackle", "DigiRain", "Lorenz", "Grit"}, default = 1, action = function(x) if not G.booting then engine.m2_type1(x - 1) end end}
    params:add{type = "option", id = "m2_type2", name = "Noise 2 Type", options = {"Pink", "White", "Crackle", "DigiRain", "Lorenz", "Grit"}, default = 2, action = function(x) if not G.booting then engine.m2_type2(x - 1) end end}
    params:add{type = "control", id = "m2_slow_rate", name = "Slow Rand Rate", controlspec = controlspec.new(0.01, 10.0, 'exp', 0.01, 0.1, "Hz"), action = function(x) if not G.booting then engine.m2_slow_rate(x) end end}
    params:add{type = "control", id = "m2_rise", name = "Slew Rise Time", controlspec = controlspec.new(0.001, 10.0, 'exp', 0.001, 0.1, "s"), action = function(x) if not G.booting then engine.m2_rise(x) end end}
    params:add{type = "control", id = "m2_fall", name = "Slew Fall Time", controlspec = controlspec.new(0.001, 10.0, 'exp', 0.001, 0.1, "s"), action = function(x) if not G.booting then engine.m2_fall(x) end end}
    params:add{type = "control", id = "m2_slew_shape", name = "Slew Shape", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m2_slew_shape(x) end end}
    params:add{type = "option", id = "m2_cycle_mode", name = "Cycle Mode", options = {"OFF", "ON"}, default = 1, action = function(x) if not G.booting then engine.m2_cycle_mode(x - 1) end end}
    params:add{type = "control", id = "m2_clk_rate", name = "Internal Clock", controlspec = controlspec.new(0.1, 50.0, 'exp', 0.01, 2.0, "Hz"), action = function(x) if not G.booting then engine.m2_clk_rate(x) end end}
    params:add{type = "option", id = "m2_clk_mode", name = "S&H Clock", options = {"INT", "EXT", "BOTH"}, default = 1, action = function(x) if not G.booting then engine.m2_clk_mode(x - 1) end end}
    params:add{type = "control", id = "m2_prob_skew", name = "Probability Skew", controlspec = controlspec.new(-1.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m2_prob_skew(x) end end}
    params:add{type = "control", id = "m2_glide", name = "S&H Glide", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m2_glide(x) end end}
    params:add{type = "control", id = "m2_clk_thresh", name = "Clock Threshold", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.001, 0.1), action = function(x) if not G.booting then engine.m2_clk_thresh(x) end end}
    add_node_params(9, 20)

    params:add_group("MOD 3: SERGE VCFQ", 20)
    params:add{type = "control", id = "m3_cutoff", name = "Cutoff", controlspec = controlspec.new(10.0, 18000.0, 'exp', 0.01, 1000.0, "Hz"), action = function(x) if not G.booting then engine.m3_cutoff(x) end end}
    params:add{type = "control", id = "m3_fine", name = "Cutoff Fine", controlspec = controlspec.new(-5.0, 5.0, 'lin', 0.001, 0.0, "Hz"), action = function(x) if not G.booting then engine.m3_fine(x) end end}
    params:add{type = "control", id = "m3_q", name = "Resonance (Q)", controlspec = controlspec.new(0.1, 500.0, 'exp', 0.1, 1.0), action = function(x) if not G.booting then engine.m3_q(x) end end}
    params:add{type = "control", id = "m3_agc_drive", name = "AGC Drive", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5), action = function(x) if not G.booting then engine.m3_agc_drive(x) end end}
    params:add{type = "control", id = "m3_fm_amt", name = "FM Amount", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 1.0), action = function(x) if not G.booting then engine.m3_fm_amt(x) end end}
    params:add{type = "control", id = "m3_notch_bal", name = "Notch Balance", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5), action = function(x) if not G.booting then engine.m3_notch_bal(x) end end}
    params:add{type = "control", id = "m3_ping_dcy", name = "Ping Decay", controlspec = controlspec.new(0.01, 2.0, 'exp', 0.01, 0.1, "s"), action = function(x) if not G.booting then engine.m3_ping_dcy(x) end end}
    params:add{type = "control", id = "m3_voct_amt", name = "V/Oct Amount", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 1.0), action = function(x) if not G.booting then engine.m3_voct_amt(x) end end}
    params:add{type = "trigger", id = "m3_ping", name = "Ping", action = function() if not G.booting then engine.m3_ping(1) end end}
    params:add{type = "option", id = "m3_range", name = "VCFQ Range", options = {"HI", "LO"}, default = 1, action = function(x) if not G.booting then engine.m3_range(x - 1) end end}
    params:add{type = "option", id = "m3_res_dest", name = "Res CV Dest", options = {"RES", "FREQ"}, default = 1, action = function(x) if not G.booting then engine.m3_res_dest(x - 1) end end}
    params:add{type = "control", id = "m3_ping_thresh", name = "Ping Threshold", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.001, 0.1), action = function(x) if not G.booting then engine.m3_ping_thresh(x) end end}
    add_node_params(21, 28)

    params:add_group("MOD 4: 1005 MODAMP", 16)
    params:add{type = "control", id = "m4_mod_gain", name = "MOD Gain", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 1.0), action = function(x) if not G.booting then engine.m4_mod_gain(x) end end}
    params:add{type = "control", id = "m4_unmod_gain", name = "UNMOD Gain", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 1.0), action = function(x) if not G.booting then engine.m4_unmod_gain(x) end end}
    params:add{type = "control", id = "m4_rm_am_mix", name = "RM/AM Morph", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m4_rm_am_mix(x) end end}
    params:add{type = "control", id = "m4_vca_base", name = "VCA Base Gain", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m4_vca_base(x) end end}
    params:add{type = "control", id = "m4_vca_resp", name = "VCA Response", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5), action = function(x) if not G.booting then engine.m4_vca_resp(x) end end}
    params:add{type = "control", id = "m4_xfade", name = "State XFade Time", controlspec = controlspec.new(0.0, 10.0, 'lin', 0.01, 0.05, "s"), action = function(x) if not G.booting then engine.m4_xfade(x) end end}
    params:add{type = "option", id = "m4_state", name = "1005 State", options = {"UNMOD", "MOD"}, default = 1, action = function(x) if not G.booting then engine.m4_state_mode(x - 1) end end}
    params:add{type = "control", id = "m4_gate_thresh", name = "Gate Threshold", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.001, 0.5), action = function(x) if not G.booting then engine.m4_gate_thresh(x) end end}
    add_node_params(29, 36)

    for i=1, 4 do
        local m = "m" .. (4+i)
        params:add_group("MOD " .. (4+i) .. ": CYBER VCA " .. i, 9)
        params:add{type = "control", id = m.."_init_gain", name = "Initial Gain", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine[m.."_init_gain"](x) end end}
        params:add{type = "control", id = m.."_env_slew", name = "Env Slew", controlspec = controlspec.new(0.01, 2.0, 'exp', 0.01, 0.1, "s"), action = function(x) if not G.booting then engine[m.."_env_slew"](x) end end}
        params:add{type = "control", id = m.."_env_gain", name = "Env Gain", controlspec = controlspec.new(0.0, 5.0, 'lin', 0.01, 1.0), action = function(x) if not G.booting then engine[m.."_env_gain"](x) end end}
        params:add{type = "option", id = m.."_vca_curve", name = "VCA Curve", options = {"LIN", "EXP"}, default = 1, action = function(x) if not G.booting then engine[m.."_vca_curve"](x - 1) end end}
        params:add{type = "option", id = m.."_env_src_sel", name = "Env Source", options = {"PRE-VCA", "POST-VCA"}, default = 1, action = function(x) if not G.booting then engine[m.."_env_src_sel"](x - 1) end end}
        add_node_params(37 + ((i-1)*4), 40 + ((i-1)*4))
    end

    params:add_group("MOD 9: SPACE-TIME CORE", 16)
    params:add{type = "option", id = "m9_mode", name = "Algorithm", options = {"TAPE", "REVERB"}, default = 1, action = function(x) if not G.booting then engine.m9_mode(x - 1); G.screen_dirty = true end end}
    params:add{type = "option", id = "m9_cv_dest", name = "CV Dest", options = {"E1", "E2", "E3", "E4"}, default = 1, action = function(x) if not G.booting then engine.m9_cv_dest(x - 1) end end}
    params:add{type = "control", id = "m9_t_drive", name = "Tape Drive", controlspec = controlspec.new(0.1, 5.0, 'lin', 0.01, 1.0), action = function(x) if not G.booting then engine.m9_t_drive(x) end end}
    params:add{type = "control", id = "m9_t_time", name = "Tape Time", controlspec = controlspec.new(0.01, 4.0, 'lin', 0.01, 0.3, "s"), action = function(x) if not G.booting then engine.m9_t_time(x) end end}
    params:add{type = "control", id = "m9_t_fb", name = "Tape Feedback", controlspec = controlspec.new(0.0, 1.2, 'lin', 0.01, 0.4), action = function(x) if not G.booting then engine.m9_t_fb(x) end end}
    params:add{type = "control", id = "m9_t_wow", name = "Tape Wow", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m9_t_wow(x) end end}
    params:add{type = "option", id = "m9_t_tone", name = "Tape Tone", options = {"18k", "8k", "4k", "1.5k"}, default = 1, action = function(x) if not G.booting then engine.m9_t_tone(x - 1) end end}
    params:add{type = "control", id = "m9_r_decay", name = "Rev Decay", controlspec = controlspec.new(0.0, 1.2, 'lin', 0.01, 0.5), action = function(x) if not G.booting then engine.m9_r_decay(x) end end}
    params:add{type = "control", id = "m9_r_bloom", name = "Rev Bloom", controlspec = controlspec.new(0.01, 1.0, 'lin', 0.01, 0.5), action = function(x) if not G.booting then engine.m9_r_bloom(x) end end}
    params:add{type = "control", id = "m9_r_damp", name = "Rev Damp", controlspec = controlspec.new(200.0, 18000.0, 'exp', 0.01, 10000.0, "Hz"), action = function(x) if not G.booting then engine.m9_r_damp(x) end end}
    params:add{type = "control", id = "m9_r_predelay", name = "Rev PreDelay", controlspec = controlspec.new(0.0, 0.2, 'lin', 0.001, 0.0, "s"), action = function(x) if not G.booting then engine.m9_r_predelay(x) end end}
    params:add{type = "option", id = "m9_r_mod", name = "Rev Mod", options = {"OFF", "LIGHT", "DEEP", "CHAOS"}, default = 1, action = function(x) if not G.booting then engine.m9_r_mod(x - 1) end end}
    add_node_params(53, 56)

    params:add_group("MOD 10: NEXUS", 22)
    params:add{type = "control", id = "m10_master_vol", name = "Master Volume", controlspec = controlspec.new(-60.0, 12.0, 'lin', 0.5, 0.0, "dB"), action = function(x) if not G.booting then engine.m10_master_vol(math.pow(10, x / 20)) end end}
    params:add{type = "control", id = "m10_cut_l", name = "Master Cutoff L", controlspec = controlspec.new(20.0, 18000.0, 'exp', 0.01, 18000.0, "Hz"), action = function(x) if not G.booting then engine.m10_cut_l(x) end end}
    params:add{type = "control", id = "m10_cut_r", name = "Master Cutoff R", controlspec = controlspec.new(20.0, 18000.0, 'exp', 0.01, 18000.0, "Hz"), action = function(x) if not G.booting then engine.m10_cut_r(x) end end}
    params:add{type = "control", id = "m10_res_l", name = "Master Res L", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m10_res_l(x) end end}
    params:add{type = "control", id = "m10_res_r", name = "Master Res R", controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0), action = function(x) if not G.booting then engine.m10_res_r(x) end end}
    params:add{type = "control", id = "m10_drive", name = "Master Drive", controlspec = controlspec.new(1.0, 5.0, 'lin', 0.01, 1.0), action = function(x) if not G.booting then engine.m10_drive(x) end end}
    params:add{type = "option", id = "m10_filt_byp", name = "Nexus Filt Bypass", options = {"ON", "BYPASS"}, default = 1, action = function(x) if not G.booting then engine.m10_filt_byp(x - 1) end end}
    params:add{type = "option", id = "m10_adc_mon", name = "Nexus ADC Mon", options = {"OFF", "ON"}, default = 1, action = function(x) if not G.booting then engine.m10_adc_mon(x - 1) end end}
    params:add{type = "option", id = "m10_cv_dest_l", name = "CV L Dest", options = {"VCA", "PAN", "VCF"}, default = 1, action = function(x) if not G.booting then engine.m10_cv_dest_l(x - 1) end end}
    params:add{type = "option", id = "m10_cv_dest_r", name = "CV R Dest", options = {"VCA", "PAN", "VCF"}, default = 1, action = function(x) if not G.booting then engine.m10_cv_dest_r(x - 1) end end}
    params:add{type = "option", id = "m10_adc_mode_l", name = "ADC L Mode", options = {"AUDIO", "ENV"}, default = 1, action = function(x) if not G.booting then engine.adc_mode_l(x - 1) end end}
    params:add{type = "option", id = "m10_adc_mode_r", name = "ADC R Mode", options = {"AUDIO", "ENV"}, default = 1, action = function(x) if not G.booting then engine.adc_mode_r(x - 1) end end}
    params:add{type = "control", id = "m10_adc_slew", name = "ADC Env Slew", controlspec = controlspec.new(0.01, 2.0, 'exp', 0.01, 0.1, "s"), action = function(x) if not G.booting then engine.adc_slew(x) end end}
    
    add_node_params(57, 64)
end

return Params
