/**************************************************************************************************************************
 *                                                    Bind Pressed                                                      *
 **************************************************************************************************************************/

void BindPress(int iClient, int iBindNumber)
{
	if(RunClientChecks(iClient) == false)
		return;

	// xpm_debug_logging 3 (VERBOSE) traces every bind press that reaches this
	// point with the state it was dispatched against; xpm_debug_logging 1
	// (ERRORS) is enough to catch the "no case matched" desync warnings below.
	DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] %N (client %d) Bind%d - Team=%d ChosenSurvivor=%d InfectedChar=%d TalentsConfirmed=%d",
		iClient, iClient, iBindNumber, g_iClientTeam[iClient], g_iChosenSurvivor[iClient], g_iInfectedCharacter[iClient], g_bTalentsConfirmed[iClient]);

	if(g_bTalentsConfirmed[iClient] == false)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You must confirm your talents before using binds.");
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] %N Bind%d blocked - talents not confirmed.", iClient, iBindNumber);
		return;
	}

	if(!IsPlayerAlive(iClient))
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You cannot use binds while you are dead.");
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] %N Bind%d blocked - not alive.", iClient, iBindNumber);
		return;
	}

	if(GetEntData(iClient, g_iOffset_IsGhost, 1) == 1)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You cannot use binds while your a ghost.");
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] %N Bind%d blocked - is a ghost.", iClient, iBindNumber);
		return;
	}

	if(g_bGameFrozen == true)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You must wait till the game is unfrozen before using binds.");
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] %N Bind%d blocked - game frozen.", iClient, iBindNumber);
		return;
	}

	if(g_bFrozenByTank[iClient] == true)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You cannot use binds while frozen.");
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] %N Bind%d blocked - frozen by Tank.", iClient, iBindNumber);
		return;
	}

	// Louis's TIME OUT bind 2, temporarily disable infected binds
	if(g_bInfectedBindsDisabled == true && g_iClientTeam[iClient] == TEAM_INFECTED)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04The Infected have been hacked. All Binds are corrupt.");
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] %N Bind%d blocked - infected binds disabled.", iClient, iBindNumber);
		return;
	}

	if(g_iClientTeam[iClient] == TEAM_SURVIVORS)
	{
		switch(g_iChosenSurvivor[iClient])
		{
			case BILL:		iBindNumber == 1 ? Bind1Press_Bill(iClient) 	: Bind2Press_Bill(iClient);
			case ROCHELLE:	iBindNumber == 1 ? Bind1Press_Rochelle(iClient)	: Bind2Press_Rochelle(iClient);
			case COACH:		iBindNumber == 1 ? Bind1Press_Coach(iClient) 	: Bind2Press_Coach(iClient);
			case ELLIS:		iBindNumber == 1 ? Bind1Press_Ellis(iClient) 	: Bind2Press_Ellis(iClient);
			case NICK:		iBindNumber == 1 ? Bind1Press_Nick(iClient) 	: Bind2Press_Nick(iClient);
			case LOUIS:		iBindNumber == 1 ? Bind1Press_Louis(iClient) 	: Bind2Press_Louis(iClient);
			case ZOEY:		iBindNumber == 1 ? Bind1Press_Zoey(iClient) 	: Bind2Press_Zoey(iClient);
			// Should be unreachable once SyncInfectedClassSlotFromCurrent/NativeSurvivorCharToXPMod
			// (Events_Main.sp) have run - if this fires, g_iChosenSurvivor desynced from the
			// survivor model the player is actually spawned as, and the bind silently no-ops.
			default:		DebugLog(DEBUG_MODE_ERRORS, "[XPMod Bind] %N pressed Bind%d but has no recognized survivor class (g_iChosenSurvivor=%d) - dispatch skipped.", iClient, iBindNumber, g_iChosenSurvivor[iClient]);
		}
	}
	else if(g_iClientTeam[iClient] == TEAM_INFECTED)
	{
		switch(g_iInfectedCharacter[iClient])
		{
			case SMOKER:	iBindNumber == 1 ? Bind1Press_Smoker(iClient) 	: Bind2Press_Smoker(iClient);
			case BOOMER:	iBindNumber == 1 ? Bind1Press_Boomer(iClient) 	: Bind2Press_Boomer(iClient);
			case HUNTER:	iBindNumber == 1 ? Bind1Press_Hunter(iClient) 	: Bind2Press_Hunter(iClient);
			case SPITTER:	iBindNumber == 1 ? Bind1Press_Spitter(iClient) 	: Bind2Press_Spitter(iClient);
			case JOCKEY:	iBindNumber == 1 ? Bind1Press_Jockey(iClient) 	: Bind2Press_Jockey(iClient);
			case CHARGER:	iBindNumber == 1 ? Bind1Press_Charger(iClient) 	: Bind2Press_Charger(iClient);
			// Should be unreachable once SyncInfectedClassSlotFromCurrent (Events_Main.sp) has
			// run - if this fires, g_iInfectedCharacter desynced from the SI class the player is
			// actually playing (e.g. Tank/Witch, or a stale value from before their last spawn).
			default:		DebugLog(DEBUG_MODE_ERRORS, "[XPMod Bind] %N pressed Bind%d but has no recognized infected class (g_iInfectedCharacter=%d) - dispatch skipped.", iClient, iBindNumber, g_iInfectedCharacter[iClient]);
		}
	}
	else
	{
		DebugLog(DEBUG_MODE_ERRORS, "[XPMod Bind] %N pressed Bind%d while on team %d (not Survivors/Infected) - dispatch skipped.", iClient, iBindNumber, g_iClientTeam[iClient]);
	}
}

