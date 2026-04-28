---@meta _
---@diagnostic disable: lowercase-global

-- ── JSON encoder ──────────────────────────────────────────────────────────────

function json_val(v)
	local t = type(v)
	if t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
	elseif t == "number" or t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		-- arrays: integer keys 1..n
		if #v > 0 then
			local parts = {}
			for _, item in ipairs(v) do parts[#parts+1] = json_val(item) end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			local parts = {}
			for k, val in pairs(v) do
				parts[#parts+1] = '"' .. tostring(k) .. '":' .. json_val(val)
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return "null"
end

-- ── JSON decoder ──────────────────────────────────────────────────────────────

function json_decode(s)
	if type(s) ~= "string" or #s == 0 then return nil end
	local pos = 1

	local function skip()
		while pos <= #s and s:byte(pos) <= 32 do pos = pos + 1 end
	end

	local parse  -- forward declaration

	local function parse_string()
		pos = pos + 1  -- skip opening "
		local chars = {}
		while pos <= #s do
			local c = s:sub(pos, pos)
			if c == '"' then
				pos = pos + 1
				return table.concat(chars)
			elseif c == '\\' then
				pos = pos + 1
				local e = s:sub(pos, pos)
				local esc = {['"']='"', ['\\']='\\', ['/']='/', n='\n', r='\r', t='\t'}
				chars[#chars+1] = esc[e] or e
			else
				chars[#chars+1] = c
			end
			pos = pos + 1
		end
		return table.concat(chars)
	end

	local function parse_number()
		local n = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
		pos = pos + #n
		return tonumber(n)
	end

	local function parse_array()
		pos = pos + 1  -- skip [
		local arr = {}
		skip()
		if s:sub(pos, pos) == ']' then pos = pos + 1; return arr end
		while true do
			arr[#arr+1] = parse()
			skip()
			local c = s:sub(pos, pos); pos = pos + 1
			if c == ']' then break end
			-- c == ',' — continue
		end
		return arr
	end

	local function parse_object()
		pos = pos + 1  -- skip {
		local obj = {}
		skip()
		if s:sub(pos, pos) == '}' then pos = pos + 1; return obj end
		while true do
			skip()
			local key = parse_string()
			skip()
			pos = pos + 1  -- skip :
			obj[key] = parse()
			skip()
			local c = s:sub(pos, pos); pos = pos + 1
			if c == '}' then break end
		end
		return obj
	end

	parse = function()
		skip()
		local c = s:sub(pos, pos)
		if     c == '"' then return parse_string()
		elseif c == '{' then return parse_object()
		elseif c == '[' then return parse_array()
		elseif c == 't' then pos = pos + 4; return true
		elseif c == 'f' then pos = pos + 5; return false
		elseif c == 'n' then pos = pos + 4; return nil
		else               return parse_number()
		end
	end

	local ok, result = pcall(parse)
	if ok then return result end
	print("[HadesII_AP] json_decode error on: " .. s:sub(1, 80))
	return nil
end
