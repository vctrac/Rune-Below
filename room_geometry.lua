local geometry = {width = 640, height = 396, border = 24, gap = 44}
local W, H, B = geometry.width, geometry.height, geometry.border
local sideLimits = {left = H, right = H, up = W, down = W}

local function rectangle(left, top, right, bottom)
    return {left, top, right, top, right, bottom, left, bottom}
end

local function makeLayout(name, polygons, axis)
    local layout = {name = name, axis = axis, blockers = {}, walls = {}}
    local covered = {left = {}, right = {}, up = {}, down = {}}
    for _, polygon in ipairs(polygons) do
        local points, edges, outline = {}, {}, {}
        local minX, minY, maxX, maxY = W, H, 0, 0
        for i = 1, #polygon, 2 do
            local u, v = polygon[i], polygon[i + 1]
            if axis == "vertical" then u, v = 1 - v, u end
            local x, y = B + u * (W - 2 * B), B + v * (H - 2 * B)
            points[i], points[i + 1] = x, y
            minX, maxX = math.min(minX, x), math.max(maxX, x)
            minY, maxY = math.min(minY, y), math.max(maxY, y)
        end
        for i = 1, #points, 2 do
            local j = i + 2 > #points and 1 or i + 2
            local x, y, tx, ty = points[i], points[i + 1], points[j], points[j + 1]
            local dx, dy = tx - x, ty - y
            edges[#edges + 1] = {x = x, y = y, dx = dx, dy = dy, lengthSquared = dx * dx + dy * dy}
            local side, a, b
            if x == tx and (x == B or x == W - B) then
                side, a, b = x == B and "left" or "right", y, ty
            elseif y == ty and (y == B or y == H - B) then
                side, a, b = y == B and "up" or "down", x, tx
            end
            if side then
                covered[side][#covered[side] + 1] = {math.min(a, b), math.max(a, b)}
            else
                outline[#outline + 1] = {x, y, tx, ty}
            end
        end
        layout.blockers[#layout.blockers + 1] = {
            points = points, edges = edges, outline = outline,
            minX = minX, minY = minY, maxX = maxX, maxY = maxY,
        }
    end
    for side, limit in pairs(sideLimits) do
        local spans, first = {}, B
        table.sort(covered[side], function(a, b) return a[1] < b[1] end)
        for _, interval in ipairs(covered[side]) do
            if first < interval[1] then spans[#spans + 1] = {first, interval[1]} end
            first = math.max(first, interval[2])
        end
        if first < limit - B then spans[#spans + 1] = {first, limit - B} end
        layout.walls[side] = spans
    end
    return layout
end

local passage = {rectangle(0.34, 0, 0.66, 0.37), rectangle(0.34, 0.63, 0.66, 1)}
local wedges = {{0.19, 0, 0.81, 0, 0.50, 0.24}, {0.23, 1, 0.52, 0.87, 0.80, 1}}
local arm = geometry.gap / (H - 2 * B)
geometry.standard = makeLayout("standard", {})
geometry.variants = {
    makeLayout("passage", passage, "horizontal"),
    makeLayout("passage", passage, "vertical"),
    makeLayout("wedges", wedges, "horizontal"),
    makeLayout("wedges", wedges, "vertical"),
    makeLayout("island", {rectangle(0.30, 0.25, 0.70, 0.75)}),
    makeLayout("cross", {
        rectangle(0, 0, 0.25, 0.5 - arm), rectangle(0.75, 0, 1, 0.5 - arm),
        rectangle(0, 0.5 + arm, 0.25, 1), rectangle(0.75, 0.5 + arm, 1, 1),
    }),
}

function geometry.fits(layout, room)
    local exits = room.exits
    if layout.axis == "horizontal" then return not (exits.up or exits.down) end
    if layout.axis == "vertical" then return not (exits.left or exits.right) end
    return layout.name ~= "island" or not room.rune
end

function geometry.blocked(room, x, y, radius)
    local layout = room.layout or geometry.standard
    local radiusSquared = radius * radius
    for _, block in ipairs(layout.blockers) do
        if x >= block.minX - radius and x <= block.maxX + radius
            and y >= block.minY - radius and y <= block.maxY + radius then
            local inside = true
            for _, edge in ipairs(block.edges) do
                local dx, dy = x - edge.x, y - edge.y
                if edge.dx * dy - edge.dy * dx < 0 then inside = false end
                local t = math.max(0, math.min(1, (dx * edge.dx + dy * edge.dy) / edge.lengthSquared))
                if (dx - t * edge.dx)^2 + (dy - t * edge.dy)^2 <= radiusSquared then return true end
            end
            if inside then return true end
        end
    end
    return false
end

function geometry.blocksLine(room, x, y, tx, ty)
    local layout = room.layout or geometry.standard
    local dx, dy = tx - x, ty - y
    local minX, maxX, minY, maxY = math.min(x, tx), math.max(x, tx), math.min(y, ty), math.max(y, ty)
    for _, block in ipairs(layout.blockers) do
        if minX <= block.maxX and maxX >= block.minX and minY <= block.maxY and maxY >= block.minY then
            -- Clip the segment against each inward-facing half-plane of the convex blocker.
            local first, last = 0, 1
            for _, edge in ipairs(block.edges) do
                local offset = edge.dx * (y - edge.y) - edge.dy * (x - edge.x)
                local rate = edge.dx * dy - edge.dy * dx
                if rate > 0 then first = math.max(first, -offset / rate)
                elseif rate < 0 then last = math.min(last, -offset / rate)
                elseif offset < 0 then first = math.huge end
                if first > last then break end
            end
            if first <= last then return true end
        end
    end
    return false
end

return geometry
