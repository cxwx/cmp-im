local cmp = require('cmp')
local utils = require('cmp_im.utils')
local source = { }
---Default options
local im_opts = {
    enable = false,
    tables = { },
    format = function(key, text)
        return vim.fn.printf('%-15S %s', text, key)
    end,
    maxn = 8,
}
---All IM tables
local im_tbls = nil


local function load_tbls(files)
    if not im_opts.enable then
        return
    end
    if not im_tbls then
        im_tbls = {}
        for _, fn in ipairs(files) do
            local tbl = utils.load_tbl(fn)
            if tbl:valid() then
                im_tbls[#im_tbls+1] = tbl
            else
                vim.notify(string.format("Failed to load %s as cmp-im's table", fn), vim.log.levels.WARN)
            end
        end
    end
end

local function cmp_item(key, val, params)
    local ctx = params.context
    local cur = ctx.cursor
    return {
        label = im_opts.format(key, val),
        sortText = key,
        filterText = key,
        textEdit = {
            newText = val,
            insert = {
                ['start'] = { line = cur.line, character = cur.character - (cur.col - params.offset) },
                ['end'] = { line = cur.line, character = cur.character },
            },
        }
    }
end

local function match_tbls(params)
    local res = {}
    if not im_tbls then
        return res
    end

    local key = string.sub(params.context.cursor_before_line, params.offset)
    for _, tbl in ipairs(im_tbls) do
        local cnt = 0
        if tbl:ordered() then
            -- Match start from idx
            local idx = tbl:index(key)
            if idx then
                repeat
                    local kvs = tbl.lst[idx + cnt]
                    if (not kvs) or (not string.match(kvs[1], '^' .. key)) then
                        break
                    end
                    for i, v in ipairs(kvs) do
                        if i >= 2 then
                            res[#res+1] = cmp_item(kvs[1], v, params)
                            cnt = cnt + 1
                            if cnt >= im_opts.maxn then
                                break
                            end
                        end
                    end
                until (cnt >= im_opts.maxn)
            end
        else
            -- A brute force match that still provides a pretty accepted performance!(Yes, luajit)
            for _, kv in ipairs(tbl.lst) do
                if string.match(kv[1], '^' .. key) then
                    cnt = cnt + 1
                    res[#res+1] = cmp_item(kv[1], kv[2], params)
                end
                if cnt >= im_opts.maxn then
                    break
                end
            end
        end
    end

    return res
end

function source:is_available()
    return im_opts.enable
end

function source:get_keyword_pattern()
    return [[\l\+]]
end

function source:get_trigger_characters()
    return {'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z'}
end

function source:complete(params, callback)
    load_tbls(im_opts.tables)
    -- local t0 = vim.fn.reltime()
    local res = match_tbls(params)
    -- vim.notify('Match elapsed: ' .. tostring(vim.fn.reltimestr(vim.fn.reltime(t0))))
    if #res > 0 then
        return callback(res)
    end
    return callback()
end

---Setup IM's options
local function setup(opts)
    im_opts = vim.tbl_deep_extend('keep', opts, im_opts)
end

---Enable/Disable IM source
local function toggle()
    im_opts.enable = not im_opts.enable
    return im_opts.enable
end

---Select the entry from IM
local function select(index)
    return function(fallback)
        if cmp.visible() then
            local entries = cmp.get_entries()
            if index and index > 0 then
                cmp.select_next_item()
                cmp.select_next_item({count = index - 1})
                return cmp.confirm()
            end
            if #entries > 0 and entries[1].source.name == 'IM' then
                return cmp.confirm({ select = true })
            end
        end
        return fallback()
    end
end

return {
    source = source,
    setup = setup,
    toggle = toggle,
    select = select,
}
