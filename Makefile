COFFEE=node_modules/.bin/coffee

all: canvas.js

canvas.js: $(COFFEE) canvas.coffee
	@$(COFFEE) -c canvas.coffee

$(COFFEE):
	npm install coffee-script

