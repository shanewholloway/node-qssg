all: build test

build: 
	./node_modules/.bin/coffee -bc ./qssg

test:
	@echo "TODO: create tests\n"

clean:
	rm ./qssg/*.js

