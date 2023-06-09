return function(condition)
	return function(cases)
		local found = false
		local result
		
		for key, val in pairs(cases) do
			if found then break end
			
			if type(key) == "table" then
				for _, condKey in ipairs(key) do
					if condKey == condition then
						found = true
						result = val
						break
					end
				end
			else
				if key == condition then
					found = true
					result = val
					break
				end
			end
		end
		
		if not found then
			result = cases.default
		end
		
		if result then
			return if type(result) == "function" then result() else result
		end
	end
end
