(*
code to find all elements on iTunes page, for use with "verifyPage()"

tell application "System Events"
	set elementCount to count of every UI element of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
	set everyElement to every UI element of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
	
	set everyProperty to {}
	repeat with loopCounter from 1 to (count of items in everyElement)
		try
			set everyProperty to everyProperty & 1
			set item loopCounter of everyProperty to (properties of item loopCounter of everyElement)
		end try
	end repeat
	
	set everyTitle to {}
	repeat with loopCounter from 1 to (count of items in everyProperty)
		set everyTitle to everyTitle & ""
		try
			set item loopCounter of everyTitle to (title of item loopCounter of everyProperty)
		end try
	end repeat
	
end tell

*)

--TO DO:

--write itunes running check
--write file output section for account status column
--write check for account status of "completed" or "skipped"

--Global Vars

--Used for storing a list of encountered errors. Written to by various handlers, read by checkForErrors()
global errorList
set errorList to {}

--Used for controlling the running or abortion of the script. Handler will run as long as scriptAction is "Continue". Can also be set to "Abort" to end script, or "Skip User" to skip an individual user.
global scriptAction
set scriptAction to "Continue"

--Store the current user number (based off line number in CSV file)
global currentUser
set currentUserNumber to 0

--Used for completing every step in the process, except actually creating the Apple ID. Also Pauses the script at various locations so the user can verify everything is working properly.
property dryRun : true