Action Bind1Press(int iClient, int args)
{
	// Confirms the client command actually reached the server - if this line never
	// shows up in the log for a player who says "my bind doesn't work", the problem
	// is client-side (no key bound to xpmbind1/sm_xpmod_bind1, or the key is shadowed
	// by a conflicting client bind) rather than anything server-side.
	DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] xpmbind1 command received from %N (client %d)", iClient, iClient);

	// Handle Pressing the bind
	BindPress(iClient, 1);

	return Plugin_Handled;
}


Action Bind2Press(int iClient, int args)
{
	DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] xpmbind2 command received from %N (client %d)", iClient, iClient);

	// Handle Pressing the bind
	BindPress(iClient, 2);

	return Plugin_Handled;
}

/**************************************************************************************************************************
 *                                                  Chat Fallback Commands                                                *
 **************************************************************************************************************************/

// Lets players trigger a bind by typing in chat (!skill1/!skill2, or !bind1/!bind2) instead of
// needing a working keybind at all - useful whenever a client-side key conflict (see
// RegisterBindCommandAlias above) or an unfamiliar config is the reason "the bind doesn't work".
// Called from SayCmd/SayTeamCmd (Events_Main.sp) with the first word of the chat message.
// Goes through the exact same BindPress() validation as a real keybind - no separate/weaker path.
bool ChatBindFallback(int iClient, const char[] strArgument1)
{
	if(StrEqual(strArgument1, "!skill1", false) || StrEqual(strArgument1, "skill1", false) ||
		StrEqual(strArgument1, "!bind1", false) || StrEqual(strArgument1, "bind1", false))
	{
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] !skill1 chat fallback used by %N (client %d)", iClient, iClient);
		BindPress(iClient, 1);
		return true;
	}

	if(StrEqual(strArgument1, "!skill2", false) || StrEqual(strArgument1, "skill2", false) ||
		StrEqual(strArgument1, "!bind2", false) || StrEqual(strArgument1, "bind2", false))
	{
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod Bind] !skill2 chat fallback used by %N (client %d)", iClient, iClient);
		BindPress(iClient, 2);
		return true;
	}

	return false;
}

/**************************************************************************************************************************
 *                                              Rebindable Command Aliases                                                *
 **************************************************************************************************************************/

// Registers strCommand (read from hCVar) as an EXTRA client command that dispatches
// to the same bind callback as the always-on default ("xpmbind1"/"xpmbind2"). Never
// unregisters anything - SourceMod has no native to do that - so old commands (and
// old client binds pointing at them) keep working even after this cvar changes.
void RegisterBindCommandAlias(ConVar hCVar, const char[] strDefaultName, ConCmd callback, int iBindNumber)
{
	char strCommand[64];
	hCVar.GetString(strCommand, sizeof(strCommand));
	TrimString(strCommand);

	// Empty, or same as the default that's already registered unconditionally - nothing to add
	if(strCommand[0] == '\0' || StrEqual(strCommand, strDefaultName, false))
		return;

	if(CommandExists(strCommand))
	{
		LogError("[XPMod] sm_xpmod_bind%d ('%s') was not registered - that command name is already in use (built-in engine command or another plugin). Bind%d is still reachable via '%s'.",
			iBindNumber, strCommand, iBindNumber, strDefaultName);
		return;
	}

	char strDescription[96];
	FormatEx(strDescription, sizeof(strDescription), "XPMod Ability Bind %d (alias set via sm_xpmod_bind%d)", iBindNumber, iBindNumber);
	RegConsoleCmd(strCommand, callback, strDescription);

	LogMessage("[XPMod] Registered '%s' as an additional client command for Bind %d (default '%s' is still active too).", strCommand, iBindNumber, strDefaultName);
}
