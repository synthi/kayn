-- lib/screen_ui.lua v0.531
-- CHANGELOG v0.531:
-- 1. FIX: Eliminada la lógica dinámica del Módulo 9 (ahora es solo Reverb).
-- 2. FIX: Traducción de strings para los destinos CV en el menú Hold.

local ScreenUI = {}
ScreenUI.ping_flash = {[3] = 0}

local MenuDef = {
    [1] = { A = { title = "1023 - OSC 1", e1 = {id="m1_pwm1", name="PWM"}, e2 = {id="m1_tune1", name="TUNE"}, e3 = {id="m1_morph1", name="MORPH"}, e4 = {id="m1_fine1", name="FINE"}, k2 = {id="m1_range1", name=""}, k3 = {id="m1_out3_wave", name="WAVE"} }, B = { title = "1023 - OSC 2", e1 = {id="m1_pwm2", name="PWM"}, e2 = {id="m1_tune2", name="TUNE"}, e3 = {id="m1_morph2", name="MORPH"}, e4 = {id="m1_fine2", name="FINE"}, k2 = {id="m1_range2", name=""}, k3 = {id="m1_out4_wave", name="WAVE"} } },
    [2] = { A = { title = "STOCHASTIC NOISE", e1 = {id="m2_slow_rate", name="SLOW RT"}, e2 = {id="m2_tilt1", name="TILT 1"}, e3 = {id="m2_tilt2", name="TILT 2"}, k2 = {id="m2_type1", name="N1"}, k3 = {id="m2_type2", name="N2"} }, B = { title = "STOCHASTIC SLEW", e1 = {id="m2_slew_shape", name="SHAPE"}, e2 = {id="m2_rise", name="RISE"}, e3 = {id="m2_fall", name="FALL"}, k2 = {id="m2_cycle_mode", name="CYCLE"} }, C = { title = "STOCHASTIC S&H", e1 = {id="m2_glide", name="GLIDE"}, e2 = {id="m2_clk_rate", name="CLOCK"}, e3 = {id="m2_prob_skew", name="SKEW"}, k2 = {id="m2_clk_mode", name="SRC"} } },
    [3] = { A = { title = "SERGE VCFQ CORE", e1 = {id="m3_agc_drive", name="AGC DRV"}, e2 = {id="m3_cutoff", name="FREQ"}, e3 = {id="m3_q", name="RES"}, e4 = {id="m3_fine", name="FINE"}, k2 = {id="m3_range", name="RNG"}, k3 = {id="m3_ping", name="PING"} }, B = { title = "SERGE VCFQ MODS", e1 = {id="m3_ping_dcy", name="PING DCY"}, e2 = {id="m3_fm_amt", name="FM AMT"}, e3 = {id="m3_notch_bal", name="NOTCH"}, e4 = {id="m3_voct_amt", name="V/OCT"} } },
    [4] = { A = { title = "1005 RING MOD", e1 = {id="m4_rm_am_mix", name="RM/AM"}, e2 = {id="m4_mod_gain", name="MOD"}, e3 = {id="m4_unmod_gain", name="UNMOD"}, e4 = {id="m4_xfade", name="XFADE"}, k2 = {id="m4_state", name="ST"} }, B = { title = "1005 VCA", e1 = {id="m4_gate_thresh", name="THRESH"}, e2 = {id="m4_vca_base", name="BASE"}, e3 = {id="m4_vca_resp", name="RESP"}, k2 = {id="m4_state", name="ST"} } },
    [5] = { A = { title = "CYBER VCA 1", e1 = {id="m5_env_gain", name="ENV GAIN"}, e2 = {id="m5_init_gain", name="BIAS"}, e3 = {id="m5_env_slew", name="ENV DCY"}, k2 = {id="m5_vca_curve", name="CRV"} } },
    [6] = { A = { title = "CYBER VCA 2", e1 = {id="m6_env_gain", name="ENV GAIN"}, e2 = {id="m6_init_gain", name="BIAS"}, e3 = {id="m6_env_slew", name="ENV DCY"}, k2 = {id="m6_vca_curve", name="CRV"} } },
    [7] = { A = { title = "CYBER VCA 3", e1 = {id="m7_env_gain", name="ENV GAIN"}, e2 = {id="m7_init_gain", name="BIAS"}, e3 = {id="m7_env_slew", name="ENV DCY"}, k2 = {id="m7_vca_curve", name="CRV"} } },
    [8] = { A = { title = "CYBER VCA 4", e1 = {id="m8_env_gain", name="ENV GAIN"}, e2 = {id="m8_init_gain", name="BIAS"}, e3 = {id="m8_env_slew", name="ENV DCY"}, k2 = {id="m8_vca_curve", name="CRV"} } },[9] = { A = { title = "BLOOM REVERB", e1 = {id="m9_r_decay", name="DECAY"}, e2 = {id="m9_r_bloom", name="BLOOM"}, e3 = {id="m9_r_damp", name="DAMP"}, e4 = {id="m9_r_predelay", name="PREDLY"}, k3 = {id="m9_r_mod", name="MOD"} } },
    [10] = { A = { title = "NEXUS FILTERS", e1 = {id="m10_cut_l", name="CUT L"}, e2 = {id="m10_res_l", name="RES L"}, e3 = {id="m10_cut_r", name="CUT R"}, e4 = {id="m10_res_r", name="RES R"}, k2 = {id="m10_filt_byp", name="FILT"} }, B = { title = "NEXUS MASTER", e1 = {id="m10_master_vol", name="VOL"}, e2 = {id="m10_drive", name="DRIVE"}, e3 = {id="thermal_drift", name="AGE"}, e4 = {id="m10_adc_slew", name="ADC SLW"}, k2 = {id="m10_adc_mon", name="ADC"} }, C = { title = "NEXUS TAPE", e1 = {id="m10_tape_time", name="TIME"}, e2 = {id="m10_tape_fb", name="FDBK"}, e3 = {id="m10_tape_tone", name="TONE"}, e4 = {id="m10_tape_wow", name="WOW"}, k2 = {id="m10_tape_mute", name="MUTE"} } }
}

