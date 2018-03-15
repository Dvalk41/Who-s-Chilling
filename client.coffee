Util = require 'util.js'

Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Obs = require 'obs'
Server = require 'server'
Time = require 'time'
Form = require 'form'
Page = require 'page'
App = require 'app'
Ui = require 'ui'
Colors = App.colors()
{tr} = require 'i18n'


dayNames = [
	tr 'Sunday'
	tr 'Monday'
	tr 'Tuesday'
	tr 'Wednesday'
	tr 'Thursday'
	tr 'Friday'
	tr 'Saturday'
]

monthNames = [
	tr 'Jan'
	tr 'Feb'
	tr 'Mar'
	tr 'Apr'
	tr 'May'
	tr 'Jun'
	tr 'Jul'
	tr 'Aug'
	tr 'Sep'
	tr 'Oct'
	tr 'Nov'
	tr 'Dec'
]

fullMonthNames = [
	tr 'Januari'
	tr 'Februari'
	tr 'March'
	tr 'April'
	tr 'May'
	tr 'Juni'
	tr 'July'
	tr 'August'
	tr 'Sepember'
	tr 'October'
	tr 'November'
	tr 'December'
]

renderCurrency = (val) ->
	Dom.text Util.formatCurrency val

getDayName = (day) ->
	date = new Date(day*86400000)
	dayNames[date.getUTCDay()] + ' ' + date.getUTCDate() + ' ' + monthNames[date.getUTCMonth()]

getState = (info,userId) ->
	cookId = info.get('cook')
	state = info.get('eat',userId)
	state %= 1000 if state? and state isnt ''
	if cookId==userId then -state else state

getPluginUserIds = ->
	+uid for uid of App.users.get()

stateIcon = (state) !->
	icon = if !state? or state is '' then 'unknown' else if state>0 then 'yes' else if state<0 then 'cook' else 'no'
	Dom.img !->
		Dom.prop src: App.resourceUri("eat-#{icon}.png")
		Dom.style
			maxWidth: '32px'
			maxHeight: '24px'
			width: 'auto'
			verticalAlign: 'middle'

plusIcon = (state) !->
	if (state>1 or state<-1)
		Dom.style
			fontWeight: 'bold'
			color: App.colors().highlight
		Dom.span !->
			Dom.style paddingLeft: '4px'
			Dom.text "+"+(Math.abs(state)-1)

setState = (info,userId,newState) !->
	Server.sync 'eat', info.key(), newState, userId, !->
		cookId = info.get('cook')
		info.set 'cook', if newState<0 then (if cookId then cookId else userId) else (if cookId==userId then null else cookId)
		info.set 'eat', userId, if newState<0 then -newState else (if !newState? or newState is '' then '' else +newState)

editingOthers = {}
editOther = (func,info,userId) ->
	return true if App.userId()==userId || editingOthers[userId]
	require('modal').confirm tr("Are you sure you want to make this update on behalf of %1?",App.userName(userId)), !->
		editingOthers[userId] = true
		func info, userId

nextState = (info,userId) ->
	return unless editOther(nextState,info,userId)
	cookId = info.get('cook')
	state = info.get('eat',userId)
	state %= 1000 if state? and state isnt ''
	state = -state if cookId==userId
	setState info, userId, if (!state? or state is '') then 1 else if state<0 then '' else if state>0 then 0 else (if cookId then '' else -1)

plusState = (info,userId) ->
	return unless editOther(plusState,info,userId)
	buttons = ['0', tr("No")]
	for i in [1..4]
		buttons.push i, i
	chosen = (val) !->
		if val?
			state = getState info, userId
			setState info, userId, if state<0 then -val-1 else val+1
	require('modal').show tr('Bringing guests?'), null, chosen, buttons

iconDiv = (func) !->
	Dom.div !->
		Dom.style
			Box: 'middle center'
			padding: '14px 12px'
			minWidth: '32px'
			minHeight: '28px'
		func?()

offset = (new Date).getTimezoneOffset()
today = 0|((App.time()-offset*60)/86400)

