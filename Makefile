all: build test

build: 
	./node_modules/.bin/coffee --map -bc ./qssg

test:
	@echo "TODO: create tests\n"

clean:
	rm ./qssg/*.js ./qssg/*.map

