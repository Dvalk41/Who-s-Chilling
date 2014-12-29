exports.formatCurrency = (val) ->
	sign = ''
	if val<0
		val = -val
		sign = '-'
	val = 0|(val*100)
	c = val%100
	sign+"€" + (0|(val/100)) + "," + (0|(c/10)) + (c%10)

exports.getUTCDay = getUTCDay = (day) ->
	date = new Date(day*86400000)
	date.getUTCDay()

exports.getInvolvedUserIds = (info, pluginUserIds) ->
	userIds = {}

	# add every happening member at least
	userIds[userId] = true for userId in pluginUserIds

	# completed with people involved with this day
	if info?
		day = info.key()
		userIds[k] = true for k, v of info.get('eat')

	userIds
