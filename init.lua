-- =====================
-- RULES + REPORTS + GUIDE + EVENTS MOD
-- =====================

-- =====================
-- Storage setup
-- =====================
local rules_path = minetest.get_worldpath() .. "/rules.txt"
local reports_path = minetest.get_worldpath() .. "/reports.txt"
local guides_path = minetest.get_worldpath() .. "/guides.txt"
local events_path = minetest.get_worldpath() .. "/events.txt"

local rules_text = "Welcome to the server!\n1. Be respectful\n2. No griefing\n3. Have fun!"
local reports = {}
local guides = { ["General"] = "This is the server guide.\nFollow the basics here." }
local events_text = "No events currently scheduled."

-- Load / Save helpers
local function load_file(path, default)
    local f = io.open(path, "r")
    if f then
        local content = f:read("*all")
        f:close()
        return minetest.deserialize(content) or content
    end
    return default
end

local function save_file(path, content)
    local f = io.open(path, "w")
    if f then
        if type(content) == "table" then
            f:write(minetest.serialize(content))
        else
            f:write(content)
        end
        f:close()
    end
end

-- Load stored data
rules_text = load_file(rules_path, rules_text)
reports = load_file(reports_path, reports)
guides = load_file(guides_path, guides)
events_text = load_file(events_path, events_text)

-- =====================
-- RULES
-- =====================
local function show_rules(player_name)
    local formspec = "formspec_version[4]size[10,7]" ..
        "textarea[0.5,0.5;9,5;rules;Server Rules:;" .. minetest.formspec_escape(rules_text) .. "]" ..
        "button_exit[4,6;2,1;done;Done]"
    minetest.show_formspec(player_name, "rules_mod:rules", formspec)
end

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local meta = player:get_meta()
    if not meta:get_string("seen_rules") or meta:get_string("seen_rules") == "" then
        minetest.after(2, function() show_rules(name) end)
    end
end)

minetest.register_privilege("rulemkr", { description = "Can edit the server rules", give_to_singleplayer = true, give_to_admin = true })

minetest.register_chatcommand("rules", {
    description = "Show the server rules",
    func = function(name) show_rules(name) return true, "Rules opened." end,
})

minetest.register_chatcommand("rulesedit", {
    description = "Edit the server rules",
    privs = { rulemkr = true },
    func = function(name)
        local formspec = "formspec_version[4]size[10,7]" ..
            "textarea[0.5,0.5;9,5;edit;Edit Rules:;" .. minetest.formspec_escape(rules_text) .. "]" ..
            "button[4,6;2,1;save;Save]"
        minetest.show_formspec(name, "rules_mod:edit", formspec)
    end,
})

minetest.register_chatcommand("frul", {
    description = "Force rules popup for a player",
    params = "<player>",
    privs = { rulemkr = true },
    func = function(name, param)
        if param == "" then return false, "Usage: /frul <player>" end
        local target = minetest.get_player_by_name(param)
        if target then target:get_meta():set_string("seen_rules", "") end
        return true, "Rules popup forced for " .. param
    end,
})

-- =====================
-- REPORTS
-- =====================
minetest.register_privilege("redit", { description = "Can comment on reports", give_to_admin = true })

local function show_reports(player_name, idx)
    idx = idx or 1
    local report = reports[idx]
    if not report then
        minetest.show_formspec(player_name, "rules_mod:reports", "formspec_version[4]size[8,5]label[0.5,0.5;No reports yet]")
        return
    end

    local comments = table.concat(report.comments or {}, "\n")
    local formspec = "formspec_version[4]size[10,8]" ..
        "label[0.5,0.5;Report by " .. report.owner .. ":]" ..
        "textarea[0.5,1;9,3;report;Report:;" .. minetest.formspec_escape(report.text) .. "]" ..
        "textarea[0.5,4;9,2;comments;Comments:;" .. minetest.formspec_escape(comments) .. "]" ..
        "button[2,6.5;2,1;prev;< Prev]" ..
        "button[4,6.5;2,1;next;Next >]" ..
        "button_exit[6,6.5;2,1;close;Close]" ..
        "button[0.5,6.5;2,1;add_comment;Add Comment]"
    minetest.show_formspec(player_name, "rules_mod:report_" .. idx, formspec)
end

minetest.register_chatcommand("report", {
    description = "File a new report",
    func = function(name)
        local formspec = "formspec_version[4]size[10,6]" ..
            "textarea[0.5,0.5;9,4;newreport;Write your report:;" ..
            "]button_exit[4,5;2,1;submit;Submit]"
        minetest.show_formspec(name, "rules_mod:new_report", formspec)
    end,
})

