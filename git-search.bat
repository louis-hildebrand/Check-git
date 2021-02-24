@ECHO off
SETLOCAL EnableDelayedExpansion
REM ====================================================================================================
REM This script checks for updates in all git repositories, starting in the current directory.
REM ====================================================================================================

SET temp_out=%~dp0
SET temp_out=%temp_out%temp.txt
SET no_repo="fatal: not a git repository (or any of the parent directories): .git"
SET no_repo=%no_repo:"=%
SET /A count=-1
SET repos[0]=""
SET output[0]=""

REM Parse arguments
SET /A search_recursive=0
SET /A show_progress=0
SET /A path_taken=0
FOR %%i in (%*) DO (
	REM Copy argument to variable and strip quotes
	SET arg=%%i
	SET arg=!arg:"=!
	
	IF "!arg!"=="-r" (
	REM Recursive flag
		ECHO Recursive mode enabled
		SET /A search_recursive=1
	) ELSE IF "!arg!"=="-p" (
	REM Progress flag
		ECHO Progress will be shown
		SET /A show_progress=1
	) ELSE IF EXIST "!arg!\" (
	REM If a path is given, start in that directory
		IF !path_taken!==1 (
			ECHO(
			ECHO Fatal: git-search does not accept more than one path as arguments
			EXIT /B 0
		) ELSE (
			ECHO Starting search in "!arg!"
			SET /A path_taken=1
			CD "!arg!"
		)
	) ELSE (
	REM Invalid argument
		ECHO Warning: unused argument "!arg!"
	)
)
IF %path_taken%==0 (
	ECHO Starting search in "%CD%"
)
ECHO(

REM Iterate through directories and check git status and git fetch
IF %show_progress%==1 ( ECHO Progress: )
FOR /D %%i in (./*) DO (
	IF %show_progress%==1 ( ECHO     Searching "%%i" )
	CALL :CheckDir "%%i"
)

REM Print report
ECHO(
IF %count%==-1 (
	ECHO No git repositories found.
) ELSE (
	ECHO Git repos:
	FOR /L %%i in (0, 1, %count%) DO (
		ECHO     !repos[%%i]!
	)
)

REM Clear temp output file
COPY NUL "%temp_out%" > NUL

EXIT /B %ERRORLEVEL%




REM Functions
REM ====================================================================================================
:CheckDir
	CD "%~dpnx1"
	REM Get output from git status into output
	GIT status > "%temp_out%" 2>&1
	SET /A index=-1
	FOR /F "eol=; tokens=* usebackq" %%i in ("%temp_out%") DO (
		SET /A index+=1
		SET output[!index!]="%%i"
	)
	REM Not a git repo
	IF %output[0]%=="%no_repo%" (
		REM Iterate through subdirectories
		IF %search_recursive%==1 (
			FOR /D %%i in (./*) DO (
				CALL :CheckDir "%%i"
			)
		)
	) ELSE (
		REM Valid git repo
		SET /A count+=1
		SET repos[!count!]="%~dpnx1"
	)
	CD ..
EXIT /B 0