renderDayItem = (day) !->
	if typeof day=='object'
		info = day
		day = 0|info.key()
	else
		info = Db.shared.ref('days', day) || new Obs.Value(null,day)

	userId = App.userId()

	Form.row !->
		Dom.style
			Box: "middle"
			Flex: 1
			padding: '0px'
		cookId = info.get('cook')
		Dom.div !->
			Dom.style padding: '12px'
			if cookId
				Ui.avatar (App.userAvatar cookId)
			else
				Dom.div !->
					Dom.style
						Box: 'middle center'
						height: '38px'
						width: '38px'
						borderRadius: '38px'
						margin: '0 4px 0 0'
						border: '1px solid #ddd'
						fontSize: '65%'
						fontWeight: 'bold'
						color: '#ccc'
						textTransform: 'uppercase'
						textAlign: 'center'
					Dom.text tr("No")
					Dom.br()
					Dom.text tr("Chef")

		Dom.div !->
			Dom.style
				Flex: 1
				fontWeight: (if day==today then 'bold' else 'normal')
				color: (if day==today then '#000' else 'inherit')
				padding: '12px 0px'
			Dom.text getDayName(day)

			Dom.div !->
				cnt = 0
				for k,v of info.get('eat')
					v %= 1000 if v isnt ''
					cnt += +v

				Dom.style
					fontSize: '80%'
					fontWeight: 'normal'
					color: if cnt or cookId then 'inherit' else '#aaa'
				Dom.text if cookId then tr("%1 hosting for %2",App.userName(cookId),cnt) else tr("%1 bored/sober |person|people",cnt)

		Event.renderBubble [day], style: marginLeft: '4px'
		###
		if unread = Social.newComments(day)
			Ui.unread unread, null, {marginLeft: '4px'}
		###

		Dom.onTap !->
			Page.nav [day]

		Form.vSep()

		iconDiv !->
			state = getState info, userId
			stateIcon state
			plusIcon state
			Dom.onTap
				cb: !-> nextState info, userId
				longTap: !-> plusState info, userId