--Used to store the file location of the iBooks "App Page Shortcut". Updated dynamically on run to reference a child folder of the .app bundle (Yes, I know this isn't kosher)
property ibooksLinkLocation : "OSX_DATA:Users:greg:Desktop:iBooks Link.inetloc"

--Master delay timer for slowing the script down at specified sections. Usefull for tweaking the entire script's speed
property masterDelay : 1

--Maximum time (in seconds) the script will wait for a page to load before giving up and throwing an error
property netDelay : 30

--Used at locations in script that will be vulnerable to slow processing. Multiplied by master delay. Tweak for slow machines. May be added to Net Delay.
property processDelay : 1

--Used to store supported iTunes versions
property supportedItunesVersions : {"10.6"}

(*
	Email
	Password
	Secret Question
	Secret Answer
	Month Of Birth
	Day Of Birth
	Year Of Birth
	First Name
	Last Name
	Address Street
	Address City
	Address State
	Address Zip
	Phone Area Code
	Phone Number
*)

--Properties for storing possible headers to check the source CSV file for. Source file will be checked for each of the items to locate the correct columns
property emailHeaders : {"Email", "Email Address"}
property passwordHeaders : {"Password", "Pass"}
property secretQuestionHeaders : {"Secret Question", "Question"}
property secretAnswerHeaders : {"Secret Answer", "Answer"}
property monthOfBirthHeaders : {"Month", "Birth Month", "Month of Birth"}
property dayOfBirthHeaders : {"Day", "Birth Day", "Day Of Birth"}
property yearOfBirthHeaders : {"Year", "Birth Year", "Year Of Birth"}
property firstNameHeaders : {"First Name", "First", "fname"}
property lastNameHeaders : {"Last Name", "Last", "lname"}
property addressStreetHeaders : {"Street", "Street Address"}
property addressCityHeaders : {"City"}
property addressStateHeaders : {"State"}
property addressZipHeaders : {"Zip Code", "Zip"}
property phoneAreaCodeHeaders : {"Area Code"}
property phoneNumberHeaders : {"Phone Number", "Phone"}
property accountStatusHeaders : {"Account Status"} --Used to keep track of what acounts have been created


set userDroppedFile to false

--Check to see if a file was dropped on this script
on open droppedFile
	set userDroppedFile to true
	MainMagic(userDroppedFile, droppedFile)
end open

--Launch the script in interactive mode if no file was dropped (if file was dropped on script, this will never be run, because of the "on open" above)
set droppedFile to ""
MainMagic(userDroppedFile, droppedFile)

on MainMagic(userDroppedFile, droppedFile)
	--CHECK ITUNES SUPPORT-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------CHECK ITUNES SUPPORT--
	
	set itunesVersion to version of application "iTunes"
	set itunesVersionIsSupported to false
	
	repeat with versionCheckLoopCounter from 1 to (count of items in supportedItunesVersions)
		if item versionCheckLoopCounter of supportedItunesVersions is equal to itunesVersion then
			set itunesVersionIsSupported to true
			exit repeat
		end if
	end repeat
	
	if itunesVersionIsSupported is false then
		set scriptAction to button returned of (display dialog "iTunes is at version " & itunesVersion & return & return & "It is unknown if this version of iTunes will work with this script." & return & return & "You may abort now, or try running the script anyway." buttons {"Abort", "Continue"} default button "Abort") as text
	end if
	
	if scriptAction is "Continue" then
		--LOAD USERS FILE-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------LOAD USERS FILE--
		
		set usersFile to loadUsersFile(userDroppedFile, droppedFile) --Load the users file. Returns a list of columns from the source file
		
		if scriptAction is "Continue" then
			--Split out header information from each of the columns
			set headers to {}
			repeat with headerRemoverLoopCounter from 1 to (count of items in usersFile)
				set headers to headers & "" --Add an empty item to headers
				set item headerRemoverLoopCounter of headers to item 1 of item headerRemoverLoopCounter of usersFile --Save the header from the column
				set item headerRemoverLoopCounter of usersFile to (items 2 thru (count of items in usersFile) of item headerRemoverLoopCounter of usersFile) --Remove the header from the column
			end repeat
			
			set userCount to (count of items in item 1 of usersFile) --Counts the number of users
			
			--seperated column contents (not really necessarry, but it makes everything else a whole lot more readable)
			set appleIdEmailColumnContents to item 1 of usersFile
			set appleIdPasswordColumnContents to item 2 of usersFile
			
			set appleIdSecretQuestionColumnContents to item 3 of usersFile
			set appleIdSecretAnswerColumnContents to item 4 of usersFile
			set monthOfBirthColumnContents to item 5 of usersFile
			set dayOfBirthColumnContents to item 6 of usersFile
			set yearOfBirthColumnContents to item 7 of usersFile
			
			set userFirstNameColumnContents to item 8 of usersFile
			set userLastNameColumnContents to item 9 of usersFile
			set addressStreetColumnContents to item 10 of usersFile
			set addressCityColumnContents to item 11 of usersFile
			set addressStateColumnContents to item 12 of usersFile
			set addressZipColumnContents to item 13 of usersFile
			set phoneAreaCodeColumnContents to item 14 of usersFile
			set phoneNumberColumnContents to item 15 of usersFile
			set accountStatusColumnContents to item 16 of usersFile
			
			--PREP-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------PREP--
			
			--Ask user if they want to perform a dry run, and give them a chance to cancel
			set scriptRunMode to button returned of (display dialog "Would you like to preform a ''dry run'' of the script?" & return & return & "A ''dry run'' will run through every step, EXCEPT actually creating the Apple IDs." buttons {"Actually Create Apple IDs", "Dry Run", "Cancel"}) as text
			if scriptRunMode is "Actually Create Apple IDs" then set dryRun to false
			if scriptRunMode is "Dry Run" then set dryRun to true
			if scriptRunMode is "Cancel" then set scriptAction to "Abort"
			
			--CREATE IDS-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------CREATE IDS--
			if scriptAction is not "Abort" then
				set currentUserNumber to 0
				repeat with loopCounter from 1 to userCount
					
					--Increment our current user, just so other handlers can know what user we are on
					set currentUserNumber to currentUserNumber + 1
					
					--Get a single user's information from the column contents
					set appleIdEmail to item loopCounter of appleIdEmailColumnContents
					set appleIdPassword to item loopCounter of appleIdPasswordColumnContents
					
					set appleIdSecretQuestion to item loopCounter of appleIdSecretQuestionColumnContents
					set appleIdSecretAnswer to item loopCounter of appleIdSecretAnswerColumnContents
					set monthOfBirth to item loopCounter of monthOfBirthColumnContents
					set dayOfBirth to item loopCounter of dayOfBirthColumnContents
					set yearOfBirth to item loopCounter of yearOfBirthColumnContents
					
					set userFirstName to item loopCounter of userFirstNameColumnContents
					set userLastName to item loopCounter of userLastNameColumnContents
					set addressStreet to item loopCounter of addressStreetColumnContents
					set addressCity to item loopCounter of addressCityColumnContents
					set addressState to item loopCounter of addressStateColumnContents
					set addressZip to item loopCounter of addressZipColumnContents
					set phoneAreaCode to item loopCounter of phoneAreaCodeColumnContents
					set phoneNumber to item loopCounter of phoneNumberColumnContents
					set accountStatus to item loopCounter of accountStatusColumnContents
					
					set accountStatusSetByCurrentRun to {}
					
					installIbooks() ---------------------------------------------------------------------------------------------------------------------------------------------------------------------Go to the iBooks App page location to kick off Apple ID creation with no payment information
					
					delay 1 --Fix so iTunes is properly tested for, instead of just manually delaying
					
					GetItunesStatusUntillLcd("Does Not Match", "Accessing iTunes Store�", 4, "times. Check for:", 120, "intervals of", 0.25, "seconds") ------------------------Wait for iTunes to open (if closed) and the iBooks page to load
					
					SignOutItunesAccount() ---------------------------------------------------------------------------------------------------------------------------------------------------------Signout Apple ID that is currently signed in (if any)
					
					CheckForErrors() ------------------------------------------------------------------------------------------------------------------------------------------------------------------Checks for errors that may have been thrown by previous handler
					if scriptAction is "Abort" then exit repeat -----------------------------------------------------------------------------------------------------------------------------------If an error was detected and the user chose to abort, then end the script
					
					ClickCreateAppleIDButton() -----------------------------------------------------------------------------------------------------------------------------------------------------Click "create Apple ID" button on pop-up window
					ClickContinueOnPageOne() ------------------------------------------------------------------------------------------------------------------------------------------------------Click "Continue" on the page with the title "Welcome to the iTunes Store"
					CheckForErrors() ------------------------------------------------------------------------------------------------------------------------------------------------------------------Checks for errors that may have been thrown by previous handler
					if scriptAction is "Abort" then exit repeat -----------------------------------------------------------------------------------------------------------------------------------If an error was detected and the user chose to abort, then end the script
					
					AgreeToTerms() -------------------------------------------------------------------------------------------------------------------------------------------------------------------Check the "I have read and agreed" box and then the "Agree" button
					CheckForErrors() ------------------------------------------------------------------------------------------------------------------------------------------------------------------Checks for errors that may have been thrown by previous handler
					if scriptAction is "Abort" then exit repeat -----------------------------------------------------------------------------------------------------------------------------------If an error was detected and the user chose to abort, then end the script
					
					ProvideAppleIdDetails(appleIdEmail, appleIdPassword, appleIdSecretQuestion, appleIdSecretAnswer, monthOfBirth, dayOfBirth, yearOfBirth) ----------------Fills the first page of apple ID details. Birth Month is full text, like "January". Birth Day and Birth Year are numeric. Birth Year is 4 digit
					CheckForErrors() ------------------------------------------------------------------------------------------------------------------------------------------------------------------Checks for errors that may have been thrown by previous handler
					if scriptAction is "Abort" then exit repeat -----------------------------------------------------------------------------------------------------------------------------------If an error was detected and the user chose to abort, then end the script
					
					ProvidePaymentDetails(userFirstName, userLastName, addressStreet, addressCity, addressState, addressZip, phoneAreaCode, phoneNumber) -------------Fill payment details, without credit card info
					CheckForErrors() ------------------------------------------------------------------------------------------------------------------------------------------------------------------Checks for errors that may have been thrown by previous handler
					if scriptAction is "Abort" then exit repeat -----------------------------------------------------------------------------------------------------------------------------------If an error was detected and the user chose to abort, then end the script
					
					if scriptAction is "Continue" then ----------------------------------------------------------------------------------------------------------------------------------------------If user was successfully created...
						set accountStatusSetByCurrentRun to accountStatusSetByCurrentRun & ""
						set item loopCounter of accountStatusSetByCurrentRun to "Created" ----------------------------------------------------------------------------------------------Mark user as created
					end if
					
					if scriptAction is "Skip User" then ----------------------------------------------------------------------------------------------------------------------------------------------If a user was skipped...
						set accountStatusSetByCurrentRun to accountStatusSetByCurrentRun & ""
						set item loopCounter of accountStatusSetByCurrentRun to "Skipped" ----------------------------------------------------------------------------------------------Mark user as "Skipped"
						set scriptAction to "Continue" ----------------------------------------------------------------------------------------------------------------------------------------------Set the Script back to "Continue" mode
					end if
					
					if scriptAction is "Stop" then exit repeat
					
				end repeat
				
				--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------Display dialog boxes that confirm the exit status of the script
				
				if scriptAction is "Abort" then display dialog "Script was aborted"
				if scriptAction is "Stop" then display dialog "Dry run completed"
				if scriptAction is "Continue" then display dialog "Script Completed Successfully"
				
				
				--Fix for multiple positive outcomes
				if itunesVersionIsSupported is false then --If the script was run against an unsupported version of iTunes...
					if scriptAction is "Continue" then --�And it wasn't aborted...
						if button returned of (display dialog "Would you like to add iTunes Version " & itunesVersion & " to the list of supported iTunes versions?" buttons {"Yes", "No"} default button "No") is "Yes" then --...then ask the user if they want to add the current version of iTunes to the supported versions list
							set supportedItunesVersions to supportedItunesVersions & itunesVersion
							display dialog "iTunes version " & itunesVersion & " succesfully added to list of supported versions."
						end if
					end if
				end if
			end if
		end if
	end if
	-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------End main function
	
end MainMagic

(*_________________________________________________________________________________________________________________________________________*)

--FUNCTIONS-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------FUNCTIONS--

on loadUsersFile(userDroppedFile, chosenFile)
	if userDroppedFile is false then set chosenFile to "Choose"
	set readFile to ReadCsvFile(chosenFile) --Open the CSV file and read its raw contents
	set readFile to ParseCsvFile(readFile) --Parse the values into a list of lists
	
	set listOfColumnsToFind to {"Email", "Password", "Secret Question", "Secret Answer", "Month Of Birth", "Day Of Birth", "Year Of Birth", "First Name", "Last Name", "Address Street", "Address City", "Address State", "Address Zip", "Phone Area Code", "Phone Number", "Account Status"}
	
	--Locate the columns in the file
	set findResults to {}
	repeat with columnFindLoopCounter from 1 to (count of items in listOfColumnsToFind)
		set findResults to findResults & ""
		set item columnFindLoopCounter of findResults to findColumn((item columnFindLoopCounter of listOfColumnsToFind), readFile) --FindColumn Returns a list of two items. The first item is either "Found" or "Not Found". The second item (if the item was "found") will be a numerical reference to the column that was found, based on its position in the source file
	end repeat
	
	--Verify that the columns were found, and resolve any missing columns
	repeat with columnVerifyLoopCounter from 1 to (count of items in findResults)
		if scriptAction is "Continue" then
			if item 1 of item columnVerifyLoopCounter of findResults is "Found" then --Check if the current item to be located was found
				set item columnVerifyLoopCounter of findResults to item 2 of item columnVerifyLoopCounter of findResults --Remove the verification information and set the item to just the column number
			else --If a column is missing
				--Ask the user what they would like to do
				set missingColumnResolution to button returned of (display dialog "The script was unable to locate the " & item columnVerifyLoopCounter of listOfColumnsToFind & " column. The script cannot continue without this information." & return & return & "What would you like to do?" buttons {"Abort Script", "Manually Locate Column"}) as text
				
				--If the user chose to abort
				if missingColumnResolution is "Abort Script" then set scriptAction to "Abort"
				
				--If the user chose to manually locate the column
				if missingColumnResolution is "Manually Locate Column" then
					--Create a list of the columns to choose from, complete with a number at the beginning of each item in the list 
					set columnList to {}
					repeat with createColumnListLoopCounter from 1 to (count of items in readFile) --Each loop will create an entry in the list of choises corresponding to the first row of a column in the original source file
						set columnList to columnList & ((createColumnListLoopCounter as text) & " " & item 1 of item createColumnListLoopCounter of readFile) --Dynamically add an incremented number and space to the beginning of each item in the list of choices, and then add the contents of the first row of the column chosen for this loop
					end repeat
					
					--Present the list of column choices to the user
					set listChoice to choose from list columnList with prompt "Which of the items below is an example of ''" & item columnVerifyLoopCounter of listOfColumnsToFind & "''" --Ask user which of the choices matches what we are looking for
					if listChoice is false then --If the user clicked cancel in the list selection dialog box
						set scriptAction to "Abort"
					else
						set item columnVerifyLoopCounter of findResults to (the first word of listChoice as number) --Set the currently evaluating entry of findResults to the column NUMBER (determined by getting the first word of list choice, which corresponds to column numbers) the user selected
					end if
				end if
				
			end if
		else --If an abort has been thrown
			exit repeat
		end if
	end repeat
	
	--Retrieve the contents of the found columns
	if scriptAction is "Continue" then
		set fileContents to {}
		repeat with contentRetrievalLoopCounter from 1 to (count of items in findResults)
			set fileContents to fileContents & ""
			set item contentRetrievalLoopCounter of fileContents to getColumnContents((item contentRetrievalLoopCounter of findResults), readFile)
		end repeat
	end if
	
	if scriptAction is "Continue" then
		return fileContents
	end if
	
end loadUsersFile

on findColumn(columnToFind, fileContents)
	
	--BEGIN FIND EMAIL																							BEGIN FIND EMAIL
	if columnToFind is "Email" then
		return findInList(emailHeaders, fileContents)
	end if
	
	--BEGIN FIND PASSWORD																						BEGIN FIND PASSWORD
	if columnToFind is "Password" then
		return findInList(passwordHeaders, fileContents)
	end if
	
	--BEGIN FIND SECRET QUESTION																				BEGIN FIND SECRET QUESTION
	if columnToFind is "Secret Question" then
		return findInList(secretQuestionHeaders, fileContents)
	end if
	
	--BEGIN FIND SECRET ANSWER																					BEGIN FIND SECRET ANSWER
	if columnToFind is "Secret Answer" then
		return findInList(secretAnswerHeaders, fileContents)
	end if
	
	--BEGIN FIND BIRTH MONTH 																					BEGIN FIND BIRTH MONTH
	if columnToFind is "Month Of Birth" then
		return findInList(monthOfBirthHeaders, fileContents)
	end if
	
	--BEGIN FIND BIRTH DAY 																						BEGIN FIND BIRTH DAY
	if columnToFind is "Day Of Birth" then
		return findInList(dayOfBirthHeaders, fileContents)
	end if
	
	--BEGIN FIND BIRTH YEAR 																						BEGIN FIND BIRTH YEAR
	if columnToFind is "Year Of Birth" then
		return findInList(yearOfBirthHeaders, fileContents)
	end if
	
	--BEGIN FIND LAST NAME																						BEGIN FIND LAST NAME
	if columnToFind is "First Name" then
		return findInList(firstNameHeaders, fileContents)
	end if
	
	--BEGIN FIND LAST NAME																						BEGIN FIND LAST NAME
	if columnToFind is "Last Name" then
		return findInList(lastNameHeaders, fileContents)
	end if
	
	--BEGIN FIND ADDRESS STREET																				BEGIN FIND ADDRESS STREET
	if columnToFind is "Address Street" then
		return findInList(addressStreetHeaders, fileContents)
	end if
	
	--BEGIN FIND ADDRESS CITY																					BEGIN FIND ADDRESS CITY
	if columnToFind is "Address City" then
		return findInList(addressCityHeaders, fileContents)
	end if
	
	--BEGIN FIND ADDRESS STATE																					BEGIN FIND ADDRESS STATE
	if columnToFind is "Address State" then
		return findInList(addressStateHeaders, fileContents)
	end if
	
	--BEGIN FIND ADDRESS ZIP																					BEGIN FIND ADDRESS ZIP
	if columnToFind is "Address Zip" then
		return findInList(addressZipHeaders, fileContents)
	end if
	
	--BEGIN FIND PHONE AREA CODE																				BEGIN FIND PHONE AREA CODE
	if columnToFind is "Phone Area Code" then
		return findInList(phoneAreaCodeHeaders, fileContents)
	end if
	
	--BEGIN FIND PHONE NUMBER																					BEGIN FIND PHONE NUMBER
	if columnToFind is "Phone Number" then
		return findInList(phoneNumberHeaders, fileContents)
	end if
	
	--BEGIN FIND ACCOUNT STATUS																				BEGIN FIND ACCOUNT STATUS
	if columnToFind is "Account Status" then
		return findInList(accountStatusHeaders, fileContents)
	end if
	
end findColumn

-----------------------------------------

on findInList(matchList, listContents)
	try
		set findState to "Not Found"
		set findLocation to 0
		repeat with columnItemLoopCounter from 1 to (count of items of (item 1 of listContents))
			repeat with testForMatchLoopCounter from 1 to (count of matchList)
				if item columnItemLoopCounter of (item 1 of listContents) is item testForMatchLoopCounter of matchList then
					set findState to "Found"
					set findLocation to columnItemLoopCounter
					exit repeat
				end if
			end repeat
			if findState is "Found" then exit repeat
		end repeat
		return {findState, findLocation} as list
	on error
		display dialog "Hmm� Well, I was looking for something in the file, and something went wrong." buttons "Bummer"
		return 0
	end try
end findInList

-----------------------------------------

--BEGIN GET COLUMN CONTENTS																								BEGIN GET COLUMN CONTENTS	
on getColumnContents(columnToGet, fileContents)
	set columnContents to {}
	repeat with loopCounter from 1 to (count of items of fileContents)
		set columnContents to columnContents & 1
		set item loopCounter of columnContents to item columnToGet of item loopCounter of fileContents
	end repeat
	return columnContents
end getColumnContents

-----------------------------------------

on ReadCsvFile(chosenFile)
	--Check to see if we are being passed a method instead of a file to open
	set method to ""
	try
		if chosenFile is "Choose" then
			set method to "Choose"
		end if
	end try
	
	try
		if method is "Choose" then
			set chosenFile to choose file
		end if
		
		set fileOpened to (characters 1 thru -((count every item of (name extension of (info for chosenFile))) + 2) of (name of (info for chosenFile))) as string
		set testResult to TestCsvFile(chosenFile)
		
		if testResult is yes then
			set openFile to open for access chosenFile
			set fileContents to read chosenFile
			close access openFile
			return fileContents
		end if
		
	on error
		close access openFile
		display dialog "Something bjorked when oppening the file!" buttons "Well bummer"
		return {}
	end try
end ReadCsvFile

-----------------------------------------

on TestCsvFile(chosenFile)
	set chosenFileKind to type identifier of (info for chosenFile)
	if chosenFileKind is "CSV Document" then
		return yes
	else
		if chosenFileKind is "public.comma-separated-values-text" then
			return yes
		else
			display dialog "Silly " & (word 1 of the long user name of (system info)) & ", that file is not a .CSV!" buttons "Oops, my bad"
			return no
		end if
	end if
end TestCsvFile

-----------------------------------------

on ParseCsvFile(fileContents)
	try
		set parsedFileContents to {} --Instantiate our list to hold parsed file contents
		set delimitersOnCall to AppleScript's text item delimiters --Copy the delimiters that are in place when this handler was called
		set AppleScript's text item delimiters to "," --Set delimiter to commas
		
		--Parse each line (paragraph) from the unparsed file contents
		set lineCount to (count of paragraphs in fileContents)
		repeat with loopCounter from 1 to lineCount --Loop through each line in the file, one at a time
			set parsedFileContents to parsedFileContents & 1 --Add a new item to store the parsed paragraph
			set item loopCounter of parsedFileContents to (every text item of paragraph loopCounter of fileContents) --Parse a line from the file into individual items and store them in the item created above
		end repeat
		
		set AppleScript's text item delimiters to delimitersOnCall --Set Applescript's delimiters back to whatever they were when this handler was called
		return parsedFileContents --Return our fancy parsed contents
	on error
		display dialog "Woah! Um, that's not supposed to happen." & return & return & "Something goofed up bad when I tried to read the file!" buttons "Ok, I'll take a look at the file"
		return fileContents
	end try
end ParseCsvFile

-----------------------------------------

on verifyPage(expectedElementString, expectedElementLocation, expectedElementCount, verificationTimeout)
	tell application "System Events"
		
		set checkFrequency to 0.25 --How often (in seconds) the iTunes LCD will be check to see if iTunes is busy loading the page
		my GetItunesStatusUntillLcd("Does Not Match", "Accessing iTunes Store�", 4, "times. Check for:", (verificationTimeout * (1 / checkFrequency)), "intervals of", checkFrequency, "seconds")
		
		set elementCount to count of every UI element of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
		
		repeat with timeoutLoopCounter from 1 to verificationTimeout --Loop will be ended before reaching verificationTimeout if the expectedElementString is successfully located
			if timeoutLoopCounter is equal to verificationTimeout then return "unverified"
			
			if expectedElementCount is 0 then set expectedElementCount to elementCount --Use 0 to disable element count verification
			
			if elementCount is equal to expectedElementCount then
				set everyTitle to {}
				
				set elementToTest to UI element expectedElementLocation of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
				
				set elementProperties to properties of elementToTest
				
				try
					set elementString to title of elementProperties
					set elementString to (text items 1 through (count of text items in expectedElementString) of elementString) as string
				end try
				if elementString is equal to expectedElementString then
					return "verified"
				end if
			end if
			delay 1
		end repeat
	end tell
end verifyPage

-----------------------------------------

on CheckForErrors()
	if scriptAction is "Continue" then --This is to make sure a previous abort hasn't already been thrown.
		if errorList is not {} then --If there are errors in the list
			
			set errorAction to button returned of (display dialog "Errors were detected. What would you like to do?" buttons {"Abort", "Skip User", "Review"} default button "Review") as string
			
			if errorAction is "Abort" then
				set scriptAction to "Abort" --This sets the global abort action
				return "Abort" --This breaks out of the remainder of the error checker
			end if
			
			if errorAction is "Review" then
				repeat with loopCounter from 1 to (count of items in errorList) --Cycle through all the errors in the list
					if errorAction is "Abort" then
						set scriptAction to "Abort" --This sets the global abort action
						return "Abort" --This breaks out of the remainder of the error checker
					else
						set errorAction to button returned of (display dialog "Showing error " & loopCounter & " of " & (count of items in errorList) & ":" & return & return & item loopCounter of errorList & return & return & "What would you like to do?" buttons {"Abort", "Manually Correct"} default button "Manually Correct") as string
						if errorAction is "Manually Correct" then set errorAction to button returned of (display dialog "Click continue when the error has been corrected." & return & "If you cannot correct the error, then you may skip this user or abort the entire script" buttons {"Abort", "Skip User", "Continue"} default button "Continue") as string
					end if
				end repeat
				set errorList to {} --Clear errors if we've made it all the way through the loops
				set scriptAction to errorAction
			end if
			
		end if --for error check
	end if --for abort check
end CheckForErrors

-----------------------------------------

on SignOutItunesAccount()
	if scriptAction is "Continue" then --This is to make sure an abort hasn't been thrown
		tell application "System Events"
			set storeMenuItems to title of every menu item of menu 1 of menu bar item "Store" of menu bar 1 of application process "iTunes"
		end tell
		
		repeat with loopCounter from 1 to (count of items in storeMenuItems)
			if item loopCounter of storeMenuItems is "Sign Out" then
				tell application "System Events"
					click menu item "Sign Out" of menu 1 of menu bar item "Store" of menu bar 1 of application process "iTunes"
				end tell
			end if
		end repeat
	end if
end SignOutItunesAccount

-----------------------------------------

on GetItunesStatusUntillLcd(matchType, stringToMatch, matchDuration, "times. Check for:", checkDuration, "intervals of", checkFrequency, "seconds")
	set loopCounter to 0
	set matchedFor to 0
	set itunesLcdText to {}
	
	repeat
		set loopCounter to loopCounter + 1
		
		if loopCounter is greater than or equal to (checkDuration * checkFrequency) then
			return "Unmatched"
		end if
		
		set itunesLcdText to itunesLcdText & ""
		tell application "System Events"
			try
				set item loopCounter of itunesLcdText to value of static text 1 of scroll area 1 of window 1 of application process "iTunes"
			end try
		end tell
		
		if matchType is "Matches" then
			if item loopCounter of itunesLcdText is stringToMatch then
				set matchedFor to matchedFor + 1
			else
				set matchedFor to 0
			end if
		end if
		
		if matchType is "Does Not Match" then
			if item loopCounter of itunesLcdText is not stringToMatch then
				set matchedFor to matchedFor + 1
			else
				set matchedFor to 0
			end if
		end if
		
		if matchedFor is greater than or equal to matchDuration then
			return "Matched"
		end if
		delay checkFrequency
	end repeat
	
end GetItunesStatusUntillLcd

-----------------------------------------

on installIbooks()
	if scriptAction is "Continue" then --This is to make sure an abort hasn't been thrown
		
		tell application "Finder"
			open file ibooksLinkLocation
		end tell
		
		set pageVerification to verifyPage("iBooks", 2, 0, netDelay) --Looking for "iBooks", in the second element, on a page with an element count of 96, with a timeout of 5
		
		if pageVerification is "verified" then --Actually click the button to obtain iBooks
			tell application "System Events"
				try
					if description of button 1 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" is "Free App, iBooks" then
						click button 1 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
					else
						set errorList to errorList & "Unable to locate install app button by its description."
					end if
				on error
					set errorList to errorList & "Unable to locate install app button by its description."
				end try
			end tell
			set pageVerification to ""
		else --Throw error if page didn't verify
			set errorList to errorList & "Unable to verify that iTunes is open at the iBooks App Store Page."
		end if
		
	end if
end installIbooks

-----------------------------------------

on ClickCreateAppleIDButton()
	if scriptAction is "Continue" then --This is to make sure an abort hasn't been thrown
		--Verification text for window:
		--get value of static text 1 of window 1 of application process "iTunes" --should be equal to "Sign In to download from the iTunes Store"
		tell application "System Events"
			if value of static text 1 of window 1 of application process "iTunes" is "Sign In to download from the iTunes Store" then
				try
					click button "Create Apple ID" of window 1 of application process "iTunes"
				on error
					set errorList to errorList & "Unable to locate and click button ''Create Apple ID'' on ID sign-in window"
				end try
			else
				set errorList to errorList & "Unable to locate sign-in window and click ''Create Apple ID''"
			end if
		end tell
	end if
end ClickCreateAppleIDButton

-----------------------------------------

on ClickContinueOnPageOne()
	
	set pageVerification to verifyPage("Welcome to the iTunes Store", 2, 12, netDelay) ----------Verify we are at page 1 of the Apple ID creation page
	
	if pageVerification is "verified" then
		
		try
			tell application "System Events"
				if title of button 2 of group 2 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" is "Continue" then
					click button 2 of group 2 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
				else
					set errorList to errorList & "Unable to locate and click the Continue button on page ''Welcome to iTunes Store''."
				end if
			end tell
		on error
			set errorList to errorList & "Unable to locate and click the Continue button on page ''Welcome to iTunes Store''."
		end try
		
		set pageVerification to ""
	else
		set errorList to errorList & "Unable to verify that iTunes is open at the first page of the Apple ID creation process."
	end if
end ClickContinueOnPageOne

-----------------------------------------

on AgreeToTerms()
	
	set pageVerification to verifyPage("Terms and Conditions and Apple Privacy Policy", 2, 15, netDelay) ----------Verify we are at page 1 of the Apple ID creation page
	
	if pageVerification is "verified" then
		tell application "System Events"
			
			--Check box
			try
				set buttonVerification to title of checkbox 1 of group 5 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
				if buttonVerification is "I have read and agree to these terms and conditions." then
					click checkbox 1 of group 5 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
				else
					set errorList to errorList & "Unable to locate and check box ''I have read and agree to these terms and conditions.''"
				end if
			on error
				set errorList to errorList & "Unable to locate and check box ''I have read and agree to these terms and conditions.''"
			end try
			
			delay (masterDelay * processDelay) --We need to pause a second for System Events to realize we have checked the box
			my CheckForErrors()
			
			
			if scriptAction is "Continue" then
				try
					set buttonVerification to title of button 3 of group 6 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
					if buttonVerification is "Agree" then
						click button 3 of group 6 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
					else
						set errorList to errorList & "Unable to locate and click button ''Agree''."
					end if
				on error
					set errorList to errorList & "Unable to locate and click button ''Agree''."
				end try
			else
				set errorList to errorList & "Unable to locate and click button ''Agree''."
			end if
			
		end tell
	end if
	
end AgreeToTerms

-----------------------------------------

on ProvideAppleIdDetails(appleIdEmail, appleIdPassword, appleIdSecretQuestion, appleIdSecretAnswer, userBirthMonth, userBirthDay, userBirthYear)
	if scriptAction is "Continue" then --This is to make sure an abort hasn't been thrown
		
		set pageVerification to verifyPage("Provide Apple ID Details", 2, 0, netDelay)
		
		if pageVerification is "Verified" then
			tell application "System Events"
				-----------
				try
					set focused of text field 1 of group 3 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
					set value of text field 1 of group 3 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to appleIdEmail --Set email address
					if value of text field 1 of group 3 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" is not appleIdEmail then
						set errorList to errorList & "Unable to fill ''Email'' field."
					end if
				on error
					set errorList to errorList & "Unable to fill ''Email'' field."
				end try
				-----------
				try
					set frontmost of application process "iTunes" to true --Verify that iTunes is the front window before performking keystroke event
					set focused of text field 1 of group 2 of group 4 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
					keystroke appleIdPassword --Set Password. Must use keystroke instead of "set value" because page checks for keyboard input for this field
					--Password field cannot be verified because it is a secure text field
				on error
					set errorList to errorList & "Unable to fill ''Password'' field."
				end try
				-----------
				try
					set frontmost of application process "iTunes" to true --Verify that iTunes is the front window before performking keystroke event
					set focused of text field 1 of group 4 of group 4 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
					keystroke appleIdPassword --Confirm Password.  Must use keystroke instead of "set value" because page checks for keyboard input for this field
					--Password Verification field cannot be verified because it is a secure text field
				on error
					set errorList to errorList & "Unable to fill ''Password Verification'' field."
				end try
				-----------
				try
					set focused of text field 1 of group 6 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
					set value of text field 1 of group 6 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to appleIdSecretQuestion --Set Secret Question
					if value of text field 1 of group 6 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" is not appleIdSecretQuestion then
						set errorList to errorList & "Unable to fill ''Secret Question'' field."
					end if
				on error
					set errorList to errorList & "Unable to fill ''Secret Question'' field."
				end try
				-----------
				try
					set focused of text field 1 of group 1 of group 7 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
					set value of text field 1 of group 1 of group 7 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to appleIdSecretAnswer --Set Secret Answer
					if value of text field 1 of group 1 of group 7 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" is not appleIdSecretAnswer then
						set errorList to errorList & "Unable to fill ''Secret Answer'' field."
					end if
				on error
					set errorList to errorList & "Unable to fill ''Secret Answer'' field."
				end try
				-----------
				try
					set frontmost of application process "iTunes" to true --Verify that iTunes is the front window before performking keystroke event
					set focused of pop up button 1 of group 1 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
					delay 0.5
					keystroke userBirthMonth
					if value of pop up button 1 of group 1 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" is not userBirthMonth then
						set errorList to errorList & "Unable to set ''Month''."
					end if
				on error
					set errorList to errorList & "Unable to set ''Month''."
				end try
				-----------
				try
					set birthDayField to ""
					set birthDaySetAttempt to 0
					repeat until birthDayField is userBirthDay --Repeat because Apple, in their infinite wisdom, decided on some bizzarre method for picking the value with keystroke
						
						set birthDaySetAttempt to birthDaySetAttempt + 1 --Count how many times we have tried to set the birth day
						if birthDaySetAttempt is greater than 31 then --Since there are a maximum of 31 days in a month, if we have tried more than 31 times to set the day then we should have tried every possibility
							errorList to errorList & "Unable to set ''Day'' field."
							exit repeat --Break out of day setting loop
						end if
						
						set frontmost of application process "iTunes" to true --Verify that iTunes is the front window before performking keystroke event
						set focused of pop up button 1 of group 2 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
						delay 0.5
						keystroke userBirthDay
						set birthDayField to value of pop up button 1 of group 2 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
					end repeat
				on error
					errorList to errorList & "Unable to set ''Day'' field."
				end try
				-----------
				try
					set focused of text field 1 of group 3 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
					set value of text field 1 of group 3 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to userBirthYear --Type year
					if value of text field 1 of group 3 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" is not userBirthYear then
						set errorList to errorList & "Unable to set ''Year'' field."
					end if
				on error
					set errorList to errorList & "Unable to set ''Year'' field."
				end try
				-----------
				try
					click checkbox 1 of group 11 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" --Uncheck psuedo-spam
				on error
					set errorList to errorList & "Unable to uncheck ''New Releases'' email option box."
				end try
				-----------
				try
					click checkbox 1 of group 12 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" --Uncheck psuedo-spam
				on error
					set errorList to errorList & "Unable to uncheck ''News and Special Offers'' email option box."
				end try
				-----------
				
				my CheckForErrors() --Check for errors before continuing to the next page
				
				if dryRun is true then
					set dryRunSucess to button returned of (display dialog "Did everything fill in properly?" buttons {"Yes", "No"}) as text
					if dryRunSucess is "No" then
						set scriptAction to button returned of (display dialog "What would you like to do?" buttons {"Abort", "Continue"}) as text
					end if
				end if
				
				if scriptAction is "Continue" then
					try
						click button 3 of group 13 of UI element 1 of scroll area 3 of window 1 of application process "iTunes"
					on error
						set errorList to errorList & "Unable to click ''Continue'' button."
					end try
				end if
			end tell
		else --(If page didn't verify)
			set errorList to errorList & "Unable to verify that the ''Provide Apple ID Details'' page is open and fill its contents."
		end if
	end if
end ProvideAppleIdDetails

on ProvidePaymentDetails(userFirstName, userLastName, addressStreet, addressCity, addressState, addressZip, phoneAreaCode, phoneNumber)
	if scriptAction is "Continue" then --This is to make sure an abort hasn't been thrown
		set pageVerification to verifyPage("Provide a Payment Method", 2, 0, netDelay)
		
		if pageVerification is "Verified" then
			tell application "System Events"
				click button 1 of group 6 of list 1 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" --Click payment type "none"
			end tell
		end if
		
		--Wait for the page to change after selecting payment type
		set checkFrequency to 0.25 --How often (in seconds) the iTunes LCD will be checked to see if iTunes is busy loading the page
		GetItunesStatusUntillLcd("Does Not Match", "Accessing iTunes Store�", 4, "times. Check for:", (netDelay * (1 / checkFrequency)), "intervals of", checkFrequency, "seconds")
		
		tell application "System Events"
			try
				set frontmost of application process "iTunes" to true --Verify that iTunes is the front window before performking keystroke event
				set focused of pop up button 1 of group 1 of group 8 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
				keystroke "Dr"
			on error
				set errorList to errorList & "Unable to set ''Title'' to ''Dr.''"
			end try
			-----------
			try
				set value of text field 1 of group 1 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to userFirstName
			on error
				set errorList to errorList & "Unable to set ''First Name'' field to " & userFirstName
			end try
			-----------
			try
				set value of text field 1 of group 2 of group 9 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to userLastName
			on error
				set errorList to errorList & "Unable to set ''Last Name'' field to " & userLastName
			end try
			-----------
			try
				set value of text field 1 of group 1 of group 10 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to addressStreet
			on error
				set errorList to errorList & "Unable to set ''Street Address'' field to " & addressStreet
			end try
			-----------
			try
				set value of text field 1 of group 1 of group 11 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to addressCity
			on error
				set errorList to errorList & "Unable to set ''City'' field to " & addressCity
			end try
			-----------
			try
				set frontmost of application process "iTunes" to true --Verify that iTunes is the front window before performking keystroke event
				set focused of pop up button 1 of group 2 of group 11 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to true
				keystroke addressState
			on error
				set errorList to errorList & "Unable to set ''State'' drop-down to " & addressState
			end try
			-----------
			try
				set value of text field 1 of group 3 of group 11 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to addressZip
			on error
				set errorList to errorList & "Unable to set ''Zip Code'' field to " & addressZip
			end try
			-----------
			try
				set value of text field 1 of group 1 of group 12 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to phoneAreaCode
			on error
				set errorList to errorList & "Unable to set ''Area Code'' field to " & phoneAreaCode
			end try
			-----------
			try
				set value of text field 1 of group 2 of group 12 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" to phoneNumber
			on error
				set errorList to errorList & "Unable to set ''Phone Number'' field to " & phoneNumber
			end try
			-----------
			
			my CheckForErrors()
			
			if dryRun is true then --Pause to make sure all the fields filled properly
				set dryRunSucess to button returned of (display dialog "Did everything fill in properly?" buttons {"Yes", "No"}) as text
				if dryRunSucess is "No" then
					set scriptAction to button returned of (display dialog "What would you like to do?" buttons {"Abort", "Continue"}) as text
				end if
			end if
			
			if dryRun is false then --Click the "Create Apple ID" button as long as we aren't in "Dry Run" mode
				if scriptAction is "Continue" then --Continue as long as no errors occurred
					try
						click button 3 of group 14 of UI element 1 of scroll area 3 of window 1 of application process "iTunes" --Click button to create Apple ID
					on error
						set errorList to errorList & "Unable to click ''Create Apple ID'' button."
					end try
				end if --End "Continue if no errors" statement
			else --If we are doing a dry run then...
				set dryRunChoice to button returned of (display dialog "Completed. Would you like to stop the script now, continue ''dry running'' with the next user in the CSV (if applicable), or run the script ''for real'' starting with the first user?" buttons {"Stop Script", "Continue Dry Run", "Run ''For Real''"}) as text
				if dryRunChoice is "Stop Script" then set scriptAction to "Stop"
				if dryRunChoice is "Run ''For Real''" then
					set currentUserNumber to 0
					set dryRun to false
				end if
			end if --End "dry Run" if statement
			
		end tell --End "System Events" tell
	end if --End main error check IF
end ProvidePaymentDetails