local function register_touch(G, param_id)
    G.last_touched_param = param_id
    if G.learn_mode then
        local p_name = param_id; local p = params.lookup[param_id]; if p then p_name = params.params[p].name end
        G.ui_text_state.text = "LEARN: " .. string.sub(p_name, 1, 12)
        G.ui_text_state.level = 15; G.ui_text_state.timer = util.time() + 2.0; G.ui_text_state.is_fader = true; G.screen_dirty = true
    end
end

local function grid_to_screen(x, y) local visual_y = y; if y >= 6 then visual_y = y - 1 end; return (x - 1) * 8 + 4, (visual_y - 1) * 8 + 4 end
local function is_lo_mode(param_id) if string.find(param_id, "m1_tune1") then return params:get("m1_range1") == 2 end; if string.find(param_id, "m1_tune2") then return params:get("m1_range2") == 2 end; return false end
local function fmt_hz(v, is_lo) if not v then return "0.0Hz" end; if is_lo then return string.format("%.3fHz", v / 1000) end; return string.format("%.1fHz", v) end
local function clean_str(str) return str and string.gsub(str, " ", "") or "" end

function ScreenUI.draw_idle(G)
    for x = 1, 16 do
        for y = 1, 8 do
            if y == 1 or y == 2 or y == 6 or y == 7 or (y == 8 and x >= 15) then
                local px, py = grid_to_screen(x, y)
                local b = (G.grid_cache and G.grid_cache[x] and G.grid_cache[x][y]) or 0
                if b == -1 then b = 0 end
                screen.level(b); screen.rect(px - 2, py - 2, 4, 4); screen.fill()
            end
        end
    end
    screen.level(1); screen.move(0, 20); screen.line(128, 20); screen.stroke(); screen.move(0, 28); screen.line(128, 28); screen.stroke()
    
    local show_morph = false
    if G.morph_percent and G.morph_percent >= 0 then if G.morph_percent < 100 then show_morph = true elseif G.morph_text_timer and util.time() < G.morph_text_timer then show_morph = true else G.morph_percent = -1 end end

    if show_morph then
        screen.level(15); screen.move(64, 26); screen.text_center(string.format("MORPHING: %d%%", math.floor(G.morph_percent)))
    else
        local now = util.time()
        if G.ui_text_state.is_fader then
            if G.learn_mode then G.ui_text_state.level = 15
            elseif now > G.ui_text_state.timer then
                local fade_progress = now - G.ui_text_state.timer
                if fade_progress >= 1.0 then G.ui_text_state.is_fader = false; G.ui_text_state.text = "KAYN CYBERNETICS"; G.ui_text_state.level = 4
                else G.ui_text_state.level = math.floor(15 * (1.0 - fade_progress)); G.screen_dirty = true end
            else G.ui_text_state.level = 15 end
        else G.ui_text_state.level = 4; G.ui_text_state.text = "KAYN CYBERNETICS" end
        screen.level(math.max(0, G.ui_text_state.level)); screen.move(64, 26); screen.text_center(G.ui_text_state.text)
    end

    screen.aa(1); screen.level(10)
    if G.patch and G.nodes then
        for src_id, dests in pairs(G.patch) do
            for dst_id, data in pairs(dests) do
                if data.active then
                    local src_node = G.nodes[src_id]; local dst_node = G.nodes[dst_id]
                    if src_node and dst_node and src_node.type ~= "dummy" and dst_node.type ~= "dummy" then
                        local sx1, sy1 = grid_to_screen(src_node.x, src_node.y); local sx2, sy2 = grid_to_screen(dst_node.x, dst_node.y)
                        screen.move(sx1, sy1); local cx = (sx1 + sx2) / 2; local cy = math.max(sy1, sy2) + 25 + (math.abs(sx1 - sx2) * 0.2) 
                        screen.curve(sx1, sy1, cx, cy, sx2, sy2); screen.stroke()
                    end
                end
            end
        end
    end
    screen.aa(0)
    local vol, vcf1, vcf2 = 0.0, 18000, 18000
    pcall(function() vol = params:get("m10_master_vol") or 0.0; vcf1 = params:get("m10_cut_l") or 18000; vcf2 = params:get("m10_cut_r") or 18000 end)
    screen.level(15); screen.move(2, 62); screen.text(string.format("%.1fdB", vol)); screen.move(64, 62); screen.text_center(fmt_hz(vcf1, false)); screen.move(126, 62); screen.text_right(fmt_hz(vcf2, false))