renderDayPage = (day) !->
	Page.setTitle getDayName(day)
	Page.setCardBackground();
	Comments.enable
		legacyStore: day
		messages:
			deadline: (c) -> tr("%1 changed status after the deadline", c.user)
			other: (c) -> tr("%1 changed status for %2", c.user, c.about)
			otherdeadline: (c) -> tr("%1 changed status for %2 after the deadline", c.user, c.about)
			cost: (c) ->
				fc = require('util.js').formatCurrency
				if c.c2
					tr("%1 changed total cost from #{fc(c.c2)} to #{fc(c.c1)}", c.user)
				else
					tr("%1 entered total cost #{fc(c.c1)}", c.user)
			remind: (c) -> tr("Are you Bored/Sober? Deadline in 30m!")

	info = Db.shared.ref('days', day) || new Obs.Value(null,day)
	userId = App.userId()

	Dom.section !->
		Dom.style ChildMargin: 12
		Form.box
			content: tr "Your status"
			sub: !->
				state = getState(info, userId)
				Dom.text if state<0
						tr "Sober/Bored, and I'm hosting"
					else if state>0
						tr "Sober/Bored"
					else if state is 0
						tr "Not joining real nigga hours"
					else
						tr "Not deciding, Pussy Boy"
			icon: !->
				stateIcon getState(info, userId)
			onTap: !-> nextState info, userId

		Obs.observe !->
			state = getState(info, userId)
			Form.box
				content: tr "Your guests"
				sub: !->
					Dom.div !->
						#Dom.style Flex: true
						#Dom.text tr "Bringing guests?"
						if state<-1 or state>1
							Dom.text tr "Bringing %1 guest|s", (Math.abs(state)-1)
						else
							Dom.text tr "Not bringing guests"
				icon: !->
					plusIcon state
				onTap: !-> plusState info, userId

	Dom.section !->
		Dom.style ChildMargin: 12
		cookId = info.get('cook')
		Form.label !->
			Dom.text if cookId then tr("Chef %1", App.userName(cookId)) else tr("No host yet")
		Form.row !->
			Dom.style Box: 'middle'
			if cookId
				# Form.input
				# 	name: 'cost'
				# 	value: info.func('cost')
				# 	text: tr 'Total cost'
				# 	format: renderCurrency
				# 	onSave: (val) !->
				# 		val = parseFloat(val.replace(',','.'))
				# 		val = null if isNaN(val)
				# 		Server.sync 'cost', info.key(), val, !->
				# 			info.set 'cost', val
				# 	inScope: !->
				# 		Dom.style marginRight: '12px'
				result = "init"
				Obs.onClean !-> # when leaving page
					if result isnt "init" and result?
						Server.sync 'cost', info.key(), result, !->
							info.set 'cost', result

				Dom.div !->
					Dom.text "Total cost: €" # (Db.shared.get("currency")||"€")
					Dom.style
						margin: '-3px 5px 0 0'
						fontSize: '21px'
				inputField = undefined
				centField = undefined
				Dom.div !->
					Dom.style width: '80px', margin: '-20px 0 -20px 0'
					inputField = Form.input
						name: 'paidby'
						type: 'number'
						value: ->
							Math.floor(info.get('cost'))
						text: '0'
						style: {textAlign: 'right'}
						onChange: (v) !->
							if v and inputField and centField
								result = +('0'+inputField.value()+"."+centField.value())
				Dom.div !->
					Dom.style
						width: '10px'
						fontSize: '175%'
						padding: '12px 0 0 5px'
						margin: '-20px 0 -20px 0'
					Dom.text ","
				Dom.div !->
					Dom.style width: '60px', margin: '-20px 0 -20px 0'
					centField = Form.input
						name: 'paidby2'
						type: 'number'
						text: '00'
						value: ->
							Math.round((info.get('cost')%1)*100)
						onChange: (v) !->
							if v<0
								centField.value(0)
							if v and inputField and centField
								result = +('0'+inputField.value()+"."+centField.value())
				Dom.on 'keydown', (evt) !->
					if evt.getKeyCode() in [188,190] # comma and dot
						centField.focus()
						centField.select()
						evt.kill()
				,true
			else
				Ui.bigButton tr("I'll host!"), !->
					state = getState info,userId
					setState info, userId, -Math.abs(state||1)

	Dom.section !->
		Dom.style ChildMargin: 12

		count = Obs.create 0
		Form.label !->
			Dom.text tr("%1 Sober/Bored |person|people",count.get())

		# Create a temporary observable that is merely used for it's sorting ability
		tmpObs = null
		Obs.observe !->
			tmpObs = Obs.create Util.getInvolvedUserIds(info, getPluginUserIds())
		tmpObs.observeEach (dummy) !->
			userId2 = 0|dummy.key()
			Ui.item
				avatar: (App.userAvatar userId2)
				content: App.userName(userId2)
				afterIcon: !->
					log "right? ui"
					state = getState info, userId2
					stateIcon state
					plusIcon state
					delta = Math.abs(0|state)
					count.incr delta
					Obs.onClean !-> count.incr -delta
				onTap:
					cb: !-> nextState info, userId2
					longTap: !-> plusState info, userId2
		, (dummy) ->
			uid = dummy.key()
			v = info.peek('eat', uid)
			v %= 1000 if v? and v isnt ''
			[(if v then 0 else (if v is 0 then 2 else 1)), App.userName(uid)]

renderStat = (text,val) !->
	Dom.div !->
		Dom.div !->
			Dom.style fontSize: '22px'
			if typeof val=='function' then val() else Dom.text val
		Dom.style fontSize: '85%', textAlign: 'center'
		Dom.text text

renderFlex = !-> Dom.div !-> Dom.style Flex: 1

