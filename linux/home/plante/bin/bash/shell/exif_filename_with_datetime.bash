#!/bin/bash
#exiftool "-FileName<FileModifyDate" -d "%Y%m%d_%H%M%S.%%e" . # works but wipes out existing filename
exiftool "-FileName<FileModifyDate" -d "%Y%m%d_%H%M%S_%%f.%%e" . # works! (retains original filename after formatted FileModifyDate)
