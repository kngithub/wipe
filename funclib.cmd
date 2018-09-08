@Echo OFF
Echo Subroutinen-Bibliothek. Kann nicht direkt gestartet werden
Exit /B 20

:libInit
If "%~1" EQU "" (
	Echo Programmname nicht uebergeben.
	Echo Call ^:libInit ^"programmname^"
	exit /B 5
)
Set __lib_caller=%~1
Set __lib_init=true
Call :checkBG "__lib_colored"
Exit /B 0

:noinit
Echo ^:libInit muss zuerst aufgerufen werden; z.B. mit
Echo Call 2^> NUL ^:libInit ^"programmname^" ^|^| ^( ^<Befehle bei Scheitern^> ^)
Exit /B 20

REM ----------------------------------------------------------------------
REM Subroutine checkBG <varname>
REM testet, ob Ausgabeprogramm bg.exe im Pfad existiert
:checkBG
(Set %~1=)
bg.exe PRINT "foo" > NUL 2> NUL
If "!ERRORLEVEL!" EQU "0" (
	(Set %~1=true)
)
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine getConLines <varname>
REM Ermittelt / setzt Zeilenanzahl fuer Ausgabe der Dateien
:getConLines
SetLocal EnableDelayedExpansion
(Set lines=)
For /F "skip=2 tokens=2 delims=: " %%L IN ('mode CON:') DO (
    (Set lines=%%L)
    REM weitere Zeilen werden nicht gelesen
    Goto testLineVal
)
:testLineVal
Echo !lines!| findstr /R "^[1-9][0-9]*$" > NUL
If "!ERRORLEVEL!" NEQ "0" (
	(Set /A lines=100)
)
If !lines! GTR 200 (Set /A lines=200)
EndLocal&Set %~1=%lines%
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine message "<text>" [/N] [/C:V[H]]
REM Textausgabe mit optischer Markierung.
REM    /N Es wird keine zusätzliche Leerzeile ausgegeben.
REM    /R Die Nachricht wird ohne prefix/postfix ausgegeben
REM  
REM Zusätzlich, wenn bg.exe gefunden wurde
REM    /C:V   Setzt Vordergrundfarbe.
REM    /C:VH  Setzt Vorder- und Hintergrundfarbe
REM           Für V bzw. H ist jeweils der Farbcode (0-9 oder A-F) einzusetzten
:message
SetLocal EnableDelayedExpansion
(Set nel=)
(Set clean=)
(Set msg=%~1)
(Set col=1A)
Shift
:msgLoop
If "%~1" NEQ "" (
	If /I "%~1" EQU "/N" (
		(Set nel=true)
	)
	If /I "%~1" EQU "/R" (
		(Set clean=true)
	)
	If DEFINED __lib_colored (
		Echo %~1| findstr /I /R "^\/C\:[A-F0-9][A-F0-9]*$" > NUL
		If "!ERRORLEVEL!" EQU "0" (
			(Set col=%~1)
			(Set col=!col:~3!)
		)
	)
	Shift
	Goto msgLoop
)
If NOT DEFINED nel (
	Echo.
)
If NOT DEFINED clean (
	Set "msg= -- !msg!"
)
If DEFINED __lib_colored (
	REM benutze Echo. statt \n, damit Hintergrundfarbe der nächsten Zeile zurückgesetzt wird
	Set msg=!msg:\=\\!
	bg.exe print !col! "!msg!"
	Echo.
) Else (
	Echo !msg!
)
EndLocal
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine errMsg <text> [<color(s)>]
REM Fehlermeldung ausgeben. Zweiter Paramter ist Farbcode für Vorder- und ggf. Hintergrund-
REM farbe, jeweils 0-F, bspw. errMsg "hi" F  für weißen Text oder errMsg "hi" F0 für
REM schwarzen Text auf weißem Hintergrund. Standard: weiß auf rot
:errMsg
SetLocal EnableDelayedExpansion
Set pcol=4F
If {%~2} NEQ {} (
	(Set pcol=%~2)
)
Echo.
If DEFINED __lib_colored (
	bg.exe 1>&2 print !pcol! " ^!^! %~1^!"
	Echo.
) Else (
	Echo 1>&2 ^^!^^! %~1^^!
)
EndLocal
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine escape <varname> <text>
:escape
SetLocal DisableDelayedExpansion
Set str=%~2
Set str=%str:&=^&%
Set str=%str:|=^|%
Set str=%str:<=^<%
Set str=%str:>=^>%
Set str=%str:^=^^%
EndLocal&Set "%~1=%str%"
exit /B

REM ----------------------------------------------------------------------
REM Subroutine usage80 <program> <usageparamname>
REM default fuer usageparamname ist /?
:usage80
SetLocal
Set "hlp=/?"
Set f80=%temp%\u80.txt
If {%~2} NEQ {} (
	Set "hlp=%~2"
)
> %f80% Call "%~1" %hlp%
Echo Zeilen ueber 80 Zeichen:
For /F "delims=" %%L IN (%f80%) DO (
	Set o=%%L
	Set o=!o:~80!
	if {!o!} NEQ {} (
		echo [%%L]
		echo zu lang: [!o!]
		Echo.
	)
)
del %f80%
EndLocal
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine pgptest
REM Testet, ob pgp.exe vorhanden ist.
:pgptest
If NOT DEFINED __lib_init (Goto noinit)
If NOT DEFINED PGPPATH (Set /P PGPPATH="Bitte Pfad zu pgp.exe definieren: ")
If NOT EXIST "%PGPPATH%\pgp.exe" (
	where /Q pgp.exe  REM quiet mode, nur ERRORLEVEL wird benötigt
	If !ERRORLEVEL! EQU 0 (  REM pgp.exe wurde gefunden
		If NOT DEFINED testloop (
			(Set testloop=true)

			REM Ausgabe von where in Variable setzen und /pgp.exe entfernen
			For /F "delims=" %%A in ('where pgp.exe') do (@Set foo=%%A)
			If DEFINED foo (
				(Set  PGPPATH=!foo:~0,-8!)
				SetX PGPPATH !foo:~0,-8! > NUL
				Echo PGPPATH wurde gesetzt: !PGPPATH!
			)

			REM Erneuter Aufruf der Subroutine mit ermitteltem Pfad
			Call :pgptest
		)
	) Else (
		Call :errMsg "PGP.exe nicht gefunden. %__lib_caller% kann nicht fortgesetzt werden"
		Exit /B 20
	)
)
Exit /B 0

REM ENDE