renderBalances = !->
	Comments.enable()
	stats = Obs.create()
	merge = (delta,minus) ->
		for k,v of delta
			k = k.split('/')
			k.push (stats.peek.apply(stats,k)||0) + (if minus then -v else v)
			stats.set.apply stats, k

	Db.shared.observeEach 'days', (info) !->
		delta = {}
		info = info.get()
		return unless info.eat and cook = info.cook
		eaters = 0
		eaters += +v%1000 for k,v of info.eat when v%1000
		return unless eaters>1
		if info.cost?
			for k,v of info.eat when v%1000
				delta["#{k}/eat"] = v%1000
				delta["#{k}/guests"] = (v-1)%1000
				delta["#{k}/consumed"] = info.cost*(v%1000)/eaters
			delta["#{cook}/cook"] = 1
			# delta["#{cook}/cookGuest"] = info.eat[cook]-1 if info.eat[cook]>1
			delta["#{cook}/fed"] = eaters
			delta["#{cook}/spent"] = info.cost
		else
			delta["#{cook}/noCost"] = 1
		merge delta
		Obs.onClean !-> merge delta, true

	Obs.observe !-> stats.observeEach (stat) !->
		Form.row !->
			Dom.style Flex: 1
			Dom.div !->
				Dom.style margin: '-8px -8px -6px', padding: '8px'
				Ui.avatar (App.userAvatar stat.key()),
					style: float: 'right'
					size: 32
				Dom.h2 App.userName(stat.key())

			Dom.div !->
				Dom.style Box: "middle"
				renderStat tr("balance"), !->
					balance = (stat.get('spent')||0) - (stat.get('consumed')||0)
					renderCurrency balance
					Dom.style color: if balance<0 then '#a00000' else '#00a000'
				renderFlex()
				renderStat tr("chef"), !->
					cook = stat.get('cook') || 0
					cmpEat = (stat.get('eat')||0)%1000 - (stat.get('guests')||0)
					perc = Math.round(100*cook/(cmpEat||cook))
					perc = (if isNaN(perc) then '-' else perc+'%')
					Dom.text perc
				renderFlex()
				renderStat tr("per meal"), !->
					renderCurrency (stat.get('spent')||0)/(stat.get('fed')||1)
				renderFlex()
				Dom.div !->
					Dom.style fontSize: '85%', textAlign: 'right'
					Dom.text tr("Chilled %1 time|s",stat.get("eat")||0)
					Dom.br()
					Dom.text tr("%1 420",stat.get("fed")||0)
					Dom.br()
					Dom.text tr("Hosted %1 time|s",stat.get("cook")||0)

			Dom.onTap !->
				Page.nav  {0:"personalBalance", "?id": stat.key()}

					#Dom.text JSON.stringify stat.get()
	, (stat) -> (stat.get('spent')||0)-(stat.get('consumed')||0)

renderPersonalBalance = (id) !->
	data = Obs.create()
	merge = (delta, minus, month) ->
		for k,v of delta
			k = k.split('/')
			if !data.peek(month)? then data.set(month, {})
			stats = data.ref month
			k.push (stats.peek.apply(stats,k)||0) + (if minus then -v else v)
			stats.set.apply stats, k

	Db.shared.observeEach 'days', (info) !->
		delta = {}
		day = info.key()
		info = info.get()
		return unless info.eat and cook = info.cook
		eaters = 0
		eaters += +v%1000 for k,v of info.eat when v%1000
		return unless eaters>1
		if info.cost?
			for k,v of info.eat when v%1000
				delta["#{k}/eat"] = v%1000
				delta["#{k}/consumed"] = info.cost*(v%1000)/eaters
			delta["#{cook}/cook"] = 1
			delta["#{cook}/cookGuest"] = info.eat[cook]-1 if info.eat[cook]>1
			delta["#{cook}/fed"] = eaters
			delta["#{cook}/spent"] = info.cost
		else
			delta["#{cook}/noCost"] = 1
		merge delta, false, Util.getUTCMonth(day)
		Obs.onClean !-> merge delta, true

	# for each month
	data.observeEach (d) !->
		Form.row !->
			Dom.style Flex: 1
			Dom.div !->
				Dom.style margin: '-8px -8px -6px', padding: '8px'
				Ui.avatar (App.userAvatar id),
					style: float: 'right'
					size: 32
				Dom.h2 fullMonthNames[d.key()]

			Dom.div !->
				Dom.style Box: "middle"
				if m = d.get(id)
					renderStat tr("balance"), !->
						balance = (m.spent||0) - (m.consumed||0)
						renderCurrency balance
						Dom.style color: if balance<0 then '#a00000' else '#00a000'
					renderFlex()
					renderStat tr("chef"), !->
						cook = m.cook || 0
						cmpEat = (m.eat||0)%1000 - (m.cookGuest||0)
						perc = Math.round(100*cook/(cmpEat||cook))
						perc = (if isNaN(perc) then '-' else perc+'%')
						Dom.text perc
					renderFlex()
					renderStat tr("per meal"), !->
						renderCurrency (m.spent||0)/(m.fed||1)
					renderFlex()
					Dom.div !->
						Dom.style fontSize: '85%', textAlign: 'right'
						Dom.text tr("Chilled %1 time|s",m.eat||0)
						Dom.br()
						Dom.text tr(" %1 420(2)",m.fed||0)
						Dom.br()
						Dom.text tr("Hosted %1 time|s",m.cook||0)
				else
					Dom.text tr("Did not join le chillings this month")
	, (d) ->
		-d.key()
	#render settle, times cooked, platessorved, meals eaten.