end

function ScreenUI.draw_node_menu(G)
    if not G.focus.node_x or not G.focus.node_y then return end
    local node = G.grid_map[G.focus.node_x] and G.grid_map[G.focus.node_x][G.focus.node_y]
    if not node or node.type == "dummy" then return end
    
    local mod_name = G.module_names and G.module_names[node.module] or ("MOD " .. node.module)
    screen.level(15); screen.move(64, 10); screen.text_center(mod_name .. ": " .. node.name)
    screen.level(4); screen.move(64, 20); screen.text_center(node.type == "in" and "INPUT ATTENUVERTER" or "OUTPUT LEVEL")
    
    screen.level(15)
    local val_px = (node.level or 0) * 50
    if val_px > 0 then screen.rect(64, 27, val_px, 6) else screen.rect(64 + val_px, 27, math.abs(val_px), 6) end
    screen.fill()
    
    screen.level(15); screen.move(126, 55)
    local lvl_str = string.format("%.2f", node.level or 0); local w_lvl = screen.text_extents(lvl_str)
    screen.text_right(lvl_str); screen.level(4); screen.move(126 - w_lvl - 2, 55); screen.text_right("E3 Level: ")
    
    if node.module == 10 and node.type == "in" then
        if node.id == 57 or node.id == 58 then
            screen.level(4); screen.move(10, 55); screen.text("E2 Pan: "); screen.level(15); screen.text(string.format("%.2f", node.pan or 0))
        elseif node.id == 59 or node.id == 60 then
            local p_id = node.id == 59 and "m10_cv_dest_l" or "m10_cv_dest_r"
            local val = params:get(p_id)
            local dest_names = {"VCA", "PAN", "VCF", "TIME", "FDBK"}
            local str_val = dest_names[val] or "---"
            screen.level(15); screen.move(126, 45); screen.text_right(str_val); local w = screen.text_extents(str_val)
            screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 DEST: ")
        end
    elseif node.module == 2 and node.type == "in" and (node.id == 9 or node.id == 10) then
        local p_id = node.id == 9 and "m2_cv1_dest" or "m2_cv2_dest"
        local val = ""; pcall(function() val = params:string(p_id) end)
        screen.level(15); screen.move(126, 45); screen.text_right(val); local w = screen.text_extents(val)
        screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 DEST: ")
    elseif node.module == 2 and node.type == "in" and node.id == 14 then
        local thresh_val = 0; pcall(function() thresh_val = params:get("m2_clk_thresh") end)
        screen.level(4); screen.move(10, 55); screen.text("E2 Thresh: "); screen.level(15); screen.text(string.format("%.2f", thresh_val))
    elseif node.module == 3 and node.type == "in" and node.id == 23 then
        local thresh_val = 0; pcall(function() thresh_val = params:get("m3_ping_thresh") end)
        screen.level(4); screen.move(10, 55); screen.text("E2 Thresh: "); screen.level(15); screen.text(string.format("%.2f", thresh_val))
    elseif node.module == 3 and node.type == "in" and node.id == 24 then
        local p_id = "m3_res_dest"
        local val = ""; pcall(function() val = params:string(p_id) end)
        screen.level(15); screen.move(126, 45); screen.text_right(val); local w = screen.text_extents(val)
        screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 DEST: ")
    elseif node.module == 1 and node.type == "in" and node.id >= 1 and node.id <= 4 then
        local p_id = (node.id == 1) and "m1_fm1_mode" or ((node.id == 2) and "m1_fm2_mode" or ((node.id == 3) and "m1_pv1_mode" or "m1_pv2_mode"))
        local val = ""; pcall(function() val = params:string(p_id) end)
        screen.level(15); screen.move(126, 45); screen.text_right(val); local w = screen.text_extents(val)
        screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 DEST: ")
    elseif node.module == 9 and node.type == "in" and node.id == 54 then
        local p_id = "m9_cv_dest"
        local val = params:get(p_id)
        local dest_names = {"DECAY", "BLOOM", "DAMP", "PREDLY"}
        local str_val = dest_names[val] or "---"
        screen.level(15); screen.move(126, 45); screen.text_right(str_val); local w = screen.text_extents(str_val)
        screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 DEST: ")
    elseif node.module == 10 and node.type == "out" and (node.id == 65 or node.id == 66) then
        local p_id = (node.id == 65) and "m10_adc_mode_l" or "m10_adc_mode_r"
        local val = ""; pcall(function() val = params:string(p_id) end)
        screen.level(15); screen.move(126, 45); screen.text_right(val); local w = screen.text_extents(val)
        screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 MODE: ")
    elseif node.module >= 5 and node.module <= 8 and node.type == "in" and (node.id == 38 or node.id == 42 or node.id == 46 or node.id == 50) then
        local p_id = "m" .. node.module .. "_env_src_sel"
        local val = ""; pcall(function() val = params:string(p_id) end)
        screen.level(15); screen.move(126, 45); screen.text_right(val); local w = screen.text_extents(val)
        screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 SRC: ")
    end