-- =====================
-- GUIDE
-- =====================
minetest.register_privilege("gued", { description = "Can edit the server guide", give_to_admin = true })

local function show_guide(player_name, section)
    section = section or "General"
    local content = guides[section] or "No content yet."
    local buttons = ""
    local x = 0.5
    for sec, _ in pairs(guides) do
        buttons = buttons .. "button[" .. x .. ",0.5;2,1;" .. sec .. ";" .. sec .. "]"
        x = x + 2.2
    end
    if minetest.check_player_privs(player_name, { gued = true }) then
        buttons = buttons .. "button[" .. x .. ",0.5;2,1;add_section;+]"
    end

    local formspec = "formspec_version[4]size[12,8]" ..
        buttons ..
        "textarea[0.5,2;11,5;guide;" .. section .. ";" .. minetest.formspec_escape(content) .. "]"
    if minetest.check_player_privs(player_name, { gued = true }) then
        formspec = formspec .. "button[5,7.2;2,1;save_guide;Save]"
    else
        formspec = formspec .. "button_exit[5,7.2;2,1;close;Close]"
    end
    minetest.show_formspec(player_name, "rules_mod:guide_" .. section, formspec)
end

minetest.register_chatcommand("guide", {
    description = "Open the server guide",
    func = function(name) show_guide(name, "General") end,
})

-- =====================
-- EVENTS
-- =====================
minetest.register_privilege("eved", { description = "Can edit server events", give_to_admin = true })

local function show_events(player_name)
    local formspec = "formspec_version[4]size[10,7]" ..
        "textarea[0.5,0.5;9,5;events;Server Events:;" .. minetest.formspec_escape(events_text) .. "]"
    if minetest.check_player_privs(player_name, { eved = true }) then
        formspec = formspec .. "button[4,6;2,1;save_events;Save]"
    else
        formspec = formspec .. "button_exit[4,6;2,1;close;Close]"
    end
    minetest.show_formspec(player_name, "rules_mod:events", formspec)
end

minetest.register_chatcommand("events", {
    description = "Open the events menu",
    func = function(name) show_events(name) end,
})

-- =====================
-- FORMSPEC HANDLING
-- =====================
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()

    -- Rules
    if formname == "rules_mod:rules" and fields.done then
        player:get_meta():set_string("seen_rules", "true")
    elseif formname == "rules_mod:edit" and fields.save and fields.edit then
        rules_text = fields.edit
        save_file(rules_path, rules_text)
        for _, p in ipairs(minetest.get_connected_players()) do
            p:get_meta():set_string("seen_rules", "")
            minetest.chat_send_player(p:get_player_name(), "⚠️ Rules got updated! Use /rules")
        end
    end

    -- Reports
    if formname == "rules_mod:new_report" and fields.submit and fields.newreport and fields.newreport ~= "" then
        table.insert(reports, { owner = name, text = fields.newreport, comments = {} })
        save_file(reports_path, reports)
        minetest.chat_send_player(name, "Report submitted.")
    end
    if formname:match("^rules_mod:report_") then
        local idx = tonumber(formname:match("%d+"))
        if fields.add_comment and minetest.check_player_privs(name, { redit = true }) then
            table.insert(reports[idx].comments, name .. ": (new comment)")
            save_file(reports_path, reports)
            show_reports(name, idx)
        elseif fields.next then show_reports(name, (idx or 1) + 1)
        elseif fields.prev then show_reports(name, math.max(1, (idx or 1) - 1)) end
    end

    -- Guide
    if formname:match("^rules_mod:guide_") then
        local section = formname:gsub("rules_mod:guide_", "")
        if fields.save_guide and fields.guide then
            guides[section] = fields.guide
            save_file(guides_path, guides)
            minetest.chat_send_player(name, "Guide saved for section: " .. section)
        elseif fields.add_section and minetest.check_player_privs(name, { gued = true }) then
            local new_section = "Section" .. tostring(#guides + 1)
            guides[new_section] = "New section content."
            save_file(guides_path, guides)
            show_guide(name, new_section)
        else
            for sec, _ in pairs(guides) do
                if fields[sec] then show_guide(name, sec) end
            end
        end
    end

    -- Events
    if formname == "rules_mod:events" and fields.save_events and fields.events then
        events_text = fields.events
        save_file(events_path, events_text)
        minetest.chat_send_player(name, "Events updated successfully!")
    end
end)
