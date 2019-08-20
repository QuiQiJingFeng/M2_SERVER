local Util = require("Util")
local CONVERT_MAP = {
    ["1"] = 0,--"0",
    ["2"] = 0x6,--"110", 
    ["3"] = 0x1e,--"11110",
    ["4"] = 0x7e,--"1111110", 
    ["10"] = 0x2,--"10",
    ["20"] = 0xe,--"1110",
    ["30"] = 0x3e,--"111110",
    ["40"] = 0xfe,--"11111110"
}



local CONVERT_MAP2 = {
    ["1"] = "0",
    ["2"] = "110",
    ["3"] = "11110",
    ["4"] = "1111110",
    ["10"] = "10",
    ["20"] = "1110",
    ["30"] = "111110",
    ["40"] = "11111110"
}
function encode(data)
    local key = ""
    local code = 0
    local length = 0
    for i=#data,1,-1 do
        local result = nil
        if data[i] == 0 then
            key = "0"
        else
            key = data[i]..key
            result = key
            key = ""
        end
        if result then
        	print("result = ",result)
            code = code | CONVERT_MAP[result] << length
            length = length + #CONVERT_MAP2[result]
        end
    end
    --[[
        为了避免这种变成相同的,所以给最左边的一位补上1
        1111112
        1112
        2
    ]]
    --给第一位补上1
    code = code | 1 << length
    return code
end
-- 1111101110000
function decode(code)
	local text = Util:binaryConversion(2,code)
	text = string.sub(text,2)
	text = string.gsub(text,CONVERT_MAP2["40"],"4,X,")
	text = string.gsub(text,CONVERT_MAP2["4"],"4,")
	text = string.gsub(text,CONVERT_MAP2["30"],"3,X,")
	text = string.gsub(text,CONVERT_MAP2["3"],"3,")
	text = string.gsub(text,CONVERT_MAP2["20"],"2,X,")
	text = string.gsub(text,CONVERT_MAP2["2"],"2,")
	text = string.gsub(text,CONVERT_MAP2["10"],"1,X,")
	text = string.gsub(text,CONVERT_MAP2["1"],"1,")
	text = string.gsub(text,"X","0")
	local array =  Util:split(text,",")
	for i,v in ipairs(array) do
		array[i] = tonumber(v)
	end
	return array
end

local code = encode({2,0,3,0,3,2})
print("code = ",code)
require("functions")
dump(decode(code),"FYD=============")

