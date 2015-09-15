Dom = require 'dom'
Form = require 'form'
Obs = require 'obs'
Page = require 'page'
Plugin = require 'plugin'
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

exports.date = date = (opts) ->
	opts = {} if typeof opts!='object'
	if opts.onSave
		return Form.editInModal(opts,date)
	[handleChange,orgValue] = Form.makeInput opts
		
	date = new Date()
	today =
		y: date.getFullYear()
		m: 1+date.getMonth()
		d: date.getDate()

	if orgValue
		date = new Date(orgValue*864e5)
		cur =
			y: date.getUTCFullYear()
			m: 1+date.getUTCMonth()
			d: date.getUTCDate()
	else
		cur =
			y: today.y
			m: today.m
	year = Obs.create cur.y
	month = Obs.create cur.m
	cur = Obs.create cur

	arr = (label,cb) !->
		Dom.div !->
			Dom.style
				backgroundColor: Colors.highlight
				color: Colors.highlightText
				fontSize: '30px'
				lineHeight: '20px'
				padding: '4px'
				textAlign: 'center'
				_borderRadius: '3px'
			Dom.text label
			Dom.onTap cb

	Dom.div !->
		Dom.style maxWidth: '350px'
		Dom.div !->
			Dom.style Box: "middle center"
			arr '⇐', !->
				m = month.peek()-1
				if m<1
					m = 12
					year.set year.peek()-1
				month.set m
			Dom.div !->
				Dom.style textAlign: 'center', fontWeight: 'bold', color: Colors.highlight, padding: '0 15px'
				Dom.text monthNames[month.get()-1]+' '+year.get()
			arr '⇒', !->
				m = month.peek()+1
				if m>12
					m = 1
					year.set year.peek()+1
				month.set m
		Dom.table !->
			Dom.style textAlign: 'center', width: '100%'
			Dom.tr !->
				for dn in dayNames
					Dom.th dn

			showDay = (day) !->
				Dom.td !->
					return unless day
					Dom.text day
					current = cur.get('d')==day and cur.get('m')==month.peek() and cur.get('y')==year.peek()
					Dom.style
						backgroundColor: if current then Colors.highlight else 'inherit'
						color: if current then Colors.highlightText else 'inherit'
					if today.d==day and today.m==month.peek() and today.y==year.peek()
						Dom.style
							fontWeight: 'bold'
					Dom.onTap !->
						newCur =
							y: year.peek()
							m: month.peek()
							d: day
						d = new Date(newCur.y, newCur.m-1, newCur.d)
						cur.set newCur
						log 0|(d.getTime()/864e5), cur
						handleChange 0|(d.getTime()/864e5)

			skipDays = (new Date(year.get(), month.get()-1, 1)).getDay()
			log 'skipDays', skipDays, year.get(), month.get()-1
			lastDate = (new Date(year.get(), month.get()-1, 0)).getDate()
			curDay = 0
			while curDay<lastDate
				Dom.tr !->
					for i in [0...7]
						if skipDays
							skipDays--
							showDay()
						else if curDay<lastDate
							showDay ++curDay
						else
							showDay()


# The time input is kind of special, as it doesn't have a no-state value. So if the value wasn't set, a change is triggered immediately.
exports.time = time = (opts) ->
	opts = {} if typeof opts!='object'
	if opts.onSave
		return Form.editInModal(opts,time)

	sanitize = opts.normalize = (v) ->
		if v<0
			v + 24*60*60
		else
			v % (24*60*60)

	[handleChange,orgValue] = Form.makeInput opts

	offset = 0
	if opts.gmt and orgValue?
		offset = (new Date).getTimezoneOffset() * 60
		orgValue -= offset

	if orgValue?
		orgValue = 0|(sanitize(orgValue)/60)
		hours = 0|(orgValue/60)
		minutes = orgValue%60
	else
		hours = 15
		minutes = 0
	hours = Obs.create hours
	minutes = Obs.create minutes
	Obs.observe !->
		handleChange sanitize(hours.get()*60*60 + minutes.get()*60 + offset)

	renderArrow = (obsVal, dir, max) !->
		Dom.div !->
			Dom.style
				width: 0
				height: 0
				borderStyle: "solid"
				borderWidth: "#{if dir>0 then 0 else 20}px 20px #{if dir>0 then 20 else 0}px 20px"
				borderColor: "#{if dir>0 then 'transparent' else Colors.highlight} transparent #{if dir>0 then Colors.highlight else Colors.highlight} transparent"
			Dom.onTap !->
				nv = Math.round(((obsVal.peek()+dir) % max)/dir)*dir
				nv=max-1 if nv<0
				obsVal.set nv

	renderInput = (obsVal,max,step) !->
		Dom.div !->
			Dom.style Box: "vertical center"
			renderArrow obsVal, step, max
			Dom.input !->
				inputE = Dom.get()
				val = ''+obsVal.get()
				val = '0'+val if val.length<2
				Dom.prop
					size: 2
					value: val
				Dom.style
					fontFamily: 'monospace'
					fontSize: '30px'
					fontWeight: 'bold'
					textAlign: 'center'
					border: 'inherit'
					backgroundColor: 'inherit'
					color: 'inherit'
				Dom.on 'change', !->
					obsVal.set(inputE.value()%max)
				Dom.on 'click', !-> inputE.select()
			renderArrow obsVal, -step, max
	Dom.div !->
		Dom.style Box: "middle"
		renderInput hours, 24, 1
		Dom.div !->
			Dom.style
				fontFamily: 'monospace'
				fontSize: '30px'
				fontWeight: 'bold'
				padding: '0 4px'
			Dom.text ':'
		renderInput minutes, 60, opts.minuteStep||5
		

exports.datetime
