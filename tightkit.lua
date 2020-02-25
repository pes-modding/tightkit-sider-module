-- tightkit.lua

local version = "1.0"

local tk_values = {
    { nil, "Auto" },  --> do not modify TightKit attribute (do nothing)
    { 0, "Off" },     --> enforce TightKit=Off
    { 1, "On" },      --> enforce TightKit=On
}
local tk_choice = 1

local org_kits_set
local org_kits_set_gk

local function table_copy(t)
    local tcopy = {}
    for k,v in pairs(t) do
        tcopy[k] = v
    end
    return tcopy
end

local function load_ini(ctx)
    local settings = {}
    local f = io.open(ctx.sider_dir .. "modules\\tightkit.ini")
    if f then
        for line in f:lines() do
            local name, value = string.match(line, "^([%w_]+)%s*=%s*([-%w%d.]+)")
            if name and value then
                value = tonumber(value) or value
                settings[name] = value
                log(string.format("loaded setting: %s = %s", name, value))
            end
        end
    end
    return settings
end

local function save_ini(ctx)
    local f = io.open(ctx.sider_dir .. "modules\\tightkit.ini", "wt")
    f:write(string.format("TightKit=%s", tk_values[tk_choice][1]))
    f:close()
end

local function kits_set(team_id, kit_id, cfg, home_or_away)
    local tk = tk_values[tk_choice][1]
    if tk==0 or tk==1 then
        cfg = table_copy(cfg)
        cfg.TightKit = tk
        log("ctx.kits.set: enforcing TightKit=" .. tostring(tk))
    end
    return org_kits_set(team_id, kit_id, cfg, home_or_away)
end

local function kits_set_gk(team_id, cfg)
    local tk = tk_values[tk_choice][1]
    if tk==0 or tk==1 then
        cfg = table_copy(cfg)
        cfg.TightKit = tk
        log("ctx.kits.set_gk: enforcing TightKit=" .. tostring(tk))
    end
    return org_kits_set_gk(team_id, cfg)
end

local function set_kits(ctx, home_info, away_info)
    local tk = tk_values[tk_choice][1]
    if tk==0 or tk==1 then
        log("set_kits: enforcing TightKit=" .. tostring(tk))
        return { TightKit=tk }, { TightKit=tk }
    end
end

local function enforce_tight_kit(ctx, team_id, home_or_away)
    local kit_id = ctx.kits.get_current_kit_id(home_or_away)
    local cfg = ctx.kits.get(team_id, kit_id)
    ctx.kits.set(team_id, kit_id, cfg, home_or_away)
    cfg = ctx.kits.get_gk(team_id)
    ctx.kits.set_gk(team_id, cfg)
end

local function key_up(ctx, vkey)
    if vkey == 0x30 then
        tk_choice = tk_choice % #tk_values + 1
        save_ini(ctx)

        -- refresh current kits
        tk = tk_values[tk_choice][1]
        if tk==0 or tk==1 then
            if ctx.home_team then
                enforce_tight_kit(ctx, ctx.home_team, 0)
                ctx.kits.refresh(0)
            end
            if ctx.away_team then
                enforce_tight_kit(ctx, ctx.away_team, 1)
                ctx.kits.refresh(1)
            end
        end
    end
end

local function overlay_on(ctx)
    return string.format("version %s | TightKit=%s (%s) | Press [0] - to toggle TightKit",
        version, tk_values[tk_choice][1], tk_values[tk_choice][2])
end

local function finalize_kits(ctx)
    enforce_tight_kit(ctx, ctx.home_team, 0)
    enforce_tight_kit(ctx, ctx.away_team, 1)
end

local function init(ctx)
    if ctx.kits then
        org_kits_set = ctx.kits.set
        org_kits_set_gk = ctx.kits.set_gk
        ctx.kits.set = kits_set
        ctx.kits.set_gk = kits_set_gk
    end
    local ini = load_ini(ctx)
    tk_choice = tk_values[ini.TightKit] or 1
    ctx.register("set_kits", set_kits)
    ctx.register("overlay_on", overlay_on)
    ctx.register("key_up", key_up)
    ctx.register("after_set_conditions", finalize_kits)
end

return { init = init }
