Db = require 'db'
Event = require 'event'
Plugin = require 'plugin'
{tr} = require 'i18n'


exports.onConfig = exports.onInstall = (config) !->
	Db.shared.set 'deadline', config.deadline
	setTimers()

exports.onUpgrade = !->
	setTimers()

setTimers = (extraTime=0) !->
	Timer = require 'timer'
	Timer.cancel()

	deadline = Db.shared.get 'deadline'
	return unless deadline?

	time = Plugin.time()
	dayStart = Math.floor(time/86400)*86400
	for type,offset of {remind: -1800, deadline: 0}
		next = dayStart + deadline + offset
		next += 86400 if next <= time+extraTime
		Timer.set (next-time)*1000, type

exports.remind = !->
	day = Plugin.time()/86400
	eat = Db.shared.get('days',day,'eat') || {}
	include = []
	for userId in Plugin.userIds() when !eat[userId]?
		include.push userId
	if include.length
		Event.create
			text: tr 'Will you eat/cook? Deadline in 30m!'
			unit: tr 'eat?'
			for: include
	setTimers 300

exports.deadline = !->
	day = Plugin.time()/86400
	cookId = Db.shared.get('days',day,'cook')
	eaters = []
	cnt = 0
	for userId,value of Db.shared.get('days',day,'eat') when value
		cnt += Math.abs(value)
		eaters.push userId
	if eaters.length==1
		Event.create
			text: tr 'Nobody else seems to be hungry. Too bad!'
			unit: tr 'msg'
			for: eaters
	else if eaters.length>1
		if cookId
			Event.create
				text: tr "Hey chef, diner for #{cnt} please!"
				unit: tr 'msg'
				for: [cookId]
		else
			Event.create
				text: tr "No chef yet. :( Will you feed the #{cnt} hungry?"
				unit: tr 'eat?'
				for: eaters
	setTimers 300


# exported functions prefixed with 'client_' are callable by our client code using `require('plugin').rpc`
exports.client_eat = (day, newState, userId) !->
	info = Db.shared.createRef 'days', day

	userId = (0|userId) || Plugin.userId()
	oldCookId = info.get('cook')
	cookId = if newState<0 then (if oldCookId then oldCookId else userId) else (if oldCookId==userId then null else oldCookId)

	info.set 'cook', cookId
	info.set 'eat', userId, if newState<0 then -newState else newState

	if cookId != oldCookId
		Db.personal(oldCookId).set('open',day,null) if oldCookId
		Db.personal(cookId).set('open',day,true) if cookId and !info.get('cost')?

	complaints = ""

	if userId != Plugin.userId()
		complaints += " "+tr("for %1",Plugin.userName(userId))

	deadline = Db.shared.get 'deadline'
	if deadline?
		if Plugin.time() > day*86400+deadline+(if newState<0 then 3600 else 0) # extra hour to become cook
			complaints += " "+tr("after the deadline")

	if complaints
		logComment day, 'stat'+userId, -> tr("changed status")+complaints


logComment = (day,topic,cb) !->
	comment =
		t: 0|Plugin.time()
		u: Plugin.userId()
		s: topic
	comments = Db.shared.createRef("comments",day)
	if max = 0|comments.get("max")
		last = comments.get(max)
		if last.t > comment.t-120 and last.u == comment.u and last.s == comment.s
			recycle = true
	unless recycle
		comments.set "max", ++max
	if comment.c = cb(comment, if recycle then last else null)
		comments.set max, comment


exports.client_cost = (day, value) !->
	info = Db.shared.createRef 'days', day
	value = if value==null then null else parseFloat(value)
	oldValue = info.get('cost')
	info.set 'cost', value
	cookId = info.get('cook')
	Db.personal(cookId).set('open',day,if value==null then true else null) if cookId
	
	fc = require('util.js').formatCurrency
	logComment day, 'cost', (newC, oldC) ->
		oldValue = oldC._o if oldC
		newC._o = oldValue
		tr "cost %1 → %2",
			if oldValue? then fc(oldValue) else ""
			if value? then fc(value) else "??"

