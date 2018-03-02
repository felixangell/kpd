#!/bin/sh

for file in tests/*.krug; do
	./krug $file -v -c
done