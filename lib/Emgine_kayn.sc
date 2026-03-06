// lib/Engine_Kayn.sc v0.516
// CHANGELOG v0.516:
// 1. ARQUITECTURA: Topología exacta de 32 TX y 32 RX. Implementado "Diagnostic Shift" para aislar el índice 0.
// 2. FIX FATAL: Corregido el colapso matemático (NaN) en los VCOs que silenciaba el motor.
// 3. DSP: Nuevo módulo Space-Time Core (Tape Echo / Bloom Reverb) con Decay infinito y Modulación.
// 4. DSP: VCOs con FM Lineal (post-exp) y FM Exponencial (pre-exp).
// 5. DSP: Extractores de Trigger (Schmidt + Trig1) en Ping In y S&H Trig In.

Engine_Kayn : CroneEngine {
    var <bus_nodes_tx, <bus_nodes_rx, <bus_levels, <bus_pans, <bus_physics;
    var <synth_matrix_amps, <synth_matrix_rows, <synth_mods, <synth_adc;
    var matrix_state, ca3080_node_buf, ca3080_master_buf;
    
    *new { arg context, doneCallback; ^super.new(context, doneCallback); }

    alloc {
        var wt_node, wt_master;
        bus_nodes_tx = Bus.audio(context.server, 32);
        bus_nodes_rx = Bus.audio(context.server, 32);
        bus_levels = Bus.control(context.server, 64);
        bus_pans = Bus.control(context.server, 64);
        bus_physics = Bus.control(context.server, 10);
        64.do { |i| bus_levels.setAt(i, 0.33) };
        
        synth_mods = Array.newClear(10);
        synth_matrix_rows = Array.newClear(32);
        matrix_state = Array.fill(32, { Array.fill(32, 0.0) });

        wt_node = Signal.fill(1024, { |i| tanh(i.linlin(0, 1023, -1.0, 1.0) * 1.3) / tanh(1.3) });
        ca3080_node_buf = Buffer.loadCollection(context.server, wt_node.asWavetable);
        wt_master = Signal.fill(1024, { |i| tanh(i.linlin(0, 1023, -1.0, 1.0) * 1.0) / tanh(1.0) });
        ca3080_master_buf = Buffer.loadCollection(context.server, wt_master.asWavetable);

        context.server.sync;

        OSCFunc({ |msg| NetAddr("127.0.0.1", 10111).sendMsg("/kayn_levels", *msg.drop(3)); }, '/kayn_levels', context.server.addr).fix;

        SynthDef(\Kayn_MatrixAmps, {
            var tx = InFeedback.ar(bus_nodes_tx.index, 32);
            var rx = InFeedback.ar(bus_nodes_rx.index, 32);
            SendReply.kr(Impulse.kr(15), '/kayn_levels', Amplitude.kr(tx ++ rx, 0.05, 0.1));
        }).add;

        SynthDef(\Kayn_MatrixRow, { arg out_bus;
            var tx = InFeedback.ar(bus_nodes_tx.index, 32);
            var gains = NamedControl.kr(\gains, 0 ! 32);
            Out.ar(out_bus, (tx * gains).sum);
        }).add;

        SynthDef(\Kayn_ADC, {
            arg out_l, out_r, lvl_l, lvl_r, shaper_buf, mode_l=0, mode_r=0, slew=0.1;
            var adc = SoundIn.ar([0, 1]);
            var env_l = (Amplitude.ar(adc[0], 0.01, slew) * 5.0).softclip; 
            var env_r = (Amplitude.ar(adc[1], 0.01, slew) * 5.0).softclip;
            var sig_l = Shaper.ar(shaper_buf, (Select.ar(K2A.ar(mode_l),[adc[0], env_l]) * In.kr(lvl_l)).clip(-1.0, 1.0));
            var sig_r = Shaper.ar(shaper_buf, (Select.ar(K2A.ar(mode_r),[adc[1], env_r]) * In.kr(lvl_r)).clip(-1.0, 1.0));
            Out.ar(out_l, sig_l); Out.ar(out_r, sig_r);
        }).add;

        SynthDef(\Kayn_1023, {
            arg in_fm1, in_fm2, in_pv1, in_pv2, out_o1, out_o2, out_i1, out_i2,
                lvl_fm1, lvl_fm2, lvl_pv1, lvl_pv2, lvl_o1, lvl_o2, lvl_i1, lvl_i2,
                tune1=100, fine1=0, pwm1=0.5, morph1=0, range1=0, pv1_mode=0, fm1_mode=0,
                tune2=101, fine2=0, pwm2=0.5, morph2=0, range2=0, pv2_mode=0, fm2_mode=0,
                out3_wave=0, out4_wave=0, phys_bus;
            var morph_lag = In.kr(phys_bus + 7);
            var fm1_in, pv1, lin_fm1, exp_fm1, morph_mod1, cv_sum1, exp_core1, freq1, ph1, tri1, sqr1, saw1, pul1, sin1, mix1, sig_out3;
            var fm2_in, pv2, lin_fm2, exp_fm2, pwm_mod2, cv_sum2, exp_core2, freq2, ph2, tri2, sqr2, saw2, pul2, sin2, mix2, sig_out4;
            
            tune1 = Lag.kr(tune1, morph_lag); fine1 = Lag.kr(fine1, morph_lag); pwm1 = Lag.kr(pwm1, morph_lag); morph1 = Lag.kr(morph1, morph_lag);
            tune2 = Lag.kr(tune2, morph_lag); fine2 = Lag.kr(fine2, morph_lag); pwm2 = Lag.kr(pwm2, morph_lag); morph2 = Lag.kr(morph2, morph_lag);
            
            // VCO 1
            fm1_in = Lag.ar(InFeedback.ar(in_fm1) * In.kr(lvl_fm1), 0.0001);
            pv1 = Lag.ar(InFeedback.ar(in_pv1) * In.kr(lvl_pv1), 0.0001);
            lin_fm1 = fm1_in * (K2A.ar(fm1_mode) < 0.5);
            exp_fm1 = fm1_in * InRange.ar(K2A.ar(fm1_mode), 0.5, 1.5);
            morph_mod1 = fm1_in * (K2A.ar(fm1_mode) > 1.5);
            
            cv_sum1 = (fine1 * 0.1) + (pv1 * pv1_mode) + exp_fm1;
            exp_core1 = K2A.ar(Select.kr(range1,[tune1, tune1*0.001])) * (2.0 ** (cv_sum1 * 10.0));
            freq1 = (exp_core1 + (lin_fm1 * 2000.0)).max(0.0);
            
            ph1 = Phasor.ar(0, freq1 * SampleDur.ir, 0, 1);
            tri1 = LeakDC.ar((ph1 * 2 - 1).abs * 2 - 1);
            sqr1 = (ph1 > 0.5) * 2 - 1;
            saw1 = (ph1 * 2 - 1) + (HPF.ar(Impulse.ar(freq1), 10000) * 0.1);
            pul1 = (tri1 > (((pwm1 + (pv1 * (1 - pv1_mode))).clip(0.0, 1.0) * 2) - 1)) * 2 - 1;
            sin1 = (LeakDC.ar(tri1 - (tri1.pow(3) / 6.0)) + (sqr1 * 0.02)) * 1.2;
            mix1 = SelectX.ar((morph1 + (morph_mod1 * 5.0)).clip(0,1) * 9.0,[sin1, tri1, saw1, sqr1, pul1, sin1.neg, tri1, saw1.neg, sqr1, pul1.neg]);
            sig_out3 = Select.ar(out3_wave,[sin1, tri1, saw1, sqr1, pul1]);
            
            // VCO 2
            fm2_in = Lag.ar(InFeedback.ar(in_fm2) * In.kr(lvl_fm2), 0.0001);
            pv2 = Lag.ar(InFeedback.ar(in_pv2) * In.kr(lvl_pv2), 0.0001);
            lin_fm2 = fm2_in * (K2A.ar(fm2_mode) < 0.5);
            exp_fm2 = fm2_in * InRange.ar(K2A.ar(fm2_mode), 0.5, 1.5);
            pwm_mod2 = fm2_in * (K2A.ar(fm2_mode) > 1.5);
            
            cv_sum2 = (fine2 * 0.1) + (pv2 * pv2_mode) + exp_fm2;
            exp_core2 = K2A.ar(Select.kr(range2,[tune2, tune2*0.001])) * (2.0 ** (cv_sum2 * 10.0));
            freq2 = (exp_core2 + (lin_fm2 * 2000.0)).max(0.0);
            
            ph2 = Phasor.ar(0, freq2 * SampleDur.ir, 0, 1);
            tri2 = LeakDC.ar((ph2 * 2 - 1).abs * 2 - 1);
            sqr2 = (ph2 > 0.5) * 2 - 1;
            saw2 = (ph2 * 2 - 1) + (HPF.ar(Impulse.ar(freq2), 10000) * 0.1);
            pul2 = (tri2 > (((pwm2 + (pv2 * (1 - pv2_mode)) + pwm_mod2).clip(0.0, 1.0) * 2) - 1)) * 2 - 1;
            sin2 = (LeakDC.ar(tri2 - (tri2.pow(3) / 6.0)) + (sqr2 * 0.02)) * 1.2;
            mix2 = SelectX.ar((morph2 + (fm2_in * fm2_mode * 5.0)).clip(0,1) * 9.0,[sin2, tri2, saw2, sqr2, pul2, sin2.neg, tri2, saw2.neg, sqr2, pul2.neg]);
            sig_out4 = Select.ar(out4_wave,[sin2, tri2, saw2, sqr2, pul2]);
            
            Out.ar(out_o1, mix1.clip(-1.0, 1.0) * In.kr(lvl_o1)); Out.ar(out_o2, mix2.clip(-1.0, 1.0) * In.kr(lvl_o2));
            Out.ar(out_i1, sig_out3.clip(-1.0, 1.0) * In.kr(lvl_i1)); Out.ar(out_i2, sig_out4.clip(-1.0, 1.0) * In.kr(lvl_i2)); 
        }).add;

        SynthDef(\Kayn_Stochastic, {
            arg in_cv1, in_cv2, in_sig, in_rate, in_samp, in_trig,
                out_n1, out_n2, out_smooth, out_cycle, out_stepped, out_coupler,
                lvl_cv1, lvl_cv2, lvl_sig, lvl_rate, lvl_samp, lvl_trig,
                lvl_n1, lvl_n2, lvl_smooth, lvl_cycle, lvl_stepped, lvl_coupler,
                cv1_dest=0, cv2_dest=1, tilt1=0, tilt2=0, type1=0, type2=1, slow_rate=0.1,
                rise=0.1, fall=0.1, slew_shape=0, cycle_mode=0,
                clk_rate=2.0, prob_skew=0, glide=0, clk_thresh=0.1, clk_mode=0, phys_bus, shaper_buf;
                
            var morph_lag = In.kr(phys_bus + 7);
            var cv1, cv2, cv_sum, mod_rise, mod_fall, mod_clk, mod_slow, mod_morph;
            var n1, n2, slow_out, clk_int, clk_ext, clk_trig, samp_in, stepped_out, coupler_out;
            var slew_in, rate_cv, actual_in, smooth_out, cycle_state, cycle_trig, next_state;
            
            tilt1 = Lag.kr(tilt1, morph_lag); tilt2 = Lag.kr(tilt2, morph_lag); slow_rate = Lag.kr(slow_rate, morph_lag);
            rise = Lag.kr(rise, morph_lag); fall = Lag.kr(fall, morph_lag); slew_shape = Lag.kr(slew_shape, morph_lag);
            clk_rate = Lag.kr(clk_rate, morph_lag); prob_skew = Lag.kr(prob_skew, morph_lag); glide = Lag.kr(glide, morph_lag);
            
            cv1 = InFeedback.ar(in_cv1) * In.kr(lvl_cv1);
            cv2 = InFeedback.ar(in_cv2) * In.kr(lvl_cv2);
            cv_sum = (cv1 * (abs(K2A.ar(cv1_dest) - (0..4)) < 0.5)) + (cv2 * (abs(K2A.ar(cv2_dest) - (0..4)) < 0.5));
            mod_rise = cv_sum[0]; mod_fall = cv_sum[1]; mod_clk = cv_sum[2]; mod_slow = cv_sum[3]; mod_morph = cv_sum[4];
            
            n1 = SelectX.ar((K2A.ar(type1) + mod_morph).clip(0, 5),[PinkNoise.ar, WhiteNoise.ar*0.5, Crackle.ar(1.9), Dust2.ar(1000)*0.9, LFNoise1.ar(500)*0.7, Latch.ar(WhiteNoise.ar, Dust.ar(50))*0.4]);
            n2 = SelectX.ar((K2A.ar(type2) + mod_morph).clip(0, 5),[PinkNoise.ar, WhiteNoise.ar*0.5, Crackle.ar(1.9), Dust2.ar(1000)*0.9, LFNoise1.ar(500)*0.7, Latch.ar(WhiteNoise.ar, Dust.ar(50))*0.4]);
            n1 = BHiShelf.ar(BLowShelf.ar(n1, 1000, 1.0, tilt1 * -12.0), 1000, 1.0, tilt1 * 12.0);
            n2 = BHiShelf.ar(BLowShelf.ar(n2, 1000, 1.0, tilt2 * -12.0), 1000, 1.0, tilt2 * 12.0);
            
            slew_in = InFeedback.ar(in_sig) * In.kr(lvl_sig);
            rate_cv = InFeedback.ar(in_rate) * In.kr(lvl_rate);
            cycle_state = LocalIn.ar(1);
            actual_in = Select.ar(K2A.ar(cycle_mode),[slew_in, cycle_state]);
            smooth_out = Slew.ar(actual_in, 1.0 / (rise * (2.0 ** ((mod_rise + rate_cv) * 10.0))).max(0.001), 1.0 / (fall * (2.0 ** ((mod_fall + rate_cv) * 10.0))).max(0.001));
            cycle_trig = Schmidt.ar(smooth_out, 0.01, 0.99);
            next_state = 1.0 - cycle_trig;
            LocalOut.ar(next_state);
            
            clk_int = Impulse.ar((clk_rate * (2.0 ** (mod_clk * 10.0))).clip(0.01, 1000));
            clk_ext = Trig1.ar(Schmidt.ar(InFeedback.ar(in_trig) * In.kr(lvl_trig), clk_thresh, clk_thresh + 0.1), 0.001);
            clk_trig = Select.ar(K2A.ar(clk_mode),[clk_int, clk_ext, clk_int + clk_ext]);
            
            samp_in = Select.ar((InFeedback.ar(in_samp) * In.kr(lvl_samp)) > 0.001,[(n1 * 5.0).softclip, InFeedback.ar(in_samp) * In.kr(lvl_samp)]);
            stepped_out = LagUD.ar(Latch.ar(samp_in, clk_trig), 0.001, 0.01 + glide);
            stepped_out = stepped_out.sign * (stepped_out.abs ** (2.0 ** prob_skew.neg));
            
            coupler_out = (stepped_out > smooth_out) * 1.0;
            
            Out.ar(out_n1, Shaper.ar(shaper_buf, n1.clip(-1.0, 1.0)) * In.kr(lvl_n1));
            Out.ar(out_n2, Shaper.ar(shaper_buf, n2.clip(-1.0, 1.0)) * In.kr(lvl_n2));
            Out.ar(out_smooth, Shaper.ar(shaper_buf, smooth_out.clip(-1.0, 1.0)) * In.kr(lvl_smooth));
            Out.ar(out_cycle, cycle_trig * In.kr(lvl_cycle));
            Out.ar(out_stepped, Shaper.ar(shaper_buf, stepped_out.clip(-1.0, 1.0)) * In.kr(lvl_stepped));
            Out.ar(out_coupler, coupler_out * In.kr(lvl_coupler));
        }).add;

        SynthDef(\Kayn_VCFQ, {
            arg in_aud, in_fm, in_ping, in_res, out_lp, out_bp, out_hp, out_notch,
                lvl_aud, lvl_fm, lvl_ping, lvl_res, lvl_lp, lvl_bp, lvl_hp, lvl_notch,
                cutoff=1000, fine=0, q=1, agc_drive=1.0, fm_amt=1.0, notch_bal=0.5, ping_dcy=0.1, voct_amt=1.0, t_ping=0, range=0, res_dest=0, ping_thresh=0.1, phys_bus, shaper_buf;
                
            var morph_lag = In.kr(phys_bus + 7);
            var aud, fm, res_in, res_cv, freq_cv2, ping_ext, ping_trig, ping_env, exciter, f_mod;
            var bp_fb, bp_amp, dyn_q, svf_res, drive_aud, lp, bp, hp, notch;
            
            cutoff = Lag.kr(cutoff, morph_lag); fine = Lag.kr(fine, morph_lag); q = Lag.kr(q, morph_lag); agc_drive = Lag.kr(agc_drive, morph_lag);
            
            aud = InFeedback.ar(in_aud) * In.kr(lvl_aud);
            fm = Lag.ar(InFeedback.ar(in_fm) * In.kr(lvl_fm), 0.0001);
            
            res_in = Lag.ar(InFeedback.ar(in_res) * In.kr(lvl_res), 0.0001);
            res_cv = res_in * (K2A.ar(res_dest) < 0.5);
            freq_cv2 = res_in * (K2A.ar(res_dest) > 0.5);
            
            ping_ext = Trig1.ar(Schmidt.ar(InFeedback.ar(in_ping) * In.kr(lvl_ping), ping_thresh, ping_thresh + 0.1), 0.001);
            ping_trig = ping_ext + K2A.ar(t_ping);
            ping_env = EnvGen.ar(Env.perc(0.001, ping_dcy), ping_trig);
            exciter = Decay.ar(K2A.ar(ping_trig), 0.01) * 5.0;
            
            f_mod = K2A.ar(cutoff) * (2.0 ** (((fm * fm_amt) + freq_cv2) * 10.0)) * (2.0 ** (ping_env * 2.0));
            f_mod = f_mod * Select.kr(range,[1.0, 0.01]);
            f_mod = (f_mod + fine).clip(0.1, 20000);
            
            bp_fb = LocalIn.ar(1);
            bp_amp = Amplitude.ar(bp_fb, 0.001, 0.05);
            dyn_q = (q * (2.0 ** (res_cv * 5.0))) / (1.0 + (bp_amp * agc_drive * 10.0));
            svf_res = dyn_q.clip(0.1, 500.0).explin(0.1, 500.0, 0.0, 2.0);
            
            drive_aud = tanh((aud + exciter) * 1.5);
            
            lp = SVF.ar(drive_aud, f_mod, svf_res, 1, 0, 0, 0, 0);
            bp = SVF.ar(drive_aud, f_mod, svf_res, 0, 1, 0, 0, 0);
            hp = SVF.ar(drive_aud, f_mod, svf_res, 0, 0, 1, 0, 0);
            LocalOut.ar(bp);
            
            notch = XFade2.ar(lp, hp, notch_bal * 2 - 1);
            
            Out.ar(out_lp, Shaper.ar(shaper_buf, lp.clip(-1.0, 1.0)) * In.kr(lvl_lp));
            Out.ar(out_bp, Shaper.ar(shaper_buf, bp.clip(-1.0, 1.0)) * In.kr(lvl_bp));
            Out.ar(out_hp, Shaper.ar(shaper_buf, hp.clip(-1.0, 1.0)) * In.kr(lvl_hp));
            Out.ar(out_notch, Shaper.ar(shaper_buf, notch.clip(-1.0, 1.0)) * In.kr(lvl_notch));
        }).add;

        SynthDef(\Kayn_1005, {
            arg in_car, in_mod, in_vca, in_gate, out_main, out_rm, out_sum, out_diff,
                lvl_car, lvl_mod, lvl_vca, lvl_gate, lvl_main, lvl_rm, lvl_sum, lvl_diff,
                mod_gain=1, unmod_gain=1, rm_am_mix=0, vca_base=0, vca_resp=0.5,
                xfade=0.05, state_mode=0, gate_thresh=0.5, phys_bus, shaper_buf;
                
            var morph_lag = In.kr(phys_bus + 7);
            var car, mod, vca_cv, gate_sig, mod_am, mod_final, rm_raw, rm_sig, gate_trig, state_flip, state_smooth, core_sig, vca_env, vca_final, final_sig;
            
            mod_gain = Lag.kr(mod_gain, morph_lag); unmod_gain = Lag.kr(unmod_gain, morph_lag); rm_am_mix = Lag.kr(rm_am_mix, morph_lag);
            vca_base = Lag.kr(vca_base, morph_lag); vca_resp = Lag.kr(vca_resp, morph_lag); xfade = Lag.kr(xfade, morph_lag);
            
            car = InFeedback.ar(in_car) * In.kr(lvl_car);
            mod = InFeedback.ar(in_mod) * In.kr(lvl_mod);
            vca_cv = Lag.ar(InFeedback.ar(in_vca) * In.kr(lvl_vca), 0.0001);
            gate_sig = InFeedback.ar(in_gate) * In.kr(lvl_gate);
            
            mod_am = (mod * 0.5) + 0.5;
            mod_final = XFade2.ar(mod, mod_am, rm_am_mix * 2 - 1);
            rm_raw = car * mod_final;
            rm_sig = (rm_raw * 3.5).softclip; 
            
            gate_trig = Schmidt.ar(gate_sig, gate_thresh, gate_thresh + 0.1);
            state_flip = ToggleFF.ar(gate_trig);
            state_smooth = Lag.ar(Select.ar(K2A.ar(state_mode),[state_flip, DC.ar(1), DC.ar(0)]), xfade);
            
            core_sig = XFade2.ar(car * unmod_gain * 1.2, rm_sig * mod_gain, state_smooth * 2 - 1);
            vca_env = (vca_base + vca_cv).clip(0, 1);
            vca_final = LinXFade2.ar(vca_env, (vca_env * 60.0 - 60.0).dbamp, vca_resp * 2 - 1);
            final_sig = (core_sig * vca_final * 1.5).clip(-1.0, 1.0);
            
            Out.ar(out_main, Shaper.ar(shaper_buf, final_sig) * In.kr(lvl_main));
            Out.ar(out_rm, Shaper.ar(shaper_buf, rm_sig.clip(-1.0, 1.0)) * In.kr(lvl_rm)); 
            Out.ar(out_sum, Shaper.ar(shaper_buf, (car + mod).clip(-1.0, 1.0)) * In.kr(lvl_sum));
            Out.ar(out_diff, Shaper.ar(shaper_buf, (car - mod).clip(-1.0, 1.0)) * In.kr(lvl_diff));
        }).add;

        SynthDef(\Kayn_CyberVCA, {
            arg in_aud, in_cv, out_aud, out_env, lvl_aud, lvl_cv, lvl_oaud, lvl_oenv,
                init_gain=0, env_slew=0.1, env_gain=1, vca_curve=0, env_src_sel=0, phys_bus, shaper_buf;
            var morph_lag = In.kr(phys_bus + 7);
            var aud_in, cv_in, vca_env, vca_final, aud_out, env_src, env_out;
            
            init_gain = Lag.kr(init_gain, morph_lag); env_slew = Lag.kr(env_slew, morph_lag); env_gain = Lag.kr(env_gain, morph_lag);
            
            aud_in = InFeedback.ar(in_aud) * In.kr(lvl_aud);
            cv_in = Lag.ar(InFeedback.ar(in_cv) * In.kr(lvl_cv), 0.0001);
            
            vca_env = (init_gain + cv_in).clip(0, 1);
            vca_final = LinXFade2.ar(vca_env, (vca_env * 60.0 - 60.0).dbamp, vca_curve * 2 - 1);
            aud_out = aud_in * vca_final;
            
            env_src = Select.ar(K2A.ar(env_src_sel),[aud_in, aud_out]);
            env_out = (Amplitude.ar(env_src, 0.001, env_slew) * env_gain * 2.0).clip(0.0, 2.0);
            
            Out.ar(out_aud, Shaper.ar(shaper_buf, aud_out.clip(-1.0, 1.0)) * In.kr(lvl_oaud));
            Out.ar(out_env, env_out * In.kr(lvl_oenv));
        }).add;

        SynthDef(\Kayn_SpaceTime, {
            arg in_aud, in_cv, out_l, out_r, lvl_aud, lvl_cv, lvl_ol, lvl_or,
                mode=0, cv_dest=0,
                t_drive=1.0, t_time=0.3, t_fb=0.4, t_wow=0.0, t_tone=0,
                r_decay=0.5, r_bloom=0.5, r_damp=10000, r_predelay=0.0, r_mod=0,
                phys_bus, shaper_buf;

            var morph_lag = In.kr(phys_bus + 7);
            var aud_in, cv_in, cv_d0, cv_d1, cv_d2, cv_d3;
            var tape_time, tape_fb, tape_wow_amt, tape_drive, tape_tone_freq, tape_local, tape_in_sig, wow_sig, tape_del, tape_sat, tape_filt, tape_out_l, tape_out_r;
            var rev_decay, rev_bloom, rev_damp, rev_predelay, rev_in, ap1, ap2, ap3, ap4, rev_local, rev_fb_sig, mod_rate, mod_depth, lfo_l, lfo_r, rev_del_l, rev_del_r, rev_filt_l, rev_filt_r, rev_out_l, rev_out_r;
            var final_l, final_r;

            aud_in = InFeedback.ar(in_aud) * In.kr(lvl_aud);
            cv_in = Lag.ar(InFeedback.ar(in_cv) * In.kr(lvl_cv), 0.0001);

            cv_d0 = cv_in * (K2A.ar(cv_dest) < 0.5);
            cv_d1 = cv_in * InRange.ar(K2A.ar(cv_dest), 0.5, 1.5);
            cv_d2 = cv_in * InRange.ar(K2A.ar(cv_dest), 1.5, 2.5);
            cv_d3 = cv_in * (K2A.ar(cv_dest) > 2.5);

            // --- TAPE ECHO ---
            tape_drive = (Lag.kr(t_drive, morph_lag) + cv_d0).clip(0.1, 5.0);
            tape_time = (Lag.kr(t_time, morph_lag) + (cv_d1 * 2.0)).clip(0.01, 4.0);
            tape_fb = (Lag.kr(t_fb, morph_lag) + cv_d2).clip(0.0, 1.2);
            tape_wow_amt = (Lag.kr(t_wow, morph_lag) + cv_d3).clip(0.0, 1.0);
            tape_tone_freq = Select.kr(t_tone,[18000, 8000, 4000, 1500]);

            tape_local = LocalIn.ar(1);
            tape_in_sig = aud_in + (tape_local * tape_fb);
            wow_sig = SinOsc.ar(LFNoise2.kr(0.5).range(0.5, 3.0)) * tape_wow_amt * 0.02;
            tape_del = DelayC.ar(tape_in_sig, 4.0, tape_time + wow_sig);
            tape_sat = (tape_del * tape_drive).tanh / tape_drive;
            tape_filt = LPF.ar(tape_sat, tape_tone_freq);
            LocalOut.ar(tape_filt);

            tape_out_l = tape_filt;
            tape_out_r = DelayC.ar(tape_filt, 0.05, 0.015);

            // --- BLOOM REVERB ---
            rev_decay = (Lag.kr(r_decay, morph_lag) + cv_d0).clip(0.0, 1.1); 
            rev_bloom = (Lag.kr(r_bloom, morph_lag) + cv_d1).clip(0.01, 2.0);
            rev_damp = (Lag.kr(r_damp, morph_lag) + (cv_d2 * 10000)).clip(200, 18000);
            rev_predelay = (Lag.kr(r_predelay, morph_lag) + cv_d3).clip(0.0, 0.2);

            rev_in = DelayN.ar(aud_in, 0.2, rev_predelay);
            
            ap1 = AllpassN.ar(rev_in, 0.1, 0.017, rev_bloom);
            ap2 = AllpassN.ar(ap1, 0.1, 0.023, rev_bloom);
            ap3 = AllpassN.ar(ap2, 0.1, 0.031, rev_bloom);
            ap4 = AllpassN.ar(ap3, 0.1, 0.047, rev_bloom);

            rev_local = LocalIn.ar(2);
            rev_fb_sig = (ap4 ! 2) + (rev_local * rev_decay);
            rev_fb_sig = HPF.ar(rev_fb_sig, 80).tanh; // DC Blocker + Softclip for infinite freeze

            mod_rate = Select.kr(r_mod,[0.0, 0.5, 1.2, 5.0]);
            mod_depth = Select.kr(r_mod,[0.0, 0.002, 0.008, 0.02]);
            lfo_l = SinOsc.ar(mod_rate) * mod_depth;
            lfo_r = SinOsc.ar(mod_rate * 1.1) * mod_depth;

            rev_del_l = DelayC.ar(rev_fb_sig[0], 0.5, 0.113 + lfo_l);
            rev_del_r = DelayC.ar(rev_fb_sig[1], 0.5, 0.149 + lfo_r);

            rev_filt_l = LPF.ar(rev_del_l, rev_damp);
            rev_filt_r = LPF.ar(rev_del_r, rev_damp);

            LocalOut.ar([rev_filt_r, rev_filt_l]); // Cross-feedback

            rev_out_l = rev_filt_l;
            rev_out_r = rev_filt_r;

            // --- MIX ---
            final_l = Select.ar(K2A.ar(mode),[tape_out_l, rev_out_l]);
            final_r = Select.ar(K2A.ar(mode),[tape_out_r, rev_out_r]);

            Out.ar(out_l, Shaper.ar(shaper_buf, final_l.clip(-1.0, 1.0)) * In.kr(lvl_ol));
            Out.ar(out_r, Shaper.ar(shaper_buf, final_r.clip(-1.0, 1.0)) * In.kr(lvl_or));
        }).add;

        SynthDef(\Kayn_Nexus, {
            arg in_ml, in_mr, in_al, in_ar, out_ml, out_mr, hw_out_l, hw_out_r,
                lvl_ml, lvl_mr, lvl_al, lvl_ar, pan_ml, pan_mr, pan_al, pan_ar, lvl_oml, lvl_omr,
                cut_l=18000, cut_r=18000, res_l=0, res_r=0, filt_byp=0,
                master_vol=1.0, drive=1.0, adc_mon=0, cv_dest_l=0, cv_dest_r=0, phys_bus, master_shaper_buf;
                
            var morph_lag = In.kr(phys_bus + 7);
            var cv_l, cv_r, dest_l, dest_r, vca_mod_l, vca_mod_r, pan_mod_l, pan_mod_r, cut_mod_l, cut_mod_r;
            var ml, mr, adc, sum, filt_l, filt_r, byp, filt_sig_l, filt_sig_r, master, final_out;
            
            cut_l = Lag.kr(cut_l, morph_lag); cut_r = Lag.kr(cut_r, morph_lag); 
            res_l = Lag.kr(res_l, morph_lag); res_r = Lag.kr(res_r, morph_lag);
            drive = Lag.kr(drive, morph_lag); master_vol = Lag.kr(master_vol, morph_lag);
            
            cv_l = InFeedback.ar(in_al) * In.kr(lvl_al);
            cv_r = InFeedback.ar(in_ar) * In.kr(lvl_ar);
            
            dest_l = K2A.ar(cv_dest_l);
            dest_r = K2A.ar(cv_dest_r);
            
            vca_mod_l = cv_l * (dest_l < 0.5);
            pan_mod_l = cv_l * InRange.ar(dest_l, 0.5, 1.5);
            cut_mod_l = cv_l * (dest_l > 1.5);
            
            vca_mod_r = cv_r * (dest_r < 0.5);
            pan_mod_r = cv_r * InRange.ar(dest_r, 0.5, 1.5);
            cut_mod_r = cv_r * (dest_r > 1.5);
            
            ml = Pan2.ar((InFeedback.ar(in_ml) * In.kr(lvl_ml)) * (1.0 + vca_mod_l).clip(0, 2), (In.kr(pan_ml) + pan_mod_l).clip(-1, 1));
            mr = Pan2.ar((InFeedback.ar(in_mr) * In.kr(lvl_mr)) * (1.0 + vca_mod_r).clip(0, 2), (In.kr(pan_mr) + pan_mod_r).clip(-1, 1));
            sum = (ml + mr) * drive;
            
            filt_l = DFM1.ar(sum[0], (cut_l * (2.0 ** (cut_mod_l * 10.0))).clip(20, 18000), res_l, 1.0, 0.0, 0.0005);
            filt_r = DFM1.ar(sum[1], (cut_r * (2.0 ** (cut_mod_r * 10.0))).clip(20, 18000), res_r, 1.0, 0.0, 0.0005);
            
            byp = K2A.ar(filt_byp);
            filt_sig_l = Select.ar(byp,[filt_l, sum[0]]);
            filt_sig_r = Select.ar(byp,[filt_r, sum[1]]);
            
            adc = SoundIn.ar([0, 1]) * K2A.ar(adc_mon);
            master =[filt_sig_l, filt_sig_r] + adc;
            final_out = Limiter.ar(Shaper.ar(master_shaper_buf, (master * master_vol).clip(-1.0, 1.0)), -0.11.dbamp);
            
            Out.ar(out_ml, final_out[0] * In.kr(lvl_oml)); Out.ar(out_mr, final_out[1] * In.kr(lvl_omr));
            Out.ar(hw_out_l, final_out[0]); Out.ar(hw_out_r, final_out[1]);
        }).add;

        context.server.sync;

        synth_matrix_amps = Synth.new(\Kayn_MatrixAmps,[], context.xg, \addToHead);
        32.do { |i| synth_matrix_rows[i] = Synth.new(\Kayn_MatrixRow,[\out_bus, bus_nodes_rx.index + i], context.xg, \addToHead); };
        
        synth_adc = Synth.new(\Kayn_ADC,[\out_l, bus_nodes_tx.index+30, \out_r, bus_nodes_tx.index+31, \lvl_l, bus_levels.index+62, \lvl_r, bus_levels.index+63, \shaper_buf, ca3080_node_buf.bufnum], context.xg, \addToHead);
        
        synth_mods[0] = Synth.new(\Kayn_1023,[\in_fm1, bus_nodes_rx.index+0, \in_fm2, bus_nodes_rx.index+1, \in_pv1, bus_nodes_rx.index+2, \in_pv2, bus_nodes_rx.index+3, \out_o1, bus_nodes_tx.index+0, \out_o2, bus_nodes_tx.index+1, \out_i1, bus_nodes_tx.index+2, \out_i2, bus_nodes_tx.index+3, \lvl_fm1, bus_levels.index+0, \lvl_fm2, bus_levels.index+1, \lvl_pv1, bus_levels.index+2, \lvl_pv2, bus_levels.index+3, \lvl_o1, bus_levels.index+4, \lvl_o2, bus_levels.index+5, \lvl_i1, bus_levels.index+6, \lvl_i2, bus_levels.index+7, \phys_bus, bus_physics.index, \shaper_buf, ca3080_node_buf.bufnum], context.xg, \addToTail);
        synth_mods[1] = Synth.new(\Kayn_Stochastic,[\in_cv1, bus_nodes_rx.index+4, \in_cv2, bus_nodes_rx.index+5, \in_sig, bus_nodes_rx.index+6, \in_rate, bus_nodes_rx.index+7, \in_samp, bus_nodes_rx.index+8, \in_trig, bus_nodes_rx.index+9, \out_n1, bus_nodes_tx.index+4, \out_n2, bus_nodes_tx.index+5, \out_smooth, bus_nodes_tx.index+6, \out_cycle, bus_nodes_tx.index+7, \out_stepped, bus_nodes_tx.index+8, \out_coupler, bus_nodes_tx.index+9, \lvl_cv1, bus_levels.index+8, \lvl_cv2, bus_levels.index+9, \lvl_sig, bus_levels.index+10, \lvl_rate, bus_levels.index+11, \lvl_samp, bus_levels.index+12, \lvl_trig, bus_levels.index+13, \lvl_n1, bus_levels.index+14, \lvl_n2, bus_levels.index+15, \lvl_smooth, bus_levels.index+16, \lvl_cycle, bus_levels.index+17, \lvl_stepped, bus_levels.index+18, \lvl_coupler, bus_levels.index+19, \phys_bus, bus_physics.index, \shaper_buf, ca3080_node_buf.bufnum], context.xg, \addToTail);
        synth_mods[2] = Synth.new(\Kayn_VCFQ,[\in_aud, bus_nodes_rx.index+10, \in_fm, bus_nodes_rx.index+11, \in_ping, bus_nodes_rx.index+12, \in_res, bus_nodes_rx.index+13, \out_lp, bus_nodes_tx.index+10, \out_bp, bus_nodes_tx.index+11, \out_hp, bus_nodes_tx.index+12, \out_notch, bus_nodes_tx.index+13, \lvl_aud, bus_levels.index+20, \lvl_fm, bus_levels.index+21, \lvl_ping, bus_levels.index+22, \lvl_res, bus_levels.index+23, \lvl_lp, bus_levels.index+24, \lvl_bp, bus_levels.index+25, \lvl_hp, bus_levels.index+26, \lvl_notch, bus_levels.index+27, \phys_bus, bus_physics.index, \shaper_buf, ca3080_node_buf.bufnum], context.xg, \addToTail);
        synth_mods[3] = Synth.new(\Kayn_1005,[\in_car, bus_nodes_rx.index+14, \in_mod, bus_nodes_rx.index+15, \in_vca, bus_nodes_rx.index+16, \in_gate, bus_nodes_rx.index+17, \out_main, bus_nodes_tx.index+14, \out_rm, bus_nodes_tx.index+15, \out_sum, bus_nodes_tx.index+16, \out_diff, bus_nodes_tx.index+17, \lvl_car, bus_levels.index+28, \lvl_mod, bus_levels.index+29, \lvl_vca, bus_levels.index+30, \lvl_gate, bus_levels.index+31, \lvl_main, bus_levels.index+32, \lvl_rm, bus_levels.index+33, \lvl_sum, bus_levels.index+34, \lvl_diff, bus_levels.index+35, \phys_bus, bus_physics.index, \shaper_buf, ca3080_node_buf.bufnum], context.xg, \addToTail);
        
        4.do { |i|
            var rx_idx = 18 + (i * 2); var tx_idx = 18 + (i * 2);
            var lvl_rx = 36 + (i * 4); var lvl_tx = 38 + (i * 4);
            synth_mods[4+i] = Synth.new(\Kayn_CyberVCA,[\in_aud, bus_nodes_rx.index+rx_idx, \in_cv, bus_nodes_rx.index+rx_idx+1, \out_aud, bus_nodes_tx.index+tx_idx, \out_env, bus_nodes_tx.index+tx_idx+1, \lvl_aud, bus_levels.index+lvl_rx, \lvl_cv, bus_levels.index+lvl_rx+1, \lvl_oaud, bus_levels.index+lvl_tx, \lvl_oenv, bus_levels.index+lvl_tx+1, \phys_bus, bus_physics.index, \shaper_buf, ca3080_node_buf.bufnum], context.xg, \addToTail);
        };
        
        synth_mods[8] = Synth.new(\Kayn_SpaceTime,[\in_aud, bus_nodes_rx.index+26, \in_cv, bus_nodes_rx.index+27, \out_l, bus_nodes_tx.index+26, \out_r, bus_nodes_tx.index+27, \lvl_aud, bus_levels.index+52, \lvl_cv, bus_levels.index+53, \lvl_ol, bus_levels.index+54, \lvl_or, bus_levels.index+55, \phys_bus, bus_physics.index, \shaper_buf, ca3080_node_buf.bufnum], context.xg, \addToTail);
        
        synth_mods[9] = Synth.new(\Kayn_Nexus,[\in_ml, bus_nodes_rx.index+28, \in_mr, bus_nodes_rx.index+29, \in_al, bus_nodes_rx.index+30, \in_ar, bus_nodes_rx.index+31, \out_ml, bus_nodes_tx.index+28, \out_mr, bus_nodes_tx.index+29, \hw_out_l, context.out_b.index, \hw_out_r, context.out_b.index+1, \lvl_ml, bus_levels.index+56, \lvl_mr, bus_levels.index+57, \lvl_al, bus_levels.index+58, \lvl_ar, bus_levels.index+59, \pan_ml, bus_pans.index+56, \pan_mr, bus_pans.index+57, \pan_al, bus_pans.index+58, \pan_ar, bus_pans.index+59, \lvl_oml, bus_levels.index+60, \lvl_omr, bus_levels.index+61, \phys_bus, bus_physics.index, \master_shaper_buf, ca3080_master_buf.bufnum], context.xg, \addToTail);

        this.addCommand("patch_set", "iif", { |msg| matrix_state[msg[1]-1][msg[2]-1] = msg[3]; synth_matrix_rows[msg[1]-1].set(\gains, matrix_state[msg[1]-1]); });
        this.addCommand("patch_row_set", "is", { |msg| matrix_state[msg[1]-1] = msg[2].asString.split($,).collect({|i| i.asFloat}); synth_matrix_rows[msg[1]-1].set(\gains, matrix_state[msg[1]-1]); });
        this.addCommand("pause_matrix_row", "i", { |msg| synth_matrix_rows[msg[1]].run(false) });
        this.addCommand("resume_matrix_row", "i", { |msg| synth_matrix_rows[msg[1]].run(true) });
        this.addCommand("set_in_level", "if", { |msg| bus_levels.setAt(msg[1] - 1, msg[2]) });
        this.addCommand("set_out_level", "if", { |msg| bus_levels.setAt(msg[1] - 1, msg[2]) });
        this.addCommand("set_in_pan", "if", { |msg| bus_pans.setAt(msg[1] - 1, msg[2]) });
        this.addCommand("set_morph_lag", "f", { |msg| bus_physics.setAt(7, msg[1]) });
        this.addCommand("set_global_physics", "sf", { |msg| var idx = switch(msg[1].asString, "thermal", 0, "droop", 1, "c_bleed", 2, "m_bleed", 3, "p_shift", 4); bus_physics.setAt(idx, msg[2]); });
        this.addCommand("adc_mode_l", "i", { |msg| synth_adc.set(\mode_l, msg[1]) });
        this.addCommand("adc_mode_r", "i", { |msg| synth_adc.set(\mode_r, msg[1]) });
        this.addCommand("adc_slew", "f", { |msg| synth_adc.set(\slew, msg[1]) });

        // M1: 1023
        this.addCommand("m1_tune1", "f", { |msg| synth_mods[0].set(\tune1, msg[1]) }); this.addCommand("m1_fine1", "f", { |msg| synth_mods[0].set(\fine1, msg[1]) }); this.addCommand("m1_pwm1", "f", { |msg| synth_mods[0].set(\pwm1, msg[1]) }); this.addCommand("m1_morph1", "f", { |msg| synth_mods[0].set(\morph1, msg[1]) }); this.addCommand("m1_range1", "i", { |msg| synth_mods[0].set(\range1, msg[1]) }); this.addCommand("m1_pv1_mode", "i", { |msg| synth_mods[0].set(\pv1_mode, msg[1]) }); this.addCommand("m1_fm1_mode", "i", { |msg| synth_mods[0].set(\fm1_mode, msg[1]) }); this.addCommand("m1_out3_wave", "i", { |msg| synth_mods[0].set(\out3_wave, msg[1]) });
        this.addCommand("m1_tune2", "f", { |msg| synth_mods[0].set(\tune2, msg[1]) }); this.addCommand("m1_fine2", "f", { |msg| synth_mods[0].set(\fine2, msg[1]) }); this.addCommand("m1_pwm2", "f", { |msg| synth_mods[0].set(\pwm2, msg[1]) }); this.addCommand("m1_morph2", "f", { |msg| synth_mods[0].set(\morph2, msg[1]) }); this.addCommand("m1_range2", "i", { |msg| synth_mods[0].set(\range2, msg[1]) }); this.addCommand("m1_pv2_mode", "i", { |msg| synth_mods[0].set(\pv2_mode, msg[1]) }); this.addCommand("m1_fm2_mode", "i", { |msg| synth_mods[0].set(\fm2_mode, msg[1]) }); this.addCommand("m1_out4_wave", "i", { |msg| synth_mods[0].set(\out4_wave, msg[1]) });

        // M2: STOCHASTIC
        this.addCommand("m2_cv1_dest", "i", { |msg| synth_mods[1].set(\cv1_dest, msg[1]) }); this.addCommand("m2_cv2_dest", "i", { |msg| synth_mods[1].set(\cv2_dest, msg[1]) }); this.addCommand("m2_tilt1", "f", { |msg| synth_mods[1].set(\tilt1, msg[1]) }); this.addCommand("m2_tilt2", "f", { |msg| synth_mods[1].set(\tilt2, msg[1]) }); this.addCommand("m2_type1", "i", { |msg| synth_mods[1].set(\type1, msg[1]) }); this.addCommand("m2_type2", "i", { |msg| synth_mods[1].set(\type2, msg[1]) }); this.addCommand("m2_slow_rate", "f", { |msg| synth_mods[1].set(\slow_rate, msg[1]) });
        this.addCommand("m2_rise", "f", { |msg| synth_mods[1].set(\rise, msg[1]) }); this.addCommand("m2_fall", "f", { |msg| synth_mods[1].set(\fall, msg[1]) }); this.addCommand("m2_slew_shape", "f", { |msg| synth_mods[1].set(\slew_shape, msg[1]) }); this.addCommand("m2_cycle_mode", "i", { |msg| synth_mods[1].set(\cycle_mode, msg[1]) });
        this.addCommand("m2_clk_rate", "f", { |msg| synth_mods[1].set(\clk_rate, msg[1]) }); this.addCommand("m2_prob_skew", "f", { |msg| synth_mods[1].set(\prob_skew, msg[1]) }); this.addCommand("m2_glide", "f", { |msg| synth_mods[1].set(\glide, msg[1]) }); this.addCommand("m2_clk_thresh", "f", { |msg| synth_mods[1].set(\clk_thresh, msg[1]) }); this.addCommand("m2_clk_mode", "i", { |msg| synth_mods[1].set(\clk_mode, msg[1]) });

        // M3: VCFQ
        this.addCommand("m3_cutoff", "f", { |msg| synth_mods[2].set(\cutoff, msg[1]) }); this.addCommand("m3_fine", "f", { |msg| synth_mods[2].set(\fine, msg[1]) }); this.addCommand("m3_q", "f", { |msg| synth_mods[2].set(\q, msg[1]) }); this.addCommand("m3_agc_drive", "f", { |msg| synth_mods[2].set(\agc_drive, msg[1]) }); this.addCommand("m3_ping", "i", { |msg| synth_mods[2].set(\t_ping, 1) }); this.addCommand("m3_range", "i", { |msg| synth_mods[2].set(\range, msg[1]) });
        this.addCommand("m3_fm_amt", "f", { |msg| synth_mods[2].set(\fm_amt, msg[1]) }); this.addCommand("m3_notch_bal", "f", { |msg| synth_mods[2].set(\notch_bal, msg[1]) }); this.addCommand("m3_ping_dcy", "f", { |msg| synth_mods[2].set(\ping_dcy, msg[1]) }); this.addCommand("m3_voct_amt", "f", { |msg| synth_mods[2].set(\voct_amt, msg[1]) }); this.addCommand("m3_res_dest", "i", { |msg| synth_mods[2].set(\res_dest, msg[1]) }); this.addCommand("m3_ping_thresh", "f", { |msg| synth_mods[2].set(\ping_thresh, msg[1]) });

        // M4: 1005
        this.addCommand("m4_mod_gain", "f", { |msg| synth_mods[3].set(\mod_gain, msg[1]) }); this.addCommand("m4_unmod_gain", "f", { |msg| synth_mods[3].set(\unmod_gain, msg[1]) }); this.addCommand("m4_rm_am_mix", "f", { |msg| synth_mods[3].set(\rm_am_mix, msg[1]) }); this.addCommand("m4_xfade", "f", { |msg| synth_mods[3].set(\xfade, msg[1]) }); this.addCommand("m4_state_mode", "i", { |msg| synth_mods[3].set(\state_mode, msg[1]) });
        this.addCommand("m4_vca_base", "f", { |msg| synth_mods[3].set(\vca_base, msg[1]) }); this.addCommand("m4_vca_resp", "f", { |msg| synth_mods[3].set(\vca_resp, msg[1]) }); this.addCommand("m4_gate_thresh", "f", { |msg| synth_mods[3].set(\gate_thresh, msg[1]) });

        // M5-8: VCAs
        4.do { |i|
            var m = "m" ++ (5+i);
            this.addCommand(m ++ "_init_gain", "f", { |msg| synth_mods[4+i].set(\init_gain, msg[1]) });
            this.addCommand(m ++ "_env_slew", "f", { |msg| synth_mods[4+i].set(\env_slew, msg[1]) });
            this.addCommand(m ++ "_env_gain", "f", { |msg| synth_mods[4+i].set(\env_gain, msg[1]) });
            this.addCommand(m ++ "_vca_curve", "i", { |msg| synth_mods[4+i].set(\vca_curve, msg[1]) });
            this.addCommand(m ++ "_env_src_sel", "i", { |msg| synth_mods[4+i].set(\env_src_sel, msg[1]) });
        };

        // M9: SPACE-TIME CORE
        this.addCommand("m9_mode", "i", { |msg| synth_mods[8].set(\mode, msg[1]) });
        this.addCommand("m9_cv_dest", "i", { |msg| synth_mods[8].set(\cv_dest, msg[1]) });
        this.addCommand("m9_t_drive", "f", { |msg| synth_mods[8].set(\t_drive, msg[1]) });
        this.addCommand("m9_t_time", "f", { |msg| synth_mods[8].set(\t_time, msg[1]) });
        this.addCommand("m9_t_fb", "f", { |msg| synth_mods[8].set(\t_fb, msg[1]) });
        this.addCommand("m9_t_wow", "f", { |msg| synth_mods[8].set(\t_wow, msg[1]) });
        this.addCommand("m9_t_tone", "i", { |msg| synth_mods[8].set(\t_tone, msg[1]) });
        this.addCommand("m9_r_decay", "f", { |msg| synth_mods[8].set(\r_decay, msg[1]) });
        this.addCommand("m9_r_bloom", "f", { |msg| synth_mods[8].set(\r_bloom, msg[1]) });
        this.addCommand("m9_r_damp", "f", { |msg| synth_mods[8].set(\r_damp, msg[1]) });
        this.addCommand("m9_r_predelay", "f", { |msg| synth_mods[8].set(\r_predelay, msg[1]) });
        this.addCommand("m9_r_mod", "i", { |msg| synth_mods[8].set(\r_mod, msg[1]) });

        // M10: NEXUS
        this.addCommand("m10_cut_l", "f", { |msg| synth_mods[9].set(\cut_l, msg[1]) }); this.addCommand("m10_cut_r", "f", { |msg| synth_mods[9].set(\cut_r, msg[1]) }); this.addCommand("m10_res_l", "f", { |msg| synth_mods[9].set(\res_l, msg[1]) }); this.addCommand("m10_res_r", "f", { |msg| synth_mods[9].set(\res_r, msg[1]) }); this.addCommand("m10_drive", "f", { |msg| synth_mods[9].set(\drive, msg[1]) }); this.addCommand("m10_filt_byp", "i", { |msg| synth_mods[9].set(\filt_byp, msg[1]) }); this.addCommand("m10_adc_mon", "i", { |msg| synth_mods[9].set(\adc_mon, msg[1]) }); this.addCommand("m10_master_vol", "f", { |msg| synth_mods[9].set(\master_vol, msg[1]) }); this.addCommand("m10_cv_dest_l", "i", { |msg| synth_mods[9].set(\cv_dest_l, msg[1]) }); this.addCommand("m10_cv_dest_r", "i", { |msg| synth_mods[9].set(\cv_dest_r, msg[1]) });
    }

    free {
        synth_matrix_amps.free; synth_matrix_rows.do({ |s| if(s.notNil, { s.free }) }); synth_mods.do({ |s| if(s.notNil, { s.free }) }); synth_adc.free;
        ca3080_node_buf.free; ca3080_master_buf.free; bus_nodes_tx.free; bus_nodes_rx.free; bus_levels.free; bus_pans.free; bus_physics.free;
    }
}
