module Conversions
	public
	def celcius_to_farenheit(temp)
		for i in 0..temp.size-1
			temp[i] = temp[i].to_f
			temp[i] = temp[i] * 9/5 + 32
			temp[i] = temp[i].to_s
		end
	end
end
