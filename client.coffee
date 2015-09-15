Util = require 'util.js'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Obs = require 'obs'
Server = require 'server'
Time = require 'time'
Form = require 'form'
Page = require 'page'
Plugin = require 'plugin'
Social = require 'social'
Ui = require 'ui'
Colors = Plugin.colors()
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
	+uid for uid of Plugin.users.get()

stateIcon = (state) !->
	icon = if !state? or state is '' then 'unknown' else if state>0 then 'yes' else if state<0 then 'cook' else 'no'
	Dom.img !->
		Dom.prop src: Plugin.resourceUri("eat-#{icon}.png")
		Dom.style
			maxWidth: '32px'
			maxHeight: '24px'
			width: 'auto'
			verticalAlign: 'middle'

plusIcon = (state) !->
	if (state>1 or state<-1)
		Dom.style
			fontWeight: 'bold'
			color: Plugin.colors().highlight
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
	return true if Plugin.userId()==userId || editingOthers[userId]
	require('modal').confirm tr("Are you sure you want to make this update on behalf of %1?",Plugin.userName(userId)), !->
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
today = 0|((Plugin.time()-offset*60)/86400)
log 'today', today

renderDayItem = (day) !->
	if typeof day=='object'
		info = day
		day = 0|info.key()
	else
		info = Db.shared.ref('days', day) || new Obs.Value(null,day)

	userId = Plugin.userId()

	Ui.item !->
		Dom.style
			Box: "middle"
			padding: 0

		Dom.div !->
			Dom.style Box: 'middle', Flex: 1, padding: '8px'
			cookId = info.get('cook')
			if cookId
				Ui.avatar (Plugin.userAvatar cookId)
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
					Dom.text if cookId then tr("%1 cooking for %2",Plugin.userName(cookId),cnt) else tr("%1 hungry |person|people",cnt)

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
	Event.showStar tr("this day")

	info = Db.shared.ref('days', day) || new Obs.Value(null,day)
	userId = Plugin.userId()
		
	Dom.style padding: 0 # style the main element
	Dom.div !->
		Dom.style backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc', paddingBottom: '8px'

		Form.box !->
			Dom.text tr "Your status"
			Dom.div !->
				state = getState(info, userId)
				Dom.text if state<0
						tr "Hungry, and I'm cooking"
					else if state>0
						tr "Hungry"
					else if state is 0
						tr "Not joining dinner"
					else
						tr "Undecided"

			iconDiv !->
				Dom.style position: 'absolute', right: '8px', top: '5px'
				stateIcon getState(info, userId)
			Dom.onTap !-> nextState info, userId

		Form.sep()

		Form.box !->
			#Dom.style Box: "middle", padding: '0 8px'
			Dom.text tr "Your guests"
			state = getState(info, userId)
			Dom.div !->
				#Dom.style Flex: true
				#Dom.text tr "Bringing guests?"
				if state<-1 or state>1
					Dom.text tr "Bringing %1 guest|s", (Math.abs(state)-1)
				else
					Dom.text tr "Not bringing guests"
			iconDiv !->
				Dom.style position: 'absolute', right: '8px', top: '5px'
				plusIcon state
			Dom.onTap !-> plusState info, userId

		Form.sep()

		Obs.observe !->
			cookId = info.get('cook')
			Form.label !->
				Dom.style marginTop: '20px'
				Dom.text if cookId then tr("Chef %1", Plugin.userName(cookId)) else tr("No chef yet")
			Dom.div !->
				Dom.style margin: '4px 8px 12px 8px', minHeight: '44px'
				if cookId
					Form.input
						name: 'cost'
						value: info.func('cost')
						text: tr 'Total cost'
						format: renderCurrency
						onSave: (val) !->
							val = parseFloat(val.replace(',','.'))
							val = null if isNaN(val)
							Server.sync 'cost', info.key(), val, !->
								info.set 'cost', val
						inScope: !->
							Dom.style marginRight: '12px'
				else
					Ui.bigButton tr("I'll cook!"), !->
						state = getState info,userId
						setState info, userId, -Math.abs(state||1)

		count = Obs.create 0
		Form.label !->
			Dom.text tr("%1 hungry |person|people",count.get())

		# Create a temporary observable that is merely used for it's sorting ability
		tmpObs = null
		Obs.observe !->
			tmpObs = Obs.create Util.getInvolvedUserIds(info, getPluginUserIds())
		tmpObs.observeEach (dummy) !->
			userId2 = 0|dummy.key()
			Dom.div !->
				Dom.style Box: "middle", padding: '0 8px'
				Ui.avatar (Plugin.userAvatar userId2)
				Dom.div !->
					Dom.style Flex: true, marginLeft: '8px'
					Dom.text Plugin.userName(userId2)
				iconDiv !->
					state = getState info, userId2
					stateIcon state
					plusIcon state
					delta = Math.abs(0|state)
					count.incr delta
					Obs.onClean !-> count.incr -delta
				Dom.onTap
					cb: !-> nextState info, userId2
					longTap: !-> plusState info, userId2
			Form.sep()
		, (dummy) ->
			uid = dummy.key()
			v = info.peek('eat', uid)
			v %= 1000 if v? and v isnt ''
			[(if v then 0 else (if v is 0 then 2 else 1)), Plugin.userName(uid)]

	Social.renderComments day, render: (comment) ->
		if comment.s and comment.u
			comment.c = Plugin.userName(comment.u) + ' ' + comment.c
			delete comment.u
			Dom.div !->
				Dom.style margin: '6px 0 6px 56px', fontSize: '70%'

				Dom.span !->
					Dom.style color: '#999'
					#Dom.text Plugin.userName(comment.u) + " • "
					Time.deltaText comment.t
					Dom.text " • "

				Dom.text comment.c
			true # We're rendering these type of comments

