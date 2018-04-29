#!/bin/sh

for file in tests/x64_tests/*.krug; do
	krug b $file
done
