# Script  :  JoboCopy.py
# Version :  1.0
# Date    :  7/5/22
# Author: Jody Ingram
# Pre-reqs: PSExec.exe
# Notes: This Python script uses a subprocess to call in RoboCopy and runs it across multiple servers. It breaks down a large RoboCopy network transfer across multiple server's threads.

from subprocess import call
call(["robocopy", "basefolder JoboCopy /S /LOG:JoboLogFileName"])
PSExec.exe \\SERVERNAME01 -s cmd /C echo N | robocopy \\SOURCE \\DESTINATION /R:1 /W:1 /E /Z /COPY:DATSO /DCOPY:DAT /SECFIX /TIMFIX /MT:128 /MIN:1 /MAX: 256
PSExec.exe \\SERVERNAME02 -s cmd /C echo N | robocopy \\SOURCE \\DESTINATION /R:1 /W:1 /E /Z /COPY:DATSO /DCOPY:DAT /SECFIX /TIMFIX /MT:128 /MIN:257 /MAX: 512
PSExec.exe \\SERVERNAME03 -s cmd /C echo N | robocopy \\SOURCE \\DESTINATION /R:1 /W:1 /E /Z /COPY:DATSO /DCOPY:DAT /SECFIX /TIMFIX /MT:128 /MIN:513 /MAX: 1024
PSExec.exe \\SERVERNAME04 -s cmd /C echo N | robocopy \\SOURCE \\DESTINATION /R:1 /W:1 /E /Z /COPY:DATSO /DCOPY:DAT /SECFIX /TIMFIX /MT:128 /MIN:1025