renderBalances = !->
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
				delta["#{k}/consumed"] = info.cost*(v%1000)/eaters
			delta["#{cook}/cook"] = 1
			delta["#{cook}/cookGuest"] = info.eat[cook]-1 if info.eat[cook]>1
			delta["#{cook}/fed"] = eaters
			delta["#{cook}/spent"] = info.cost
		else
			delta["#{cook}/noCost"] = 1
		merge delta
		Obs.onClean !-> merge delta, true

	renderStat = (text,val) !->
		Dom.div !->
			Dom.div !->
				Dom.style fontSize: '22px'
				if typeof val=='function' then val() else Dom.text val
			Dom.style fontSize: '85%', textAlign: 'center'
			Dom.text text

	renderFlex = !-> Dom.div !-> Dom.style Flex: 1

	Obs.observe !-> stats.observeEach (stat) !->
		Dom.section !->
			Dom.style Box: "middle"

			Dom.div !->
				Dom.style Flex: 1
				Dom.div !->
					Dom.style margin: '-8px -8px -6px', background: '#fff', padding: '8px'
					Ui.avatar (Plugin.userAvatar stat.key()),
						style: float: 'right'
						size: 32
					Dom.h2 Plugin.userName(stat.key())

				Dom.div !->
					Dom.style Box: "middle"
					renderStat tr("balance"), !->
						balance = (stat.get('spent')||0) - (stat.get('consumed')||0)
						renderCurrency balance
						Dom.style color: if balance<0 then '#a00000' else '#00a000'
					renderFlex()
					renderStat tr("chef"), !->
						cook = stat.get('cook') || 0
						cmpEat = (stat.get('eat')||0)%1000 - (stat.get('cookGuest')||0)
						perc = Math.round(100*cook/(cmpEat||cook))
						perc = (if isNaN(perc) then '-' else perc+'%')
						Dom.text perc
					renderFlex()
					renderStat tr("per meal"), !->
						renderCurrency (stat.get('spent')||0)/(stat.get('fed')||1)
					renderFlex()
					Dom.div !->
						Dom.style fontSize: '85%', textAlign: 'right'
						Dom.text tr("ate %1 time|s",stat.get("eat")||0)
						Dom.br()
						Dom.text tr("served %1 plate|s",stat.get("fed")||0)
						Dom.br()
						Dom.text tr("cooked %1 time|s",stat.get("cook")||0)

					#Dom.text JSON.stringify stat.get()
	, (stat) -> (stat.get('spent')||0)-(stat.get('consumed')||0)


exports.render = !->
	what = Page.state.get(0)
	if +what
		renderDayPage +what # day nr
		return

	if what=='balances'
		Page.setTitle tr("Balances")
		renderBalances()
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
		Ui.list !->
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

	if title = Plugin.title()
		Dom.h2 !->
			Dom.style margin: '6px 2px'
			Dom.text title

	Ui.list !->
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


exports.renderConfig = exports.renderSettings = !->
	Dom.div !->
		Dom.style Box: "inline middle", margin: '6px 0 10px'
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
		Dom.div !->
			Dom.style Box: "middle", padding: '8px'
			Ui.avatar (Plugin.userAvatar userId2)
			Dom.div !->
				Dom.style Flex: true, marginLeft: '8px'
				Dom.text Plugin.userName(userId2)
			Dom.div !->
				Dom.style color: '#aaa', margin: '0 5px', border: '8px solid transparent'
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
						Dom.style Box: 'middle center', minWidth: '60px'
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

		Form.sep()
