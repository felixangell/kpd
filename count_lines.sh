#!/bin/bash
git ls-files | grep -E "\.d" | xargs cat | wc -l