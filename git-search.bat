@ECHO off
SETLOCAL EnableDelayedExpansion
REM ====================================================================================================
REM This script checks for updates in multiple git repositories.
REM ====================================================================================================

SET temp_out=%~dp0
SET temp_out=%temp_out%temp.txt

SET no_repo="fatal: not a git repository (or any of the parent directories): .git"
SET no_repo=%no_repo:"=%
SET /A status=0
SET /A count=-1
SET repos[0]=""
SET has_commits[0]=""
SET has_remote_changes[0]=""

REM Parse arguments
SET /A search_recursive=0
SET /A show_progress=0
SET /A path_taken=0
FOR %%i in (%*) DO (
	REM Copy argument to variable and strip quotes
	SET arg=%%i
	SET arg=!arg:"=!
	
	IF /I "!arg!"=="-r" (
	REM Recursive flag
		IF !search_recursive!==1 (
			ECHO [91mError: repeated flag -r[0m
			GOTO :eof
		)
		SET /A search_recursive=1
	) ELSE IF /I "!arg!"=="-p" (
	REM Progress flag
		IF !show_progress!==1 ( 
			ECHO [91mError: repeated flag -p[0m
			GOTO :eof
		)
		SET /A show_progress=1
	) ELSE IF EXIST "!arg!\" (
	REM If a path is given, start in that directory
		IF !path_taken!==1 (
			ECHO(
			ECHO [91mError: git-search does not accept more than one path as arguments[0m
			GOTO :eof
		) ELSE (
			SET /A path_taken=1
			CD "!arg!"
		)
	) ELSE IF /I "!arg!"=="--help" (
	REM Display help message
		CALL :ShowHelp
		GOTO :eof
	) ELSE IF /I "!arg!"=="-h" (
	REM Display help message
		CALL :ShowHelp
		GOTO :eof
	) ELSE (
	REM Invalid argument
		ECHO [91mError: unused argument "!arg!"[0m
		GOTO :eof
	)
)
REM Show user execution info
IF %search_recursive%==1 	( ECHO Recursive mode enabled )
IF %show_progress%==1		( ECHO Progress will be shown )
ECHO Starting search in "%CD%"
IF %show_progress%==1 (
	ECHO(
)

REM Iterate through directories and check git status and git fetch
IF %show_progress%==1 ( ECHO Progress: )
FOR /D %%i in (./*) DO (
	CALL :CheckDir "%%i"
)

REM Print report
IF %count%==-1 (
	ECHO -
	ECHO(
	ECHO No git repositories found.
) ELSE (
	ECHO(
	SET /A count+=1
	ECHO !count! git repos found:
	SET /A count-=1
	FOR /L %%i in (0, 1, %count%) DO (
		ECHO     !repos[%%i]!
		IF !has_commits[%%i]!==1 (
			ECHO         [96mUnsaved local changes[0m
		)
		IF !has_remote_changes[%%i]!==1 (
			ECHO		[95mNew changes in the remote[0m
		)
	)
)

REM Clear temp output file
COPY NUL "%temp_out%" > NUL

EXIT /B %ERRORLEVEL%




REM ====================================================================================================
REM Functions
REM ====================================================================================================
:ShowHelp
	ECHO Checks for local and remote updates in multiple git repositories
	ECHO(
	ECHO usage: git-search [^<path^>] [-r] [-p] [--help ^| -h]
	ECHO     ^<path^>      The directory whose subdirectories are to be searched
	ECHO     -r          Recursively check all subdirectories
	ECHO     -p          Display progress
	ECHO     --help, -h  Show help
	ECHO(
EXIT /B 0

:CheckDir
	IF %show_progress%==1 ( ECHO     Searching "%~dpnx1" )
	SET dir_name="%~dpnx1"
	CD "%~dpnx1"
	REM Check whether the directory is a git repo
	IF NOT EXIST "%dir_name:"=%\.git\" (
	REM Not a git repo: iterate through subdirectories if recursive option is selected
		IF %search_recursive%==1 (
			FOR /D %%i in (./*) DO (
				CALL :CheckDir "%%i"
			)
		)
	) ELSE (
		REM Get output from git status into output
		CALL :RunGitStatus status
		IF !status!==0 (
		REM Not a git repo: iterate through subdirectories if recursive option is selected
			IF %search_recursive%==1 (
				FOR /D %%i in (./*) DO (
					CALL :CheckDir "%%i"
				)
			)
		) ELSE (
		REM Valid git repo
			SET /A count+=1
			SET repos[!count!]=!dir_name!
			IF !status!==2 (
				SET /A has_commits[!count!]=1
			) ELSE (
				SET /A has_commits[!count!]=0
			)
			
			REM Check for changes in the remote
			CALL :RunGitFetch status
			IF !status!==0 (
				SET /A has_remote_changes[!count!]=0
			) ELSE (
				SET /A has_remote_changes[!count!]=1
			)
		)
	)
	CD ..
EXIT /B 0

REM Runs git status and returns an integer indicating the result:
REM		0: Not a git repo
REM		1: No changes or untracked files
REM 	2: Changes to be committed or untracked files
:RunGitStatus
	GIT status > "%temp_out%" 2>&1
	SET /A index=-1
	FOR /F "eol=; tokens=* usebackq" %%i in ("%temp_out%") DO (
		SET /A index+=1
		SET output[!index!]="%%i"
	)
	REM Process output
	IF %output[0]%=="%no_repo%" (
	REM Not a git repo
		SET /A %~1=0
	) ELSE IF !index!==2 (
	REM Possibly no commits
		SET /A %~1=1
	) ELSE (
	REM Unsaved commits
		SET /A %~1=2
	)
EXIT /B 0

REM Runs git fetch and returns an integer indicating the result:
REM		0: Nothing to fetch
REM		1: new changes in the remote
:RunGitFetch
	GIT fetch > "%temp_out%" 2>&1
	SET /A index=-1
	FOR /F "eol=; tokens=* usebackq" %%i in ("%temp_out%") DO (
		SET /A index+=1
		SET output[!index!]="%%i"
	)
	REM Process output
	IF !index!==-1 (
	REM No message: nothing to fetch
		SET /A %~1=0
	) ELSE (
	REM New changes in the remote
		SET /A %~1=1
	)
EXIT /B 0