#!/bin/bash
exiftool "-CreateDate<FileName" "-DateTimeOriginal<FileName" "-ModifyDate<FileName" "$1" # doesn't work
