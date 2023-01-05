--[[
  example_api.lua, to demostrate how to use jparser api

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


require "jparser"

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

print("The parse result:")
if jparser.is_object(json) then
    local j = jparser.find(json, "number")
    local val = j and jparser.is_number(j) and jparser.value_of(j)
    print("number = " .. val)

    j = jparser.find(json, "obj")
    j = j and jparser.find(j, "obj_member_obj")
    j = j and jparser.find(j, "obj_nested")

    val = j and jparser.is_string(j) and jparser.value_of(j)
    print("obj_nested = " .. val)

    j = jparser.find(json, "array")
    print("array size = " .. jparser.get_array_size(j))
    print("arra[2] = " .. jparser.value_of(jparser.get_array_item(j, 2)))
else
    local val, err = jparser.value_of(json)
    print("Basic value = " .. tostring(val))
end