end

local function draw_param(def_e, x, y, label, align_right)
    if not def_e then return end
    local val = nil; pcall(function() val = params:get(def_e.id) end)
    local str_val = "---"
    if val then if string.find(def_e.id, "cut") or string.find(def_e.id, "tune") then str_val = fmt_hz(val, is_lo_mode(def_e.id)) else pcall(function() str_val = clean_str(params:string(def_e.id)) end) end end
    if align_right then
        screen.level(15); screen.move(x, y); screen.text_right(str_val); local w = screen.text_extents(str_val)
        screen.level(4); screen.move(x - w - 2, y); screen.text_right(label .. " " .. def_e.name .. (def_e.name ~= "" and ": " or ""))
    else
        screen.level(4); screen.move(x, y); screen.text(label .. " " .. def_e.name .. (def_e.name ~= "" and ": " or "")); screen.level(15); screen.text(str_val)
    end
end

function ScreenUI.draw_module_menu(G)
    if not G.focus.module_id or not G.focus.page then return end
    local def = MenuDef[G.focus.module_id][G.focus.page]
    if not def then return end

    screen.level(15); screen.move(64, 10); screen.text_center(def.title)
    draw_param(def.e1, 2, 30, "E1", false); draw_param(def.e2, 2, 45, "E2", false)
    draw_param(def.e3, 2, 60, "E3", false); draw_param(def.e4, 126, 30, "E4", true)

    if def.k2 then 
        local k2_id = type(def.k2) == "table" and def.k2.id or def.k2; local k2_name = type(def.k2) == "table" and def.k2.name or "K2"
        local k2_val = ""; pcall(function() k2_val = clean_str(params:string(k2_id)) end)
        local is_ping = (k2_name == "PING"); local is_flashing = is_ping and (util.time() - (ScreenUI.ping_flash[G.focus.module_id] or 0) < 0.15)
        if is_flashing then screen.level(15); screen.move(126, 45); screen.text_right("PING!")
        else screen.level(15); screen.move(126, 45); screen.text_right(k2_val); local w = screen.text_extents(k2_val); screen.level(4); screen.move(126 - w - 2, 45); screen.text_right("K2 " .. k2_name .. (k2_name ~= "" and ": " or "")) end
    end
    if def.k3 then 
        local k3_id = type(def.k3) == "table" and def.k3.id or def.k3; local k3_name = type(def.k3) == "table" and def.k3.name or "K3"
        local k3_val = ""; pcall(function() k3_val = clean_str(params:string(k3_id)) end)
        local is_ping = (k3_name == "PING"); local is_flashing = is_ping and (util.time() - (ScreenUI.ping_flash[G.focus.module_id] or 0) < 0.15)
        if is_flashing then screen.level(15); screen.move(126, 60); screen.text_right("PING!")
        else screen.level(15); screen.move(126, 60); screen.text_right(k3_val); local w = screen.text_extents(k3_val); screen.level(4); screen.move(126 - w - 2, 60); screen.text_right("K3 " .. k3_name .. (k3_name ~= "" and ": " or "")) end
    end
