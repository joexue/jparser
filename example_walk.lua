--[[
  example_walk.lua to demostrate how to use jparser walk

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


--[[
  This example demostrate how to use foreach to transverse the whole JSON data
  and restruct it. i.e. JSON -> parse -> JSON
--]]

require "jparser"

local ident = 0

-- The function to use walk to visit the whole JSON data
local function cb_enter(json, output)
    if jparser.is_object(json) then
        table.insert(output, "{\n")
        ident = ident + 4
        return
    end

    if jparser.is_array(json) then
        table.insert(output, "[")
        return
    end

    if jparser.is_pair(json) then
        local var = jparser.get_pair_name(json)
        local val = jparser.get_pair_value(json)
        local ident_space = string.rep(" ", ident)
        table.insert(output, ident_space .. '"' .. var .. '" : ')
        return
    end
end

local function cb_exit(json, output)
    if jparser.is_object(json) then
        -- to remove the last ', ', makes it pretty
        if output[#output] == ', ' then
            table.remove(output)
        end
        if output[#output] == '\n' and output[#output - 1] == ', ' then
            table.remove(output, #output - 1)
        end

        ident = ident - 4
        local ident_space = string.rep(" ", ident)
        table.insert(output, ident_space .. "}")
        return
    end

    if jparser.is_array(json) then
        if output[#output] == ', ' then
            table.remove(output)
        end

        table.insert(output, "]")
        table.insert(output, ", ")
        return
    end

    if jparser.is_pair(json) then
        table.insert(output, "\n")
    end

    if jparser.is_string(json) then
        table.insert(output, '"' .. jparser.value_of(json) .. '"')
        table.insert(output, ", ")
    end

    if jparser.is_number(json) then
        table.insert(output, jparser.value_of(json))
        table.insert(output, ", ")
    end

    if jparser.is_true(json) then
        table.insert(output, "true");
        table.insert(output, ", ")
    end

    if jparser.is_false(json) then
        table.insert(output, "false");
        table.insert(output, ", ")
    end

    if jparser.is_null(json) then
        table.insert(output, "null");
        table.insert(output, ", ")
    end
end

local path = arg[1]
if path then
    io.input(path)
end

local data = io.read("a")

print("The original JSON data:")
print(data)
print("")

local json, err = jparser.parse(data)
assert(json, err)

local output = {}
jparser.walk(json, cb_enter, cb_exit, output)
print("The parse result:")
print(table.concat(output))
