-- kayn.lua v0.510
-- CHANGELOG v0.510:
-- 1. OPTIMIZACIÓN: Mapeo cruzado de niveles OSC (TX/RX) a IDs de Lua.

engine.name = 'Kayn'

print("========================================")
print("KAYN DEBUG: INICIANDO CARGA DE MÓDULOS")
print("========================================")

local G = include('lib/globals')
local GridUI = include('lib/grid_ui')
local ScreenUI = include('lib/screen_ui')
local Matrix = include('lib/matrix')
local Params = include('lib/params_setup')
local Storage = include('lib/storage')
local Sixteen = include('lib/16n')

g = grid.connect()

local grid_metro
local screen_metro

osc.event = function(path, args, from)
    if not G or G.booting then return end
    if path == '/kayn_levels' then
        if not G.node_levels then G.node_levels = {} end
        for i = 1, 66 do
            local node = G.nodes[i]
            if node then
                if node.type == "out" then
                    G.node_levels[i] = args[2 + node.tx_idx] or 0
                elseif node.type == "in" then
                    G.node_levels[i] = args[2 + 34 + node.rx_idx] or 0
                end
            end
        end
        G.screen_dirty = true
    end
end

function init()
    G.booting = true
    
    G.init_nodes()
    Params.init(G)
    
    params.action_write = function(filename, name, number) Storage.save(G, number) end
    params.action_read = function(filename, silent, number) Storage.load(G, number) end
    
    params:default()
    
    Matrix.init(G)
    GridUI.init(G)
    
    grid_metro = metro.init()
    grid_metro.time = 1/30
    grid_metro.event = function() GridUI.redraw(G, g) end
    grid_metro:start()
    
    screen_metro = metro.init()
    screen_metro.time = 1/15
    screen_metro.event = function() 
        if G.screen_dirty then redraw(); G.screen_dirty = false end
    end
    screen_metro:start()
    
    Sixteen.init(function(msg)
        if not G or G.booting then return end
        if G.morph_percent and G.morph_percent >= 0 and G.morph_percent < 100 then return end

        local slider_id = Sixteen.cc_2_slider_id(msg.cc)
        if not slider_id then return end

        local raw_val = msg.val
        local val = raw_val / 127 

        local now = util.time()
        if now - (G.fader_last_move[slider_id] or 0) > 0.2 then G.fader_move_start[slider_id] = now end
        G.fader_last_move[slider_id] = now
        local wake_ui = (now - G.fader_move_start[slider_id]) >= 0.05

        if G.learn_mode then
            if G.last_touched_param then
                G.fader_map[slider_id] = G.last_touched_param
                local p_name = G.last_touched_param
                local p = params.lookup[G.last_touched_param]
                if p then p_name = params.params[p].name end
                
                if wake_ui then
                    G.ui_text_state.text = "MAPPED: F" .. slider_id .. " -> " .. string.sub(p_name, 1, 10)
                    G.ui_text_state.level = 15
                    G.ui_text_state.timer = util.time() + 1.5
                    G.ui_text_state.is_fader = true
                    G.screen_dirty = true
                end
                G.fader_latched[slider_id] = true
            end
        end

        local param_id = G.fader_map[slider_id]
        if param_id and params.lookup[param_id] then
            if G.shift_held then
                if G.fine_link[param_id] then
                    param_id = G.fine_link[param_id]
                else
                    local raw_delta = raw_val - (G.fader_last_raw[slider_id] or raw_val)
                    if raw_delta ~= 0 then
                        local dir = raw_delta > 0 and 1 or -1
                        params:delta(param_id, dir)
                        if wake_ui and not G.learn_mode then
                            local p_name = params.params[params.lookup[param_id]].name
                            G.ui_text_state.text = "[F" .. slider_id .. "] " .. string.sub(p_name, 1, 10) .. " ~ " .. params:string(param_id)
                            G.ui_text_state.level = 15
                            G.ui_text_state.timer = util.time() + 1.0
                            G.ui_text_state.is_fader = true
                            G.screen_dirty = true
                        end
                    end
                    G.fader_last_raw[slider_id] = raw_val
                    return 
                end
            end

            if G.fader_last_param[slider_id] ~= param_id then G.fader_latched[slider_id] = false end
            G.fader_last_param[slider_id] = param_id

            local current_val = params:get_raw(param_id)
            local p_name = params.params[params.lookup[param_id]].name
            local short_name = string.sub(p_name, 1, 10)

            if not G.fader_latched[slider_id] then
                if math.abs(val - current_val) < 0.05 then
                    G.fader_latched[slider_id] = true
                else
                    if wake_ui then
                        if val < current_val then G.ui_text_state.text = "[F" .. slider_id .. "] " .. short_name .. " >>>"
                        else G.ui_text_state.text = "<<< " .. short_name .. "[F" .. slider_id .. "]" end
                        G.ui_text_state.level = 15
                        G.ui_text_state.timer = util.time() + 1.0
                        G.ui_text_state.is_fader = true
                        G.screen_dirty = true
                    end
                    G.fader_last_raw[slider_id] = raw_val
                    return
                end
            end

            if G.fader_latched[slider_id] then
                params:set_raw(param_id, val)
                if wake_ui and not G.learn_mode then
                    G.ui_text_state.text = "[F" .. slider_id .. "] " .. short_name .. ": " .. params:string(param_id)
                    G.ui_text_state.level = 15
                    G.ui_text_state.timer = util.time() + 1.0
                    G.ui_text_state.is_fader = true
                    G.screen_dirty = true
                end
            end
        end
        G.fader_last_raw[slider_id] = raw_val
    end)
    
    params:bang()
    pcall(function() engine.set_morph_lag(0.05) end)
    G.booting = false
    print("KAYN DEBUG: BOOT COMPLETADO")
end

function enc(n, d) ScreenUI.enc(G, n, d); G.screen_dirty = true end
function key(n, z) ScreenUI.key(G, n, z); G.screen_dirty = true end
g.key = function(x, y, z) GridUI.key(G, g, x, y, z) end
function redraw() screen.clear(); ScreenUI.draw(G); screen.update() end
function cleanup() if grid_metro then grid_metro:stop() end; if screen_metro then screen_metro:stop() end end
