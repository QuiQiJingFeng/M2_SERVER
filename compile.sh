#!/bin/bash

LUAC=./3rd/lua/luac
mkdir -p bin

Luas=`find . -name "*.lua"`
for file in $Luas
do
    filename=./bin/${file#*/}
    dirpath=${file%/*}"/"
    dirpath=bin/${dirpath#*/}

	if [ ! -d "$dirpath" ];then
		mkdir -p $dirpath
	fi
    $LUAC -o $filename $file
done