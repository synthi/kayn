-- lib/matrix.lua v0.508
-- CHANGELOG v0.508:
-- 1. FIX: Inyección de fallbacks (or 0.0) en params:get para evitar nils durante el boot.

local Matrix = {}

local function evaluate_row_pause(dst_id, G)
    local active_count = 0
    for src_id = 1, 66 do
        if G.patch[src_id] and G.patch[src_id][dst_id] and G.patch[src_id][dst_id].active then
            active_count = active_count + 1
        end
    end
    if active_count == 0 then engine.pause_matrix_row(dst_id - 1) else engine.resume_matrix_row(dst_id - 1) end
end

function Matrix.connect(src_id, dst_id, G)
    if G.patch[src_id] and G.patch[src_id][dst_id] then
        G.patch[src_id][dst_id].active = true; G.patch[src_id][dst_id].current_gain = 1.0
        engine.resume_matrix_row(dst_id - 1); engine.patch_set(dst_id, src_id, 1.0)
    end
end

function Matrix.disconnect(src_id, dst_id, G)
    if G.patch[src_id] and G.patch[src_id][dst_id] then
        G.patch[src_id][dst_id].active = false; G.patch[src_id][dst_id].current_gain = 0.0
        engine.patch_set(dst_id, src_id, 0.0); evaluate_row_pause(dst_id, G)
    end
end

function Matrix.init(G)
    for dst_id = 1, 66 do
        local has_active = false; local row_vals = {}
        for src_id = 1, 66 do
            local is_active = G.patch[src_id] and G.patch[src_id][dst_id] and G.patch[src_id][dst_id].active
            if G.patch[src_id] and G.patch[src_id][dst_id] then G.patch[src_id][dst_id].current_gain = is_active and 1.0 or 0.0 end
            row_vals[src_id] = is_active and 1.0 or 0.0
            if is_active then has_active = true end
        end
        engine.patch_row_set(dst_id, table.concat(row_vals, ","))
        if has_active then engine.resume_matrix_row(dst_id - 1) else engine.pause_matrix_row(dst_id - 1) end
    end
    
    for i = 1, 66 do
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
