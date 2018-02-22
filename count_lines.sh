#!/bin/bash
git ls-files | grep -E "(\.d)|(\.c)|(\.h)" | xargs cat | wc -l