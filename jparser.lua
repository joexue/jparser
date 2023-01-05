--[[
  jparser.lua

  MIT License

  Copyright (c) 2023 Joe Xue (lgxue@hotmail.com)

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
--]]

local TOKEN_STRING             = 0
local TOKEN_NUMBER             = 1
local TOKEN_TRUE               = 2
local TOKEN_FALSE              = 3
local TOKEN_NULL               = 4
local TOKEN_COMMA              = 5
local TOKEN_COLON              = 6
local TOKEN_BRAKET_LEFT        = 7
local TOKEN_BRAKET_RIGHT       = 8
local TOKEN_CURLY_BRAKET_LEFT  = 9
local TOKEN_CURLY_BRAKET_RIGHT = 10

local JSON_STRING              = 0
local JSON_NUMBER              = 1
local JSON_TRUE                = 2
local JSON_FALSE               = 3
local JSON_NULL                = 4
local JSON_PAIR                = 5
local JSON_ARRAY               = 6
local JSON_OBJECT              = 7

local token_lookup = {
    [','] = TOKEN_COMMA,
    [':'] = TOKEN_COLON,
    ['['] = TOKEN_BRAKET_LEFT,
    [']'] = TOKEN_BRAKET_RIGHT,
    ['{'] = TOKEN_CURLY_BRAKET_LEFT,
    ['}'] = TOKEN_CURLY_BRAKET_RIGHT
}

local function is_token_string(str)
    if string.match(str, '".*"') == str then
        return true
    end

    return false
end

local function is_token_number(str)
    if tonumber(str) ~= nil then
        return true
    end

    return false
end

local function match_token(token, token_type)
    return token_type == token[1]
end

local match_value

local function match_pair(tokens, pos)
    if not match_token(tokens[pos], TOKEN_STRING) then
        return false, pos
    end

    local var = string.sub(tokens[pos][4], 2, -2)

    pos = pos + 1

    if not match_token(tokens[pos], TOKEN_COLON) then
        return false, pos
    end

    pos = pos + 1

    local rc, pos, json = match_value(tokens, pos)
    if rc then
        return rc, pos, {JSON_PAIR, var, json}
    end

    return false, pos
end

local function match_array(tokens, pos)
    local tree = {}

    if not match_token(tokens[pos], TOKEN_BRAKET_LEFT) then
        return false, pos
    end

    pos = pos + 1

    -- Empty array case
    if match_token(tokens[pos], TOKEN_BRAKET_RIGHT) then
        pos = pos + 1
        return true, pos, {JSON_ARRAY, "", tree}
    end

    while #tokens >= pos do
        local rc, json
        rc, pos, json = match_value(tokens, pos)
        if not rc then
            return false, pos
        end

        table.insert(tree, json)

        if not match_token(tokens[pos], TOKEN_COMMA) then
            break
        end

        pos = pos + 1
    end

    if match_token(tokens[pos], TOKEN_BRAKET_RIGHT) then
        pos = pos + 1
        return true, pos, {JSON_ARRAY, "", tree}
    end

    return false, pos
end

local function match_object(tokens, pos)
    local tree = {}

    if not match_token(tokens[pos], TOKEN_CURLY_BRAKET_LEFT) then
        return false, pos
    end

    pos = pos + 1

    -- Empty object case
    if match_token(tokens[pos], TOKEN_CURLY_BRAKET_RIGHT) then
        pos = pos + 1
        return true, pos, {JSON_OBJECT, "", tree}
    end

    while #tokens >= pos do
        local rc, json
        rc, pos, json = match_pair(tokens, pos)
        if not rc then
            return false, pos
        end

        table.insert(tree, json)

        if not match_token(tokens[pos], TOKEN_COMMA) then
            break
        end

        pos = pos + 1
    end

    if match_token(tokens[pos], TOKEN_CURLY_BRAKET_RIGHT) then
        pos = pos + 1
        return true, pos, {JSON_OBJECT, "", tree}
    end

    return false, pos
end

match_value = function(tokens, pos)
    local rc, json, pos_temp = 0

    if match_token(tokens[pos], TOKEN_STRING) then
        return true, pos + 1, {JSON_STRING, "", string.sub(tokens[pos][4], 2, -2)}
    end

    if match_token(tokens[pos], TOKEN_NUMBER) then
        return true, pos + 1, {JSON_NUMBER, "", tokens[pos][4]}
    end

    if match_token(tokens[pos], TOKEN_TRUE) then
        return true, pos + 1, {JSON_TRUE, "", tokens[pos][4]}
    end

    if match_token(tokens[pos], TOKEN_FALSE) then
        return true, pos + 1, {JSON_FALSE, "", tokens[pos][4]}
    end

    if match_token(tokens[pos], TOKEN_NULL) then
        return true, pos + 1, {JSON_NULL, "", tokens[pos][4]}
    end

    rc, pos_temp, json = match_array(tokens, pos)
    if rc then
        return rc, pos_temp, json
    end

    rc, pos, json = match_object(tokens, pos)
    if rc then
        return rc, pos, json
    end

    return false, (pos_temp > pos) and pos_temp or pos, nil
end

-- @param  tokens The table of tokens
-- @return json   The JSON data structure
-- @return err    The error message if there is error happens or nil
-- @see    parse
local function parser(tokens)
    -- Start to parse from the first token
    local rc, pos, json = match_value(tokens, 1)

    -- either the match failed or there is extra tokens which should not exist
    if not rc or pos <= #tokens then
        local _, line, col, token = table.unpack(tokens[pos])
        return nil, string.format('Error JSON format "%s" at line: %d, position: %d', token, line, col)
    end

    return json, nil
end