end

function ScreenUI.draw(G)
    if not G or not G.grid_map or not G.nodes or not G.focus then return end
    if G.focus.state == "idle" or G.focus.state == "patching" then ScreenUI.draw_idle(G)
    elseif G.focus.state == "in" or G.focus.state == "out" then ScreenUI.draw_node_menu(G)
    elseif G.focus.state == "menu" then ScreenUI.draw_module_menu(G) end
end

local last_enc_time = 0
function ScreenUI.enc(G, n, d)
    if not G or not G.focus then return end
    local now = util.time(); local dt = now - last_enc_time; last_enc_time = now
    local accel = 1.0; if dt < 0.05 then accel = 5.0 elseif dt > 0.15 then accel = 0.1 end 

    if G.focus.state == "idle" then
        local target_param = nil
        if n == 1 then target_param = "m10_master_vol" elseif n == 2 then target_param = "m10_cut_l" elseif n == 3 then target_param = "m10_cut_r" end
        if target_param then 
            register_touch(G, target_param); 
            pcall(function() 
                local p_idx = params.lookup[target_param]
                local min_val = 20.0; local max_val = 18000.0
                if p_idx and params.params[p_idx].controlspec then
                    min_val = params.params[p_idx].controlspec.minval
                    max_val = params.params[p_idx].controlspec.maxval
                end
                if n == 1 then 
                    params:delta(target_param, d * ((accel < 1) and 0.1 or 1.0)) 
                else 
                    params:set(target_param, util.clamp(params:get(target_param) + (d * ((accel < 1) and 0.1 or ((accel > 1) and 100.0 or 10.0))), min_val, max_val)) 
                end 
            end) 
        end
    elseif G.focus.state == "in" or G.focus.state == "out" then
        if not G.focus.node_x or not G.focus.node_y then return end
        local node = G.grid_map[G.focus.node_x] and G.grid_map[G.focus.node_x][G.focus.node_y]
        if not node or node.type == "dummy" then return end
        local Matrix = include('lib/matrix') 
        if n == 3 then register_touch(G, "node_lvl_" .. node.id); node.level = util.clamp((node.level or 0) + (d * 0.01), -1.0, 1.0); if Matrix.update_node_params then Matrix.update_node_params(node) end
        elseif n == 2 then
            if node.module == 10 and node.type == "in" and (node.id == 57 or node.id == 58) then register_touch(G, "node_pan_" .. node.id); node.pan = util.clamp((node.pan or 0) + (d * 0.01), -1.0, 1.0); if Matrix.update_node_params then Matrix.update_node_params(node) end
            elseif node.module == 2 and node.type == "in" and node.id == 14 then register_touch(G, "m2_clk_thresh"); pcall(function() params:delta("m2_clk_thresh", d) end)
            elseif node.module == 3 and node.type == "in" and node.id == 23 then register_touch(G, "m3_ping_thresh"); pcall(function() params:delta("m3_ping_thresh", d) end) end
        end
    elseif G.focus.state == "menu" then
        if not G.focus.module_id or not G.focus.page then return end
        local def = MenuDef[G.focus.module_id][G.focus.page]
        if not def then return end

        local target_param = nil
        if n == 1 then target_param = def.e1 and def.e1.id elseif n == 2 then target_param = def.e2 and def.e2.id elseif n == 3 then target_param = def.e3 and def.e3.id elseif n == 4 then target_param = def.e4 and def.e4.id end 
        if target_param then
            register_touch(G, target_param)
            pcall(function()
                local p_idx = params.lookup[target_param]
                local min_val = 0; local max_val = 1
                if p_idx and params.params[p_idx].controlspec then
                    min_val = params.params[p_idx].controlspec.minval
                    max_val = params.params[p_idx].controlspec.maxval
                end
                if string.find(target_param, "tune") or string.find(target_param, "cutoff") or string.find(target_param, "damp") then 
                    params:set(target_param, util.clamp(params:get(target_param) + (d * ((accel < 1) and 0.1 or ((accel > 1) and 10.0 or 1.0))), min_val, max_val))
                elseif string.find(target_param, "fine") then 
                    params:set(target_param, util.clamp(params:get(target_param) + (d * ((accel < 1) and 0.001 or 0.01)), min_val, max_val))
                else 
                    params:delta(target_param, d * ((accel < 1) and 0.1 or 1.0)) 
                end
            end)
        end
    end
