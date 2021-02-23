@ECHO off
SETLOCAL
REM ====================================================================================================
REM This script checks for updates in all git repositories, starting in the current directory.
REM
REM It does this by recursively calling git status and git fetch on all directories. If there are
REM unsaved commits or new changes in the remote, the repo name is added to status.txt.
REM ====================================================================================================

REM TODO check that variables haven't already been taken

SET out_file=status.txt
SET no_repo="fatal: not a git repository (or any of the parent directories): .git"
REM Remove quotes
SET no_repo=%no_repo:"=%

ECHO %no_repo%
FOR /D %%i in (./*) DO (
	ECHO %%i
	REM TODO
)

EXIT /B %ERRORLEVEL%

REM Functions
REM ====================================================================================================
:GitStatus
	CD %~1
	REM TODO
EXIT /B 0