return {
	DATA_STORE              = "TopWins" , --< OrderedDataStore for leaderboard ranking (separate from PlayerData_v1)
	LEADERBOARD_UPDATE      = 1 , --< How often you want the leaderboard to update in minutes (no less than 1) 
	NAME_OF_STAT            = "Wins" , --< Stat name to save in the database
	USE_LEADERSTATS         = true, --< Should use the Roblox built-in Leaderboard system too?
	NAME_LEADERSTATS        = "Wins", --< What the name of the Leaderboard to use?
	SHOW_1ST_PLACE_AVATAR   = true,
	DO_DEBUG                = false , --< Should it debug (print) messages to the console?
}
