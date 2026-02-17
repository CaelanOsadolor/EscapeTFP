return {
	DATA_STORE              = "TopSpeed" , --< OrderedDataStore for leaderboard ranking (separate from PlayerData_V1)
	LEADERBOARD_UPDATE      = 1 , --< How often you want the leaderboard to update in minutes (no less than 1) 
	NAME_OF_STAT            = "Speed" , --< Stat name to save in the database
	USE_LEADERSTATS         = false, --< Speed is an attribute, not in leaderstats
	NAME_LEADERSTATS        = "Speed", --< Not used since USE_LEADERSTATS is false
	SHOW_1ST_PLACE_AVATAR   = true,
	DO_DEBUG                = false , --< Should it debug (print) messages to the console?
}
