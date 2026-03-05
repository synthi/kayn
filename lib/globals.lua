-- lib/globals.lua v0.507
-- CHANGELOG v0.507:
-- 1. FIX FATAL: Expansión de la matriz a 66x66 para acomodar todos los nodos de Kayn sin desbordamiento.

local G = {}

G.screen_dirty = true
G.node_levels = {}
for i = 1, 66 do G.node_levels[i] = 0 end

G.focus = { state = "idle", module_id = nil, page = nil, node_x = nil, node_y = nil, hold_time = 0 }
G.shift_held = false
G.active_snap = nil
G.snapshots = {}
for i = 1, 6 do G.snapshots[i] = { has_data = false, patch = nil, params = nil } end

G.fader_map = {}
G.fader_latched = {}
G.fader_last_move = {}
G.fader_move_start = {}
G.fader_last_raw = {} 
G.fader_last_param = {} 
for i = 1, 16 do 
    G.fader_latched[i] = false; G.fader_last_move[i] = 0; G.fader_move_start[i] = 0
    G.fader_last_raw[i] = 0; G.fader_last_param[i] = nil
end
G.learn_mode = false
G.last_touched_param = nil
G.ui_text_state = { text = "KAYN CYBERNETICS", level = 4, timer = 0, is_fader = false }

G.fine_link = {["m1_tune1"] = "m1_fine1", ["m1_tune2"] = "m1_fine2",["m3_cutoff"] = "m3_fine"
}

G.patch = {}
G.nodes = {}
G.grid_map = {}

G.module_by_col = {1,1, 2,2,2, 3,3, 4,4, 5, 6, 7, 8, 9, 10,10}
G.module_names = {"1023 DUAL VCO", "STOCHASTIC CORE", "SERGE VCFQ", "1005 MODAMP", "CYBER VCA 1", "CYBER VCA 2", "CYBER VCA 3", "CYBER VCA 4", "CYBER VCA 5", "NEXUS"}

function G.init_nodes()
    for x = 1, 16 do G.grid_map[x] = {}; for y = 1, 8 do G.grid_map[x][y] = nil end end
    local node_id_counter = 1

    local function add_node(x, y, type, module_idx, name)
        local id = node_id_counter
        local node = { id = id, x = x, y = y, type = type, module = module_idx, name = name, level = 0.33, pan = 0.0 }
        G.nodes[id] = node; G.grid_map[x][y] = node; node_id_counter = node_id_counter + 1
        return id
    end

    -- MOD 1: 1023 (IDs 1-8)
    add_node(1, 1, "in", 1, "FM/Morph 1 In"); add_node(2, 1, "in", 1, "FM/Morph 2 In")
    add_node(1, 2, "in", 1, "PWM/VOct 1 In"); add_node(2, 2, "in", 1, "PWM/VOct 2 In")
    add_node(1, 6, "out", 1, "Osc 1 Out"); add_node(2, 6, "out", 1, "Osc 2 Out")
    add_node(1, 7, "out", 1, "Multi 1 Out"); add_node(2, 7, "out", 1, "Multi 2 Out")

    -- MOD 2: STOCHASTIC (IDs 9-20)
    add_node(3, 1, "in", 2, "CV 1 In"); add_node(3, 2, "in", 2, "CV 2 In")
    add_node(4, 1, "in", 2, "Slew Sig In"); add_node(4, 2, "in", 2, "Slew Rate CV")
    add_node(5, 1, "in", 2, "S&H Sig In"); add_node(5, 2, "in", 2, "S&H Trig In")
    add_node(3, 6, "out", 2, "Noise 1 Out"); add_node(3, 7, "out", 2, "Noise 2 Out")
    add_node(4, 6, "out", 2, "Smooth Out"); add_node(4, 7, "out", 2, "Cycle Trig Out")
    add_node(5, 6, "out", 2, "Stepped Out"); add_node(5, 7, "out", 2, "Coupler Out")

    -- MOD 3: VCFQ (IDs 21-28)
    add_node(6, 1, "in", 3, "Audio In"); add_node(6, 2, "in", 3, "FM CV In")
    add_node(7, 1, "in", 3, "Ping Trig In"); add_node(7, 2, "in", 3, "Resonance CV")
    add_node(6, 6, "out", 3, "Low Pass Out"); add_node(6, 7, "out", 3, "Band Pass Out")
    add_node(7, 6, "out", 3, "High Pass Out"); add_node(7, 7, "out", 3, "Notch Out")

    -- MOD 4: 1005 (IDs 29-36)
    add_node(8, 1, "in", 4, "Carrier In"); add_node(8, 2, "in", 4, "Modulator In")
    add_node(9, 1, "in", 4, "VCA CV In"); add_node(9, 2, "in", 4, "State Gate In")
    add_node(8, 6, "out", 4, "Main Out"); add_node(8, 7, "out", 4, "Ring Mod Out")
    add_node(9, 6, "out", 4, "Sum Out"); add_node(9, 7, "out", 4, "Diff Out")

    -- MODS 5-9: CYBER VCAs (IDs 37-56)
    for i=0, 4 do
        local col = 10 + i; local mod_idx = 5 + i
        add_node(col, 1, "in", mod_idx, "Audio In")
        add_node(col, 2, "in", mod_idx, "CV In")
        add_node(col, 6, "out", mod_idx, "VCA Out")
        add_node(col, 7, "out", mod_idx, "Env Follower Out")
    end

    -- MOD 10: NEXUS (IDs 57-66)
    add_node(15, 1, "in", 10, "Modular In L"); add_node(16, 1, "in", 10, "Modular In R")
    add_node(15, 2, "in", 10, "CV L In"); add_node(16, 2, "in", 10, "CV R In")
    add_node(15, 6, "out", 10, "Master Out L"); add_node(16, 6, "out", 10, "Master Out R")
    add_node(15, 7, "out", 10, "Tape Send L"); add_node(16, 7, "out", 10, "Tape Send R")
    add_node(15, 8, "out", 10, "ADC Out L"); add_node(16, 8, "out", 10, "ADC Out R")

    for src = 1, 66 do G.patch[src] = {}; for dst = 1, 66 do G.patch[src][dst] = { active = false, level = 1.0, pan = 0.0 } end end
end

return G