-- @param  buf    The JSON data buf
-- @return tokens The table of all valid tokens
-- @return err    The error message if there is error happens or nil
-- @field         The token format {TOKEN_TYPE, line, colum, token_str}
local function lexer(buf)
    local tokens = {}
    local token = {}

    local col = 0
    local line = 1

    for i = 1, #buf + 1 do
        local c = buf:sub(i,i)
        col = col + 1
        if i == #buf + 1
            or c == ' ' or c == '\n'
            or c == '\r' or c == '\t'
            or c == ',' or c == ':'
            or c == '{' or c == '}'
            or c == '[' or c == ']' then
            if #token > 0 then
                token = table.concat(token)
                if token == 'true' then
                    table.insert(tokens, {TOKEN_TRUE, line, col - #token, token})
                elseif token == 'false' then
                    table.insert(tokens, {TOKEN_FALSE, line, col - #token, token})
                elseif token == 'null' then
                    table.insert(tokens, {TOKEN_NULL, line, col - #token, token})
                elseif is_token_string(token) then
                    table.insert(tokens, {TOKEN_STRING, line, col - #token, token})
                elseif is_token_number(token) then
                    table.insert(tokens, {TOKEN_NUMBER, line, col - #token, token})
                else
                    local err = string.format('Unrecognized word "%s" at line: %d, position: %d', token, line, col - #token)
                    return nil, err
                end
                token = {}
            end
            local t = token_lookup[c]
            if t then
                table.insert(tokens, {t, line, col, c})
            end
        else
            table.insert(token, c)
        end

        if c == '\n' then
            line = line + 1
            col = 0
        end
    end

    if #tokens > 0 then
        return tokens, nil
    else
        return nil, "No JSON data input"
    end
end

-- @param  json The JSON data structure
-- @return ture/false
local function is_object(json)
    return json and json[1] and json[1] == JSON_OBJECT
end

local function is_array(json)
    return json and json[1] and json[1] == JSON_ARRAY
end

local function is_pair(json)
    return json and json[1] and json[1] == JSON_PAIR
end

local function is_string(json)
    return json and json[1] and json[1] == JSON_STRING
end

local function is_number(json)
    return json and json[1] and json[1] == JSON_NUMBER
end

local function is_true(json)
    return json and json[1] and json[1] == JSON_TRUE
end

local function is_false(json)
    return json and json[1] and json[1] == JSON_FALSE
end

local function is_null(json)
    return json and json[1] and json[1] == JSON_NULL
end

-- @param  json The JSON data structure
-- @return      The name of JSON pair
local function get_pair_name(json)
    if is_pair(json) then
        return json[2]
    end
end

-- @param  json The JSON data structure
-- @return      The value of JSON pair
local function get_pair_value(json)
    if is_pair(json) then
        return json[3]
    end
end

-- @param  json The JSON data structure
-- @return      The size of array
local function get_array_size(json)
    if json and is_array(json) and json[3] then
        return #json[3]
    end

    return 0
end

-- @param  json The JSON data structure
-- @return      The JSON datastruct of array at index
local function get_array_item(json, index)
    return json and json[3] and json[3][index]
end

-- @param  json The JSON data structure
-- @return data The JSON basic data or nil
-- @return err  The error message if there is error happens or nil
local function value_of(json)
    if is_string(json) then
        return json[3]
    elseif is_number(json) then
        return tonumber(json[3])
    elseif is_true(json) then
        return true
    elseif is_false(json) then
        return false
    elseif is_null(json) then
        return nil
    end

    return nil, "Not a basic JSON type"
end

-- @param  json The JSON data structure
-- @param  cb   The call back function
-- @param  uap  The user application data
local function foreach(json, cb, uap)
    if is_object(json) or is_array(json) then
        local _, _, t = table.unpack(json)
        for i = 1, #t do
            cb(t[i], uap)
        end
    else
        cb(json, uap)
    end
end

-- @param  json   The JSON data structure
-- @param  cb_in  The call back function when enter one JSON item
-- @param  cb_out The call back function when exit one JSON iterm
-- @param  uap    The user application data
local function walk(json, cb_in, cb_out, uap)
    if cb_in then
        cb_in(json, uap)
    end

    if is_object(json) or is_array(json) then
        local _, _, t = table.unpack(json)
        for i = 1, #t do
            walk(t[i], cb_in, cb_out, uap)
        end
    elseif is_pair(json) then
        local _, _, t = table.unpack(json)
        walk(t, cb_in, cb_out, uap)
    end

    if cb_out then
        cb_out(json, uap)
    end
end

-- @param  json The JSON data structure
-- @param  name The name of JSON data
-- @return      The JSON data structure associated to the name
local function find(json, name)
    if is_object(json) then
        local _, _, t = table.unpack(json)
        for i = 1, #t do
            local _, n, t1 = table.unpack(t[i])
            if n == name then
                return t1
            end
        end
    end

    return nil
end

-- @param  buf  The JSON data buf
-- @return json The JSON data structure
-- @return err  The error message if there is error happens or nil
-- @field       The JSON structure format {JSON_TYPE, name, value}
--              the value inside could be a basic data such as string, number
--              true, false, null, or a nested JSON structure.
local function parse(buf)
    local tokens, err = lexer(buf)
    if tokens then
        local json, err = parser(tokens)
        return json, err
    end

    return nil, err
end

jparser = {
    parse     = parse,
    find      = find,
    is_object = is_object,
    is_array  = is_array,
    is_pair   = is_pair,
    is_string = is_string,
    is_number = is_number,
    is_true   = is_true,
    is_false  = is_false,
    is_null   = is_null,
    value_of  = value_of,
    walk      = walk,
    foreach   = foreach,
    get_pair_name  = get_pair_name,
    get_pair_value = get_pair_value,
    get_array_size = get_array_size,
    get_array_item = get_array_item
}

return jparser
