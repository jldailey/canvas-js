
# abort is a sentinel
abort = ->

mixin = (fields) ->
	(args...) ->
		obj = args.pop()
		fields.init?.apply obj, args
		for f,v of fields
			do (f,v) -> # get a new scope for each iteration
				if $.is 'function', v
					p = obj[f] ? ->
					obj[f] = (b...) ->
						if (i = v.apply @, b) isnt abort
							j = p?.apply @, b
						return i ? j
		obj

position = mixin
	init: (x=0,y=0) ->
		@x ?= x
		@y ?= y

area = mixin
	init: (w=30,h=30) ->
		@w ?= w
		@h ?= h

bounded = mixin
	init: (@boundx=320,@boundy=240,@bounce=1) ->
		if @constructor.name is "Array"
			for i in [0...@length]
				@[i] = bounded @boundx,@boundy,@[i]
	tick: (dt) ->
		if @boundy < @y or @y < 0 then @vy *= -@bounce
		if @boundx < @x or @x < 0 then @vx *= -@bounce

velocity = mixin
	init: (@vx=0,@vy=0)->
	tick: (dt) ->
		@x += (@vx * dt)
		@y += (@vy * dt)
	draw: (ctx) ->
		return
		ctx.zap('strokeStyle', 'rgba(0,0,255,0.5)')
		ctx.select('drawLine').call @x,@y,@x+@vx,@y+@vy

drag = mixin
	init: (@dragx=0.0,@dragy=0.0) ->
	tick: (dt) ->
		@vx *= (1.0 - @dragx * dt)
		@vy *= (1.0 - @dragy * dt)

circle = mixin
	init: (@r=30) ->
	draw: (ctx) -> ctx.select('drawCircle').call(@x,@y,@r)
	clipPoint: (p) ->	$([p[0]-@x,p[1]-@y]).normalize().scale(@r).weave([@x,@y]).fold((a,b)->a+b)
	doesClip: (p) -> $([p[0]-@x,p[1]-@y]).magnitude() < @r

fill = mixin
	init: (@fillStyle="#000") ->
	draw: (ctx) -> ctx.zap('fillStyle',@fillStyle)

group = mixin
	draw: (ctx) -> x.draw?(ctx) for x in @
	tick: (dt) -> x.tick?(dt) for x in @
	clip: (x,y) -> (x.clip?(dt) for x in @).reduce (a,x) -> a or x

box_clipPoint = (p,tx,ty,tw,th) ->
	minda = 9999
	min = null
	for a in [ [tx,ty-th/2], [tx+tw/2,ty-th], [tx+tw,ty-th/2], [tx+tw/2,ty] ]
		da = $(p).weave(a).fold((i,j)->i-j).magnitude()
		if da < minda
			min = a
			minda = da
	return min

box_doesClip = (p,tx,ty,tw,th) -> return (tx <= p[0] <= tx+tw) and (ty <= p[1] <= ty+th)

text = mixin
	init: (@text="Hello") ->
		@w = 0
		@h = 16
	draw: (ctx) ->
		ctx.select('fillText').call(@text, @x, @y)
		@w = ctx.select('measureText').call(@text).select('width').first()
		
labels = {
	"hello": "Hello World"
	"fps": "FPS: 0"
}
label = mixin
	init: (@label="hello") ->
	draw: (ctx) ->
		ctx.select('fillText').call(labels[@label], @x, @y)

font = mixin
	init: (@font="1em sans normal") ->
	draw: (ctx) -> ctx.zap('font', @font)

border = mixin
	draw: (ctx) ->
		ctx.select('beginPath').call()
		ctx.select('rect').call(@x,@y,@w,@h)
		ctx.select('stroke').call()
		ctx.select('closePath').call()

mass = mixin
	init: (@mass=0) ->

accel = mixin
	init: (ax=0,ay=0) ->
		@acc or= []
		@acc.push [ax,ay]
	tick: (dt) ->
		for v in @acc
			@vx += v[0] * dt
			@vy += v[1] * dt

force = mixin
	init: (dx=0,dy=0) ->
		@vx += dx
		@vy += dy

bodies = []
collide = mixin
	init: ->
		bodies.push @
		@showCollideNotice = 0
	tick: (dt) ->
		if @showCollideNotice > 0
			@showCollideNotice -= dt
		dvx = dvy = 0
		for body in bodies
			if body is this then continue
			cpa = @clipPoint? [body.x, body.y]
			cpb = body.clipPoint? [@x,@y]
			if body.doesClip?(cpa) or @doesClip?(cpb)
				@showCollideNotice = .100
				@vx += dvx
				@vy += dvx
	clipPoint: (p) -> [0,0]
	doesClip: (p) -> false
	draw: (ctx) ->
		for body in bodies
			if body is this then continue
			b = [body.x,body.y]
			cpa = @clipPoint?(b)
			if cpa?
				ctx.zap('fillStyle', 'yellow').select('drawCircle').call(cpa[0],cpa[1],2)
			else
				ctx.zap('fillStyle', 'purple').select('drawCircle').call(@x+5,@y+5,5)
		if @showCollideNotice > 0
			ctx.zap('fillStyle', 'pink').select('drawCircle').call(@x+5,@y-5,5)

gravity = (o) -> accel 0,9, o
physical = (o) -> collide gravity velocity 0,0, drag 0.1,0.1, o

class Scene
	constructor: (selector, items, @fps=60) ->
		@scene = items
		@ctx = $(selector).bind("mousemove", (evt) ->
			rect = $(this).rect().first()
			x = evt.pageX - rect.left
			y = evt.pageY - rect.top
			labels["xy"] = "X: #{x} Y: #{y}"
		).select("getContext").call("2d").map -> $.extend @,
			drawCircle: (x,y,r) ->
				@beginPath()
				@arc(x,y,r,0,2*Math.PI)
				@fill()
				@stroke()
				@closePath()
			drawLine: (x1,y1,x2,y2) ->
				@beginPath()
				@moveTo x1,y1
				@lineTo x2,y2
				@stroke()
				@closePath()
		@last = +new Date
	tick: (dt) ->
		@ctx.select('clearRect').call 0,0, @scene.boundx ? 320, @scene.boundy ? 240
		labels["fps"] = "FPS: #{(1/dt).toFixed(2)}"
		@scene.tick(dt)
		@scene.draw(@ctx)
	resume: ->
		@last = +new Date / 1000
		@intervalId = setInterval (=>
			now = +new Date / 1000
			@last += (dt = now - @last)
			@tick(dt)
		), Math.floor(1000/@fps)
	pause: ->
		clearInterval @intervalId


$(document).ready ->
	window.scene = new Scene "canvas", bounded 320,240, area 320,240, position 0,0, border group [
		(fill "#f00", circle 20, position 60,60, physical {})
		(fill "#ffc", circle 20, position 90,60, velocity -5,30, physical {})
		(fill "#000", circle 20, position 120,60, velocity -50,10, physical {})
		(fill "#000", font "20px bold", text "Hello", position 40,40, {})
		(fill "#00f", font "10px sans", label "fps", position 0,10, {})
		(fill "#00f", font "10px sans", label "xy", position 0,22, {})
	]
	scene.resume()
	$("canvas").click -> scene.scene.forEach (x) -> force( $.random.integer(-10,10), -30, x )

	setTimeout (-> scene.pause()), 5000
	$("button.start").click -> scene.resume()
	$("button.stop").click -> scene.pause()
