-- lib/matrix.lua v0.516
-- CHANGELOG v0.516:
-- 1. FIX: Ajuste de bucles a 64 nodos y 32 buses TX/RX.

local Matrix = {}

local function evaluate_row_pause(dst_id, G)
    local active_count = 0
    for src_id = 1, 64 do
        if G.patch[src_id] and G.patch[src_id][dst_id] and G.patch[src_id][dst_id].active then
            active_count = active_count + 1
        end
    end
    local dst_node = G.nodes[dst_id]
    if dst_node and dst_node.type == "in" then
        if active_count == 0 then engine.pause_matrix_row(dst_node.rx_idx - 1) else engine.resume_matrix_row(dst_node.rx_idx - 1) end
    end
end

function Matrix.connect(src_id, dst_id, G)
    if G.patch[src_id] and G.patch[src_id][dst_id] then
        G.patch[src_id][dst_id].active = true; G.patch[src_id][dst_id].current_gain = 1.0
        local src_node = G.nodes[src_id]; local dst_node = G.nodes[dst_id]
        if src_node and dst_node and src_node.type == "out" and dst_node.type == "in" then
            engine.resume_matrix_row(dst_node.rx_idx - 1); engine.patch_set(dst_node.rx_idx, src_node.tx_idx, 1.0)
        end
    end
end

function Matrix.disconnect(src_id, dst_id, G)
    if G.patch[src_id] and G.patch[src_id][dst_id] then
        G.patch[src_id][dst_id].active = false; G.patch[src_id][dst_id].current_gain = 0.0
        local src_node = G.nodes[src_id]; local dst_node = G.nodes[dst_id]
        if src_node and dst_node and src_node.type == "out" and dst_node.type == "in" then
            engine.patch_set(dst_node.rx_idx, src_node.tx_idx, 0.0); evaluate_row_pause(dst_id, G)
        end
    end
end

function Matrix.init(G)
    for dst_id = 1, 64 do
        local dst_node = G.nodes[dst_id]
        if dst_node and dst_node.type == "in" then
            local has_active = false; local row_vals = {}
            for i = 1, 32 do row_vals[i] = 0.0 end
            
            for src_id = 1, 64 do
                local src_node = G.nodes[src_id]
                if src_node and src_node.type == "out" then
                    local is_active = G.patch[src_id] and G.patch[src_id][dst_id] and G.patch[src_id][dst_id].active
                    local gain = is_active and 1.0 or 0.0
                    if G.patch[src_id] and G.patch[src_id][dst_id] then G.patch[src_id][dst_id].current_gain = gain end
                    row_vals[src_node.tx_idx] = gain
                    if is_active then has_active = true end
                end
            end
            engine.patch_row_set(dst_node.rx_idx, table.concat(row_vals, ","))
            if has_active then engine.resume_matrix_row(dst_node.rx_idx - 1) else engine.pause_matrix_row(dst_node.rx_idx - 1) end
        end
    end
    
    for i = 1, 64 do
        local lvl = params:get("node_lvl_" .. i) or 0.0
        local node = G.nodes[i]
        if node then
            node.level = lvl
            if node.type == "out" then engine.set_out_level(i, lvl)
            elseif node.type == "in" then
                engine.set_in_level(i, lvl)
                if node.module == 10 and i >= 57 and i <= 60 then
                    local pan = params:get("node_pan_" .. i) or 0.0
                    node.pan = pan; engine.set_in_pan(i, pan)
                end
            end
        end
    end
end

function Matrix.update_node_params(node)
    if node.type == "out" then engine.set_out_level(node.id, node.level or 0.0)
    elseif node.type == "in" then
        engine.set_in_level(node.id, node.level or 0.0)
        if node.module == 10 and node.id >= 57 and node.id <= 60 then
            engine.set_in_pan(node.id, node.pan or 0.0); params:set("node_pan_" .. node.id, node.pan or 0.0)
        end
    end
    params:set("node_lvl_" .. node.id, node.level or 0.0)
end

return Matrix