end

function ScreenUI.key(G, n, z)
    if not G or not G.focus then return end
    if z == 1 then
        if G.focus.state == "in" or G.focus.state == "out" then
            if not G.focus.node_x or not G.focus.node_y then return end
            local node = G.grid_map[G.focus.node_x] and G.grid_map[G.focus.node_x][G.focus.node_y]
            if node and n == 2 then
                local p_id = nil
                if node.id == 59 then p_id = "m10_cv_dest_l" elseif node.id == 60 then p_id = "m10_cv_dest_r"
                elseif node.id == 9 then p_id = "m2_cv1_dest" elseif node.id == 10 then p_id = "m2_cv2_dest"
                elseif node.id == 1 then p_id = "m1_fm1_mode" elseif node.id == 2 then p_id = "m1_fm2_mode"
                elseif node.id == 3 then p_id = "m1_pv1_mode" elseif node.id == 4 then p_id = "m1_pv2_mode"
                elseif node.id == 24 then p_id = "m3_res_dest"
                elseif node.id == 54 then p_id = "m9_cv_dest"
                elseif node.id == 65 then p_id = "m10_adc_mode_l" elseif node.id == 66 then p_id = "m10_adc_mode_r"
                elseif node.module >= 5 and node.module <= 8 and (node.id == 38 or node.id == 42 or node.id == 46 or node.id == 50) then p_id = "m" .. node.module .. "_env_src_sel" end
                if p_id then register_touch(G, p_id); pcall(function() local p_idx = params.lookup[p_id]; if p_idx then local p = params.params[p_idx]; if p.options then params:set(p_id, params:get(p_id) == #p.options and 1 or params:get(p_id) + 1) end end end) end
            end
        elseif G.focus.state == "menu" then
            if not G.focus.module_id or not G.focus.page then return end
            local def = MenuDef[G.focus.module_id][G.focus.page]
            if not def then return end

            local target_param = nil
            if n == 2 and def.k2 then target_param = type(def.k2) == "table" and def.k2.id or def.k2 end
            if n == 3 and def.k3 then target_param = type(def.k3) == "table" and def.k3.id or def.k3 end
            if target_param then
                register_touch(G, target_param)
                pcall(function()
                    local p_idx = params.lookup[target_param]
                    if p_idx then
                        local p = params.params[p_idx]
                        if p.t == 4 or string.find(target_param, "ping") then 
                            params:set(target_param, 1)
                            if target_param == "m3_ping" then ScreenUI.ping_flash[3] = util.time() end
                        elseif p.options then params:set(target_param, params:get(target_param) == #p.options and 1 or params:get(target_param) + 1) end
                    end
                end)
            end
        end
    end
end

return ScreenUI
