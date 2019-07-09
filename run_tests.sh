#!/bin/sh

for file in tests/x64_tests/*.krug; do
	./bin/krug b $file
done
