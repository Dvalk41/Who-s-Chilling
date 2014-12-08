exports.formatCurrency = (val) ->
	sign = ''
	if val<0
		val = -val
		sign = '-'
	val = 0|(val*100)
	c = val%100
	sign+"€" + (0|(val/100)) + "," + (0|(c/10)) + (c%10)

