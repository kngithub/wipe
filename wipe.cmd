@Echo OFF
REM wipe.cmd  2018-02-04 KN
REM Löscht alle Dateien in einem Verzeichnis, auf die ein Muster passt

SetLocal EnableExtensions EnableDelayedExpansion

REM prgname ist der Dateiname mit Erweiterung
REM prgbasename ist der reine Dateiname ohne Erweiterung, wird u.A. als Basisname für
REM die logdatei verwendet
Set prgname=%~nx0
Set prgbasename=%~n0

Call :libInit "%prgname%" 2> NUL || (
	Echo.
	Echo FEHLER^^!^^! Dieses Script benoetigt die Bibliothek funclib.cmd
	Exit /B 20
)

REM Test, ob Echo-Ersatz bg.exe verfügbar ist
Call :checkBG "foundBG"

REM Ermitteln der Fenster-Zeilenzahl für Dateilisten-Ausgabe
Call :getConLines "conlines"

REM keine Parameter
If {%~1} EQU {} (
	Call :message "Keine Parameter spezifiziert. %prgname% -h fuer Hilfe"
	Exit /B 1
)

REM Grundwerte setzen und dafür sorgen, daß verwendete Variablen nicht definiert sind
:setup
REM Liste gültiger Parameter-Namen
(Set validlist= a e f h i l n p r s t u v x z 8 D HS Q lo ls -h80 -ps -force-delete #)

REM vordefinierte Datei-Erweiterungen
Set exts[a]=*.flac,*.mp3,*.wma,*.wav,*.ogg,*.opus
Set exts[i]=*.jpg,*.gif,*.png,*.jpeg,*.jpe,*.bmp
Set exts[v]=*.mpg,*.avi,*.mp4,*.mkv,*.m4v,*.mov,*.ts,*.wmv,*.flv,*.f4v,*.webm,*.3gp
Set exts[z]=*.zip,*.rar,*.7z,*.tar,*.gz,*.arc,*.arj,*.cab,*.lha

REM Alle Variablen in 'myvars' auf 'nicht definiert' setzen
Set myvars=deldirs delhidden delmodes[a] delmodes[i] delmodes[v] dirline dirswitch epat ^
	fcnt fcout forceskip isbatch linecnt linemax logging msg name newlog par pat pn ^
	recurse showlog size skipp skipq testloop testmode useenv usepre useshort wcmdline ^
	xpat
For %%A IN (%myvars%) DO (
	(Set %%A=)
)
(Set myvars=)

REM findstr ändert Wert von ERRORLEVEL, wenn Ausgabe nach NUL umgeleitet wird, daher
REM muss auf EQU 0 getestet werden, wenn Treffer gefunden wurde
Echo "%*"| findstr /R /I "\-h\> \-help\> /\?\> /H\> /Help\>" > NUL
If "!ERRORLEVEL!" EQU "0" (
	Call :usage
	Exit /B
)

REM Anzeige der vordefinierten Muster, wenn Parameter -s vorhanden ist
Echo "%*"| findstr /R "\-s\>" > NUL
If !ERRORLEVEL! EQU 0 (
	Call :showext
	Exit /B
)

REM feststellen, ob diese Batchdatei aus einer Cmd-Shell oder aus einem Programm
REM aufgerufen wurde
Echo %cmdcmdline% | find /I "%~0" > NUL
If !ERRORLEVEL! GTR 0 (Set isbatch=true)

REM PGP suchen und ggf. Pfad setzen
Call :pgptest
If !ERRORLEVEL! GTR 0 (Exit /B 20)

REM ===== Alle Parameter verarbeiten =====
:paramLoop
If {%~1} NEQ {} (    REM Wenn jeweils erster Parameter nicht leer ist

	(Set "par=%~1")

	REM Parameternamen validieren
	Call :validate "!par!"
	If !ERRORLEVEL! GTR 0 (Exit /B 10)

	REM Video-Modus
	If "!par!" EQU "-v" (
		(Set delmodes[v]=true)
		Goto nextParam
	)

	REM Image-Modus
	If "!par!" EQU "-i" (
		(Set delmodes[i]=true)
		Goto nextParam
	)

	REM Audio-Modus
	If "!par!" EQU "-a" (
		(Set delmodes[a]=true)
		Goto nextParam
	)

	REM Packer-Modus
	If "!par!" EQU "-z" (
		(Set delmodes[z]=true)
		Goto nextParam
	)

	REM Alle vordefinierten Muster
	If "!par!" EQU "-p" (
		(Set usepre=true)
		Goto nextParam
	)

	REM Umgebungsvariable nutzen
	If "!par!" EQU "-u" (
		(Set useenv=true)
		Goto nextParam
	)

	REM Logging
	If "!par!" EQU "-l" (
		(Set logging=true)
		Goto nextParam
	)
	If "!par!" EQU "-lo" (
		(Set logging=true)
		(Set newlog=true)
		Goto nextParam
	)
	If "!par!" EQU "-ls" (
		(Set logging=true)
		(Set showlog=true)
		Goto nextParam
	)

	REM Kurze Dateinamen benutzen
	If "!par!" EQU "-8" (
		(Set useshort=true)
		Goto nextParam
	)

	REM Erzwingt Löschen auch bei rekursiver Dateisuche. Gefährlich, daher undokumentiert
	If "!par!" EQU "--force-delete" (
		(Set forceskip=true)
		Goto nextParam
	)

	REM Test-Modus: keine Löschung von Dateien
	If "!par!" EQU "-t" (
		(Set testmode=true)
		Goto nextParam
	)

	REM Sicherheitsabfragen und Anzeige Dateiliste überspringen
	If "!par!" EQU "-Q" (
		(Set skipq=true)
		Goto nextParam
	)

	REM Dateiliste ohne Pause
	If "!par!" EQU "-n" (
		(Set skipp=true)
		Goto nextParam
	)

	REM rekursive Dateisuche aktivieren
	If "!par!" EQU "-r" (
		(Set recurse=true)
		Goto nextParam
	)

	REM Verzeichnisse löschen
	If "!par!" EQU "-D" (
		(Set deldirs=true)
		Goto nextParam
	)

	REM Versteckte und System-Dateien einbeziehen
	If "!par!" EQU "-HS" (
		(Set delhidden=true)
		Goto nextParam
	)

	REM zusätzliche Dateimuster
	If "!par!" EQU "-x" (
		REM Überprüfung des nachfolgenden Parameters
		Call :checkValue "!par!" "%~2"
		If !ERRORLEVEL! GTR 0 (Exit /B 10)

		Call :addPattern "xpat" "%~2"

		REM zusätzliche Verschiebung der Parameterliste, da zwei Parameter entfernt
		REM werden müssen
		Shift
		Goto nextParam
	)

	REM exklusiv zu verwendende Dateimuster
	If "!par!" EQU "-e" (
		Call :checkValue "!par!" "%~2" "unsetEx"
		If !ERRORLEVEL! GTR 0 (Exit /B 10)
		(Set epat=%~2)
		Shift
		Goto nextParam
	)

	REM alle Parameter, die nicht mit "-" starten, als Muster verwenden
	If "!par:~0,1!" NEQ "-" (
		Call :addPattern "pat" "!par!"
		Goto nextParam
	)

	REM Parameterzeile aus einer Datei einlesen
	If "!par!" EQU "-f" (
		Call :checkFile "!par!" "%~2" "%~3"
		Exit /B !ERRORLEVEL!
	)

	If "!par!" EQU "--h80" (
		Call :usage80 "%prgname%"
		Exit /B
	)

	If "!par!" EQU "--ps" (
		Set psmode=true
	)

	:nextParam
	REM Parameterliste verschieben
	Shift

	REM Rücksprung zum Label
	Goto paramLoop
)

(Set validlist=)
(Set par=)

If DEFINED psmode (
	Set skipq=true
	Set skipp=true
	Set forceskip=true
	Set recurse=true
	Set deldirs=true
	Set pat=*.txt,*.jpg,*.mp4,*.ts
	Goto listFiles
)

if DEFINED delhidden (
	(Set skipq=)
)

REM alle vordefinierten Muster
If DEFINED usepre (
	For /F "tokens=2 delims=[]" %%M IN ('set exts[') DO (
		(Set delmodes[%%M]=true)
	)
	(Set useenv=true)
	If DEFINED skipq (
		If NOT DEFINED forceskip (
			Call :disableSkip "-p"
		)
	)
)

REM Wenn -Q und -r gleichzeitig gesetzt wurden, dann soll die Funktion von -Q aus
REM Sicherheitsgründen ignoriert werden (Rekursives Löschen ohne Abfrage kann zu
REM unerwünschten Löschungen führen). Wird jedoch zusätzlich(!!) der Parameter
REM --force-delete gesetzt, dann wird rekursiv ohne Sicherheitsabfrage gelöscht.
REM Ohne gesetzte Parameter -Q UND -r hat --force-delete keine Auswirkungen.
If DEFINED skipq (
	If DEFINED recurse (
		If NOT DEFINED forceskip (
			Call :disableSkip "-r"
		)
	)
)

REM ===== Dateimuster-Liste je nach Optionswahl erstellen =====
:setPatterns
If DEFINED epat (
	REM Wenn Parameter -e gesetzt ist, wird ausschließlich die dort übergebene
	REM Muster-Liste verwendet.
	(Set pat=%epat%)
) Else (
	REM Test, ob in der paramLoop-Schleife eine der delmodes-Variablen gesetzt wurde.
	Set > NUL 2> NUL delmodes[
	If !ERRORLEVEL! EQU 0 (
		REM Liste der vordefinierten Dateierweiterungen erstellen
		REM Schleife über alle gesetzten Werte in delmodes
		For /F "tokens=2 delims=[]" %%M IN ('set delmodes[') DO (
			If DEFINED exts[%%M] (
				Call :addPattern "pat" "!exts[%%M]!"
			)
		)
	)

	REM Muster aus Parameter -x hinzufügen
	If DEFINED xpat (
		(Set "pat=%xpat%,!pat!")
	)

	REM Muster aus Umgebungsvariable hinzufügen
	If DEFINED useenv (
		If DEFINED WIPEBAT_PATTERN (
			(Set "pat=%WIPEBAT_PATTERN%,!pat!")
		) Else (
			Call :message "Umgebungsvariable WIPEBAT_PATTERN ist nicht gesetzt"

			REM Wenn '-u' alleiniger Parameter war, dann Abbruch
			(Set gtmp=%*)
			If "!gtmp!" EQU "-u" (Exit /B)
		)
	)
)

REM Falls bisher 'pat' noch nicht definiert wurde, ist kein gültiger Parameter
REM gefunden worden.
If NOT DEFINED pat (
	Call :message "Es wurde kein Muster definiert. %prgbasename% -h fuer Hilfe"
	Exit /B 10
)

REM Je nach Kombination der Parameter muß ein Komma am Ende entfernt werden
If "!pat:~-1!" EQU "," (
	(Set pat=!pat:~0,-1!)
)

REM ===== Trefferliste der zu löschenden Dateien ausgeben =====
:listFiles
Set tmpfile=%temp%\wipe_dir.tmp
SetLocal DisableDelayedExpansion
	If DEFINED recurse (
		(Set dirswitch=/S)
	)
	if DEFINED delhidden (
		(Set dflags=)
	) Else (
		(Set dflags=-H-S)
	)
	(Set dirline=%pat% /A:-D-R%dflags% /B /O:N %dirswitch%)
	(Set DIRCMD=)
	(Set /A fcnt=0)
	echo %dirline% %dflags%

	REM Datei anlegen oder überschreiben
	type NUL > %tmpfile%  || (
		Call :errMsg "Kann temporaere Datei nicht nutzen"
		Exit /B
	)

	REM alle passenden Dateien in temporäre Datei schreiben
	REM Dateiname und -größe werden durch Zeichen * getrennt
	For /F "delims=" %%F IN ('dir %dirline% 2^> NUL') DO (
		If DEFINED useshort (
			(Set name=%%~sF)
		) Else (
			(Set name=%%~F)
		)
		(Set /A fcnt+=1)
		SetLocal EnableDelayedExpansion
			(Echo !name!*%%~zF) >> !tmpfile!
		EndLocal
	)

	REM keine Treffer, Nachricht ausgeben und Beenden
	If %fcnt% LSS 1 (
		SetLocal EnableDelayedExpansion
		Call :message "Keine Treffer fuer:" /C:1F
		Call :message "%pat%" /N
		Goto batchEnd
	)


	REM Augabe der passenden Dateien
	Echo.
	Call :testmodemessage
	(Set /A fcnt=1)
	For /F "tokens=1,2 delims=*" %%F IN (%tmpfile%) DO (
		If NOT DEFINED skipq (
			(Set name=%%F)
			SetLocal EnableDelayedExpansion
				(Set fcout=    !fcnt!)
				(Set "size=          %%G")
				Echo !fcout:~-4! !size:~-10!  !name!
				If NOT DEFINED skipp (
					(Set /A remain=!fcnt! %% !conlines!)
					If "!remain!" EQU "0" (Pause&echo !ERRORLEVEL!)
				)
			EndLocal
		)
		(Set /A fcnt+=1)
	)
	Call :testmodemessage
EndLocal & Set fcnt=%fcnt%

REM Sicherheitsabfrage vor dem Löschen. Zur Vermeidung von Fehlbedienung wird als
REM Bestätigung ausschliesslich auf ein J (Grossbuchstabe) reagiert
REM Diese Abfrage wird mit Parameter -Q übersprungen
Echo.
If DEFINED skipq (
	Goto wipe
) Else (
	(Set /A fcnt-=1)
	Choice /CS /C JNnaA /N /M "Sollen die angegebenen !fcnt! Dateien geloescht werden? (J/n)"
	If !ERRORLEVEL!==1 (Goto wipe)
)

REM wird aufgerufen, wenn Sicherheitsfrage nicht mit J bestätigt wurde
:cancel
Call :message "Abgebrochen" /C:6
Set rc=5
Goto batchEnd

REM Dateien löschen
:wipe
Echo.
Set /A rc=0
If DEFINED testmode (
	(Set logging=)
)
If DEFINED logging (
	(Set logfile=!USERPROFILE!\!prgbasename!.log)
	(Set "loghead=Loeschprotokoll %DATE% %TIME:~0,-3%")
	If DEFINED newlog (
		>  !logfile! Echo !loghead!
	) Else (
		>> !logfile! Echo !loghead!
	)
)

REM Zähler Dateien
Set /A "wcnt=0"
REM Zähler Fehler
Set /A "ecnt=0"
SetLocal DisableDelayedExpansion

For /F "tokens=1 delims=*" %%F IN (%tmpfile%) DO (
	If NOT DEFINED testmode (
		(Set fx=)
		%PGPPATH%\pgp.exe +batchmode -w "%%F" 2> NUL || (
			(Set /A ecnt+=1)
			If DEFINED logging (
				(Set "attr=%%~aF")
				SetLocal EnableDelayedExpansion
				>> %logfile% Echo -- Fehler beim Loeschen: "%%F"
				>> %logfile% Echo        Datei-Attribute: [!attr: =!]
				EndLocal
			)
			(Set fx=true)
		)

		If NOT DEFINED fx (
			If DEFINED logging (
				>> %logfile% Echo ++ Datei geloescht: "%%F"
			)
		)
	)
	(Set /A wcnt+=1)
	SetLocal EnableDelayedExpansion
	EndLocal
)
EndLocal&(Set wcnt=%wcnt%&Set ecnt=%ecnt%)

If DEFINED logging (
	If NOT DEFINED newlog (
		>> !logfile! Echo ==========================================================
	)
)
Call :message "Dateien gesamt: !wcnt!; Fehler: !ecnt!"
If !ecnt! GTR 0 (
	Echo.
	If NOT DEFINED isbatch (
		If NOT DEFINED skipq (
			Pause
		)
	)
	(Set /A rc=20)
)

REM Leere Verzeichnisse löschen
:deldir
SetLocal DisableDelayedExpansion
If DEFINED deldirs (
	Echo.
	Call :testmodemessage
	For /F "delims=" %%D in ('dir /s /b /a:d ^| sort /r 2^> NUL') DO (
		If DEFINED useshort (
			(Set dirname=%%~sD)
		) Else (
			(Set dirname=%%D)
		)
		SetLocal EnableDelayedExpansion
		If DEFINED testmode (
			Echo Loeschen: !dirname!
		) Else (
			If EXIST "!dirname!\." (
				rmdir "!dirname!" > NUL 2> NUL
				If NOT EXIST "!dirname!\." (
					Call :message "Verzeichnis !dirname! geloescht"
				)
			)
		)
		EndLocal
	)
	Call :testmodemessage
)
EndLocal

If DEFINED showlog (
	Echo.
	If EXIST %prgbasename%.log (
		type %prgbasename%.log
	)
)

:batchEnd
del !tmpfile! 2> NUL
REM Wenn nicht aus cmd-Fenster gestartet, Pause vor dem Schließen des Fensters einlegen,
REM wenn skipq nicht gesetzt ist oder anderenfalls, wenn Fehler aufgetreten sind
If NOT DEFINED isbatch (
	If DEFINED skipq (
		If !ecnt! NEQ 0 (Pause)
	) Else (
		Pause
	)
)
Exit /B !rc!

REM ========================== SUBROUTINEN ===============================

REM Subroutine addPattern <name> <value>
REM Setzt ein Muster oder erweitert es
:addPattern
SetLocal EnableDelayedExpansion
Set pn=%~1
If NOT DEFINED !pn! (
	(Set pv=%~2)
) Else (
	(Set pv=!%pn%!,%~2)
)
EndLocal & Set %pn%=%pv%
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine checkValue <param> <next_param> [<call_label>]
REM überprüft, ob einem Parameter eine Wertzuweisung folgt und ob diese gültig ist
:checkValue
If {%~2} NEQ {} (
	(Set pp=%~2)

	REM erstes Zeichen darf kein Minus sein
	If "!pp:~0,1!" EQU "-" (
		Call :errMsg "hinter %~1 muss ein Dateimuster folgen, kein Parameter" 0D
		Exit /B 20
	) Else (
		REM Ein eventuell an die checkValue Subroutine übergebener dritter Parameter als
		REM Label behandeln und dieses aufrufen.
		If {%~3} NEQ {} (
			Call :%~3
		)
	)
) Else (
	Call :errMsg "hinter %~1 muss ein Dateimuster folgen" 0D
	Exit /B 20
)
Exit /B 0

REM ----------------------------------------------------------------------
REM Exklusiver Modus: Muster-Liste aus eventuellem Parameter -x wird gelöscht und
REM Auswertung der Umgebungsvariable abgeschaltet
:unsetEx
(Set xpat=)
(Set useenv=)
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine usage
REM Hinweistext zu möglichen Parametern ausgeben
:usage
SetLocal DisableDelayedExpansion
Set "common=[-Q^|-r] [-8] [-t] [-n] [-l^|-lo] [-ls] [-D]"
Echo.
Echo %prgname% loescht Dateien mit der ^"wipe^"-Option von PGP. Dateien mit gesetzten
Echo Attributen R, H oder S (schreibgeschuetzt, versteckt, System) werden ignoriert.
Echo.
Echo USAGE:
Echo %prgbasename% [[-x] ^"muster^"] [-v] [-i] [-a] [-u] [-p] [-z] {allgemeine Optionen}
Echo %prgbasename% -e ^"muster^" {allgemeine Optionen}
Echo %prgbasename% -f ^"datei^" [zeile]
Echo %prgbasename% -s
Echo.
Echo Allgemeine Optionen sind: %common%
Echo.
Echo MUSTER
Echo   -x	^"muster^"  Setzt ein Loesch-Muster oder fuegt weitere Muster zu den
Echo     	gesetzten Werten hinzu. Mehrfach verwendbar.
Echo   -e	^"muster^"  Setzt exklusiv ein Muster, alle fast anderen Muster-Optionen
Echo     	sowie die Umgebungsvariable WIPEBAT_PATTERN werden ignoriert
Echo   -v	Setzt Loesch-Muster auf Dateiendungen gaengiger Video-Formate
Echo   -i	Setzt Loesch-Muster auf Dateiendungen gaengiger Bild-Formate
Echo   -a	Setzt Loesch-Muster auf Dateiendungen gaengiger Audio-Formate
Echo   -z	Setzt Loesch-Muster auf Dateiendungen gaengiger Packer-Formate
Echo   -p	Alle vordefinierten Muster, entspricht ^"-a -i -v -u -z^"
Echo   -u	Steuert die Verwendung der Umgebungsvariablen WIPEBAT_PATTERN
Echo   -s	Zeigt alle vordefinierten Muster an und %prgname% endet
Echo.
Echo VERHALTEN
Echo   -r	Sucht zusaetzlich nach allen passenden Dateien in Unterverzeichnissen
Echo   -n	Die Ausgabe der Dateiliste vor dem Loeschen wird nicht pausiert
Echo   -8	Verwendet kurze (8.3) Dateinamen
Echo   -t	Test-Modus. Dateien werden nicht geloescht
Echo   -D	Loescht leere Verzeichnisse
Echo   -Q	Ueberspringt die Sicherheitsabfrage und loescht die Dateien unmittelbar.
Echo     	Die Dateien werden vor dem Loeschen nicht aufgelistet.
Echo   -f	^"datei^"  Liest eine Parameterzeile aus einer Datei aus. Alle weiteren
Echo     	Parameter der Befehlszeile werden ignoriert.
Echo   -HS	Es werden auch versteckte und Systemdateien, auf die das Muster passt, in die
Echo     	Löschliste aufgenommen. Mit VORSICHT verwenden! Diese Option schaltet -Q aus
Echo.
Echo LOGDATEI
Echo   -l	Schreibt die Namen der geloeschten Dateien und ggf. Fehler in die Datei
Echo     	^"%USERPROFILE%^\%prgbasename%.log^".
Echo   -lo	Wie ^"-l^", ueberschreibt jedoch eine vorhandenes Logdatei
Echo   -ls	Zeigt nach Loeschung die erzeugte Logdatei an. Falls der Paramter ^"-lo^"
Echo      	nicht angegeben wurde, wird Logging mit ^"-l^" automatisch aktiviert.
Echo.
Echo    ^"muster^" ist ein gueltiges DOS-Pattern; z.B. *.foo oder ^"*.foo,*.bar,a*.txt^"
Echo    Es muss in Anfuehrungszeichen uebergeben werden, wenn Komma-separierte Muster
Echo    verwendet werden, um eine sichere Erkennung zu gewaehrleisten. Darf mehrfach
Echo    verwendet werden.
Echo.
Echo    Ist der Parameter ^"-e^" gesetzt, werden die Parameter ^"-a^", ^"-i^", ^"-v^", ^"-z^"
Echo    ^"-p^", ^"-u^" und ^"-x^" ignoriert.
Echo.
Echo    Mit dem Parameter ^"-f^" kann eine Datei eingelesen werden, die vordefinierte
Echo    Parameterzeilen enthaelt. Ein zweiter Parameter ermoeglicht die gezielte
Echo    Auswahl einer Zeile. Wird nur der Dateiname angegeben oder ist der zweite
Echo    Parameter 0, wird der Datei-Inhalt ausgegeben und %prgname% beendet.
Echo    Der Parameter ^"-f^" darf in einer Parameter-Datei nicht verwendet werden.
Echo.
Echo    Werden die Parameter ^"-Q^" und ^"-r^" gleichzeitig verwendet, wird ^"-Q^" aus
Echo    Sicherheitsgruenden ignoriert.
Echo.
Echo    Ist die Umgebungsvariable WIPEBAT_PATTERN gesetzt, werden die dort einge-
Echo    tragenen Muster genutzt, wenn der Parameter ^"-u^" als einziger Parameter
Echo    verwendet wird oder hinzugefuegt, wenn der Parameter ^"-u^" mit anderen
Echo    Parametern verwendet wird.
EndLocal
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine testmodemessage
REM gibt im Testmodus einen Hinweis aus
:testmodemessage
If DEFINED testmode (
	If NOT DEFINED skipq (
		Call :message "----- TESTMODUS -----" /C:1B /R /N
	)
)
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine showext
REM zeigt vordefinierte Muster an
:showext
SetLocal EnableDelayedExpansion
If DEFINED WIPEBAT_PATTERN (
	(Set rr=%WIPEBAT_PATTERN%)
) Else (
	(Set "rr=Umgebungsvariable WIPEBAT_PATTERN nicht gesetzt")
)
Echo.
Echo Folgende Muster sind vordefiniert:
For /F "tokens=2 delims=[]" %%E in ('set exts[') DO (
	Echo   -%%E	!exts[%%E]!
)
Echo   -u	%rr%
EndLocal
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine validate <parametername>
REM Testen, ob ein Parametername erlaubt ist
:validate
::Set par=%~1
If "!par:~0,1!" EQU "/" (
	(Set par=-!par:~1!)
)

If "!par:~0,1!" EQU "-" (
	Echo %validlist%| findstr /C:" !par:~1! " > NUL
	If !ERRORLEVEL! GTR 0 (
		Call :errMsg "Ungueltiger Parameter !par!" 0D
		Exit /B 10
	)
)
Exit /B 0

REM ----------------------------------------------------------------------
REM Subroutine disableSkip
REM schaltet bei -Q und -r oder -p gleichzeitig die Funktion von -Q aus und gibt Hinweis
:disableSkip
(Set skipq=)
Call :message "Die Parameter %~1 und -Q duerfen nicht gleichzeitig verwendet werden." /C:6
Call :message "Parameter -Q wird nicht beachtet." /N /C:6
Exit /B

REM ----------------------------------------------------------------------
REM Subroutine checkFile <parametername> <parameterdatei> <zeilennummer>
:checkFile
If {%~2} NEQ {} (
	(Set par=%~1)
	(Set paramfile=%~2)
	If "!paramfile:~0,1!" EQU "-" (
		Call :errMsg "hinter !par! muss ein Dateiname folgen, kein Parameter" 0D
		Exit /B 10
	) Else (
		If EXIST !paramfile! (
			(Set nextparam=%~3)
			REM Testen, ob nächster Parameter eine Zahl ist.
			REM ACHTUNG! Bei regExp mit ^$ Begrenzung darf vor Pipe kein Leerzeichen
			Echo !nextparam!| findstr /R "^[1-9][0-9]*$ ^0$" > NUL
			If !ERRORLEVEL! NEQ 0 (
				If {!nextparam!} NEQ {} (
					Call :errMsg "ungueltiger Wert fuer Zeilen-Nummer: !nextparam!" 0D
					Exit /B 10
				)
			)
		) Else (
			Call :errMsg "Die hinter !par! angegebene Datei konnte nicht gefunden werden" 0D
			Exit /B 10
		)
	)
) Else (
	Call :errMsg "hinter !par! muss ein Dateiname folgen" 0D
	Exit /B 10
)
Call :readFromFile "!paramfile!" !nextparam!
Exit /B 0

REM ----------------------------------------------------------------------
REM Subroutine readFromFile <datei> <zeile>
REM liest eine Zeile einer Datei und führt wipe mit den dort übergebenen Parametern aus
:readFromFile
Set pfile="%~1"
Set /A linecnt=1
Set /A linemax=1
(Set listl=)
If "%~2" EQU "" (Set listl=true)
If "%~2" EQU "0" (Set listl=true)
If DEFINED listl (
	Echo.
	For /F "usebackq delims=#" %%A IN (!pfile!) DO (
		Echo   Zeile !linecnt!:  %%A
		(Set /A linecnt+=1)
	)
	Exit /B 0
)

If "%~2" GTR "0" (
	(Set /A "linemax=%~2")
)
For /F "usebackq delims=#" %%A IN (!pfile!) DO (
	(Set "wcmdline=%%A")
	(Set /A linecnt+=1)
	If !linecnt! GTR !linemax! Goto lineend
)
If !linecnt! LEQ %~2 (
	Call :errMsg "Zeilen-Nummer ist groesser als Anzahl der vorhandenen Zeilen." 0D
	Exit /B 5
)
:lineend
Call :message "Eingelesene Parameter: !wcmdline!"

REM Wenn -f oder --force-delete in Datei gefunden wurde, muß abgebrochen weden.
Echo !wcmdline!| findstr /R "\-f\>" > NUL
If !ERRORLEVEL! EQU 0 (
	Call :errMsg "Parameter -f darf nicht in einer Parameter-Datei verwendet werden" 0D
	Exit /B 10
)
Call !prgname! !wcmdline!
Exit /B !ERRORLEVEL!

REM ----------------------------------------------------------------------
REM Subroutinen aus externer Bibliothek aufrufen
:libInit
:checkBG
:getConLines
:pgptest
:message
:errMsg
:usage80
:escape
funclib.cmd %*
Exit /B

REM ENDE
