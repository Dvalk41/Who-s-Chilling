Db = require 'db'
Dom = require 'dom'
Obs = require 'obs'
Server = require 'server'
Form = require 'form'
Page = require 'page'
Plugin = require 'plugin'
Ui = require 'ui'
Colors = Plugin.colors()
{tr} = require 'i18n'


dayNames = [
	tr 'Sun'
	tr 'Mon'
	tr 'Tue'
	tr 'Wed'
	tr 'Thu'
	tr 'Fri'
	tr 'Sat'
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
	Util = require 'util.js'
	Dom.text Util.formatCurrency val

getDayName = (day) ->
	date = new Date(day*86400000)
	dayNames[date.getUTCDay()] + ' ' + date.getUTCDate() + ' ' + monthNames[date.getUTCMonth()]

getState = (info,userId) ->
	cookId = info.get('cook')
	state = info.get('eat',userId)
	if cookId==userId then -state else state

stateIcon = (state) !->
	icon = if !state? then 'unknown' else if state>0 then 'yes' else if state<0 then 'cook' else 'no'
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
		Dom.text " +"+(Math.abs(state)-1)

setState = (info,userId,newState) !->
	Server.sync 'eat', info.key(), newState, userId, !->
		cookId = info.get('cook')
		info.set 'cook', if newState<0 then (if cookId then cookId else userId) else (if cookId==userId then null else cookId)
		info.set 'eat', userId, if newState<0 then -newState else newState

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
	state = -state if cookId==userId
	setState info, userId, if !state? then (if cookId then 1 else -1) else if state<0 then -state else if state>0 then 0 else null

plusState = (info,userId) ->
	return unless editOther(plusState,info,userId)
	buttons = []
	for i in [0..4]
		buttons.push i, '+'+i
	chosen = (val) !->
		if val?
			state = getState info, userId
			setState info, userId, if state<0 then -val-1 else val+1
	require('modal').show tr('Bringing guests?'), null, chosen, buttons

iconDiv = (func) !->
	Dom.div !->
		Dom.style
			padding: '6px 2px 6px 8px'
			minWidth: '32px'
			minHeight: '24px'
			lineHeight: '24px'
			textAlign: 'center'
		func?()

offset = (new Date).getTimezoneOffset()
today = 0|((Plugin.time()-offset*60000)/86400)

renderDayItem = (day) !->
	if typeof day=='object'
		info = day
		day = 0|info.key()
	else
		info = Db.shared.ref('days', day) || new Obs.Value()

	userId = Plugin.userId()

	Dom.section !->

		Dom.style
			Box: "middle"

		cookId = info.get('cook')
		Ui.avatar (Plugin.userAvatar cookId if cookId)

		Dom.div !->
			Dom.style
				Flex: 1
				fontWeight: (if day==today then 'bold' else 'normal')
			Dom.text getDayName(day)

			Dom.div !->
				cnt = 0
				for k,v of info.get('eat')
					cnt += v
					
				Dom.style
					fontStyle: 'italic'
					fontSize: '80%'
					fontWeight: 'normal'
					color: if cnt or cookId then 'inherit' else '#aaa'
				Dom.text if cookId then tr("diner à la %1 for %2",Plugin.userName(cookId),cnt) else tr("%1 hungry |person|people",cnt)

		Form.vSep()

		iconDiv !->
			state = getState info, userId
			stateIcon state
			plusIcon state
			Dom.onTap
				cb: !-> nextState info, userId
				longTap: !-> plusState info, userId
			
		Dom.onTap !->
			Page.nav ['day',day]


renderDayPage = (day) !->
	Page.setTitle getDayName(day)

	info = Db.shared.ref('days', day) || new Obs.Value()
	userId = Plugin.userId()
		
	Dom.section !->
		Dom.div !->
			Dom.style Box: "middle", padding: '8px'
			Dom.div !->
				Dom.style Flex: true
				Dom.text tr "Your response"
				Dom.div !->
					Dom.style
						fontSize: '75%'
						lineHeight: '1.2em'
					state = getState(info, userId)
					Dom.text if state<0
							tr "Yes, and I'm cooking"
						else if state>0
							tr "Yes, please"
						else if state==0
							tr "No, thanks"
						else
							tr "Undecided"

			iconDiv !->
				stateIcon getState(info, userId)
			Dom.onTap !-> nextState info, userId
	
		Form.sep()
		
		Dom.div !->
			Dom.style Box: "middle", padding: '8px'
			Dom.div !->
				Dom.style Flex: true
				Dom.text tr "Bringing guests?"
			iconDiv !->
				plusIcon getState(info, userId)
			Dom.onTap !-> plusState info, userId

		Dom.div !->
	
	Dom.section !->
		cookId = info.get('cook')
		Dom.h2 if cookId then tr("Chef %1", Plugin.userName(cookId)) else tr("No chef yet")
		Dom.div !->
			Dom.style
				Box: "middle center"
			if cookId
				Ui.avatar Plugin.userAvatar(cookId)
				Dom.div !-> Dom.style width: '8px'
				Dom.div !->
					Dom.style Flex: 1
					Form.input
						name: 'cost'
						value: info.func('cost')
						text: tr 'total cost'
						format: renderCurrency
						onSave: (val) !->
							val = parseFloat(val.replace(',','.'))
							val = null if isNaN(val)
							Server.sync 'cost', info.key(), val, !->
								info.set 'cost', val
			else
				Ui.bigButton tr("I'll cook!"), !->
					state = getState info,userId
					setState info, userId, -Math.abs(state||1)

	Dom.section !->
		count = Obs.create 0
		Dom.h2 !->
			Dom.text tr("%1 hungry |person|people",count.get())

		Plugin.users.observeEach (user) !->
			userId2 = 0|user.key()
			Dom.div !->
				Dom.style Box: "middle", padding: '8px'
				Ui.avatar (Plugin.userAvatar userId2)
				Dom.div !-> Dom.style width: '8px'
				Dom.div !->
					Dom.style Flex: true
					Dom.text user.get('name')
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
		, (user) ->
			[(if info.peek('eat',user.key()) then 0 else 1), user.peek('name')]

	Dom.section !->
		Dom.h2 tr 'Comments'
		require('social').renderComments day, render: (comment) !->
			if comment.s and comment.u
				comment.c = Plugin.userName(comment.u) + ": "+ comment.c
				delete comment.u

renderBalances = !->
	stats = Obs.create()
	merge = (delta,minus) ->
		for k,v of delta
			k = k.split('/')
			k.push (stats.get.apply(stats,k)||0) + (if minus then -v else v)
			stats.set.apply stats, k

	Db.shared.observeEach 'days', (info) !->
		delta = {}
		info = info.get()
		return unless info.eat and cook = info.cook
		eaters = 0
		eaters += v for k,v of info.eat
		return unless eaters>1
		if info.cost?
			for k,v of info.eat when v
				delta["#{k}/eat"] = v
				delta["#{k}/consumed"] = info.cost*v/eaters
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

			Ui.avatar (Plugin.userAvatar stat.key())

			Dom.div !-> Dom.style width: '8px'

			Dom.div !->
				Dom.style Flex: 1
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
						cmpEat = (stat.get('eat')||0) - (stat.get('cookGuest')||0)
						Dom.text Math.round(100*cook/(cmpEat||cook)) + '%'
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
	if what=='day'
		renderDayPage Page.state.get(1)
		return

	if what=='balances'
		renderBalances()
		return

	if what=='history'
		items = Obs.create()
		# show last week, plus earlier days that have a cook
		for day in [today-1..today-7] by -1
			renderDayItem day
		Db.shared.dirty().observeEach 'days', (info) !->
			day = 0|info.key()
			if day<today-7 and info.get('cook')
				renderDayItem info
				items.set true
		, (day) -> -day.key()
		Obs.observe !->
			Ui.emptyText tr("No earlier items") unless items.get()
		return

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
		Dom.style Box: "inline middle"
		Dom.div !->
			Dom.text tr("Daily deadline: ")
		require('datepicker.js').time
			name: 'deadline'
			gmt: true
			value: Db.shared.get('deadline')
	