exports.render = !->
	what = Page.state.get(0)
	if +what
		renderDayPage +what # day nr
		return

	if what=='balances'
		Page.setTitle tr("Balances")
		renderBalances()
		return

	if what=='personalBalance'
		id = Page.state.get("?id")
		Page.setTitle tr("Balances of %1", App.userName(id))
		renderPersonalBalance(id)
		return

	if what=='history'
		Page.setTitle tr("History")

		eatersCnt = (eat) ->
			cnt = 0
			for k,v of eat
				v %= 1000 if v isnt ''
				cnt += +v
			cnt

		items = Obs.create()
		# show last week, plus earlier days that have a cook
		Obs.observe !->
			for day in [today-1..today-7] by -1
				renderDayItem day
			Db.shared.dirty().observeEach 'days', (info) !->
				day = 0|info.key()
				if day<today-7 and (info.get('cook') or eatersCnt(info.get('eat'))>0)
					renderDayItem info
					items.set true
			, (day) -> -day.key()
			Obs.observe !->
				Ui.emptyText tr("No earlier items") unless items.get()
		return

	if title = App.title()
		Dom.h2 !->
			Dom.style margin: '6px 2px'
			Dom.text title

	# Ui.list !->
	Obs.observe !->
		Db.personal.observeEach 'open', (info) !->
			day = 0|info.key()
			if day < (today-1)
				renderDayItem info
		, (day) -> 0|day.key()

		for day in [today-1...today+14] by 1
			renderDayItem day

	Page.setFooter
		label: tr "Balances"
		action: !-> Page.nav ['balances']
	,
		label: tr "History"
		action: !-> Page.nav ['history']

exports.renderSettings = !->
	Dom.div !->
		Dom.style Box: "middle center"
		Dom.div !->
			Dom.text tr("Daily deadline: ")
		require('datepicker.js').time
			name: 'deadline'
			gmt: true
			value: Db.shared?.get('deadline') || 16.5*3600

	Dom.h2 tr "Default statuses"

	defaults = Obs.create(Db.shared?.get('defaults'))
	expanded = Obs.create()

	e = Form.hidden 'defaults', JSON.stringify(Db.shared?.get('defaults'))
	Obs.observe !->
		e.value JSON.stringify(defaults.get())

	# TODO: allow manual removal of users that have left the happening but still have a default status
	userIds = {}
	userIds[u] = true for u of Db.shared?.get('defaults')
	userIds[i] = true for i in getPluginUserIds()
	for userId2, v of userIds then do (userId2) !->
		Form.row !->
			Dom.style paddingRight: '0px'
			Dom.div !->
				Dom.style Box: "middle"
				Ui.avatar (App.userAvatar userId2)
				Dom.div !->
					Dom.style Flex: true, marginLeft: '8px'
					Dom.text App.userName(userId2)
				Dom.div !->
					Dom.style color: '#aaa', margin: '0 13px', border: '8px solid transparent'
					if expanded.get(userId2)
						Dom.style borderBottom: '8px solid #ccc', marginTop: '-8px'
					else
						Dom.style borderTop: '8px solid #ccc', marginBottom: '-8px'

				Dom.onTap !->
					expanded.modify(userId2, (v) -> if v then null else true)

			Dom.div !->
				Dom.style display: if expanded.get(userId2) then 'block' else 'none'
				for dayName, index in dayNames then do (dayName, index) !->
					Dom.div !->
						Dom.style Box: 'middle right', padding: '10px 0'
						Dom.div dayName
						state = defaults.get(userId2, index, 'eat')
						Dom.div !->
							Dom.style Box: 'middle center', minWidth: '45px'
							stateIcon state
							plusIcon state

						Dom.onTap
							cb: !->
								defaults.modify userId2, index, 'eat', (state) ->
									if !state? then 1 else if state>0 then 0 else null
							longTap: !->
								buttons = ['0', tr("No")]
								buttons.push i, i for i in [1..4]
								chosen = (val) !->
									if val?
										defaults.modify userId2, index, 'eat', (state) -> val+1
								require('modal').show tr('Bringing guests?'), null, chosen, buttons
