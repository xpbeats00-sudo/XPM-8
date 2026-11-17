//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////     Special Infected Class Cap + Reroll (max 2 of a kind)     ////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Enforces a maximum number of players simultaneously live as any one Special Infected
// class (e.g. no more than 2 Spitters at once), and gives a human player a way to
// voluntarily reroll their upcoming class while still a ghost (not yet spawned).
//
// Two separate mechanisms, with two separate confidence levels:
//
//  1) Bot/Director spawns - AreaBotBotEnforceCap below hooks left4dhooks'
//     L4D_OnSpawnSpecial, which explicitly only fires for bot/Director-initiated spawns
//     (not real players) and lets us change the class *before* it spawns by reference.
//     This is the same technique SirPlease's L4D2-Competitive-Rework plugin suite uses
//     for its own spawn-order/class control, so confidence here is high. Since ABM fills
//     most of an 8v8 Infected team with bots, this covers the majority of the roster.
//
//  2) Human players - Command_InfectedReroll below has a human player run z_spawn_old
//     on themselves while still a ghost. Community reports (Steam discussions) say this
//     makes a ghosted human spawn AS that class rather than summoning a separate bot -
//     unlike e.g. NecroTanker's witch-summon (Talents_Tank_NecroTanker.sp), which calls
//     the same underlying command but from a client who is NOT a ghost, and so spawns a
//     separate entity instead. This distinction could not be verified end-to-end here
//     (no live client to test with) - please test this specifically and report back.
//
#define INFECTED_CLASS_LIVE_CAP 2

// Counts how many currently-alive Infected players (human or bot) are playing the given
// class. Ghosts don't count - they haven't landed as anything yet. Pass -1 for
// iExcludeClient to not exclude anyone.
int CountLiveInfectedOfClass(int iInfectedClass, int iExcludeClient = -1)
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == iExcludeClient ||
			RunClientChecks(i) == false ||
			g_iClientTeam[i] != TEAM_INFECTED ||
			IsPlayerAlive(i) == false ||
			g_bIsGhost[i] == true)
			continue;

		if (g_iInfectedCharacter[i] == iInfectedClass)
			iCount++;
	}

	return iCount;
}

// Picks a class currently under the live cap, preferring whichever is least populated so
// repeated rerolls/redirects spread out across classes rather than piling into whichever
// happens to be checked first. Returns -1 if every class is already at (or over) the cap.
int PickInfectedClassUnderCap(int iExcludeClient = -1)
{
	static const int CLASSES[] = { SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER };

	int iBestClass = -1;
	int iBestCount = INFECTED_CLASS_LIVE_CAP + 1;

	for (int c = 0; c < sizeof(CLASSES); c++)
	{
		int iCount = CountLiveInfectedOfClass(CLASSES[c], iExcludeClient);
		if (iCount < INFECTED_CLASS_LIVE_CAP && iCount < iBestCount)
		{
			iBestClass = CLASSES[c];
			iBestCount = iCount;
		}
	}

	return iBestClass;
}

// left4dhooks forward - fires before the Director/a bot spawns as a given SI class.
// Explicitly bot/Director-only per left4dhooks' own documentation, never real players.
public Action L4D_OnSpawnSpecial(int &zombieClass, const float vecPos[3], const float vecAng[3])
{
	if (zombieClass < SMOKER || zombieClass > CHARGER)
		return Plugin_Continue;

	if (CountLiveInfectedOfClass(zombieClass) < INFECTED_CLASS_LIVE_CAP)
		return Plugin_Continue;

	int iReplacementClass = PickInfectedClassUnderCap();
	if (iReplacementClass == -1 || iReplacementClass == zombieClass)
		return Plugin_Continue; // every class already at cap - nothing better available

	DebugLog(DEBUG_MODE_VERBOSE, "[XPMod] Bot spawn redirected: %s was at the %d-player cap, spawning %s instead.",
		INFECTED_NAME[zombieClass], INFECTED_CLASS_LIVE_CAP, INFECTED_NAME[iReplacementClass]);

	zombieClass = iReplacementClass;
	return Plugin_Changed;
}

// Console command for a human player: while still a ghost (not yet spawned), reroll to a
// different class under the live cap. Bind this to whatever key you want, e.g.:
//   bind mouse2 xpmreroll
Action Command_InfectedReroll(int iClient, int args)
{
	if (RunClientChecks(iClient) == false || IsFakeClient(iClient) == true)
		return Plugin_Handled;

	if (g_iClientTeam[iClient] != TEAM_INFECTED || g_bIsGhost[iClient] == false)
	{
		PrintToChat(iClient, "\x03[XPMod] \x05You can only reroll while waiting to spawn as Infected (still a ghost).");
		return Plugin_Handled;
	}

	int iNewClass = PickInfectedClassUnderCap();
	if (iNewClass == -1)
	{
		PrintToChat(iClient, "\x03[XPMod] \x05Every Special Infected class is at the %d-player cap right now - try again in a moment.", INFECTED_CLASS_LIVE_CAP);
		return Plugin_Handled;
	}

	char strSpawnCommand[32];
	Format(strSpawnCommand, sizeof(strSpawnCommand), "z_spawn_old %s auto", INFECTED_NAME[iNewClass]);
	RunCheatCommand(iClient, "z_spawn_old", strSpawnCommand);

	PrintToChat(iClient, "\x03[XPMod] \x05Rerolled - you should spawn as \x04%s\x05.", INFECTED_NAME[iNewClass]);
	DebugLog(DEBUG_MODE_ERRORS, "[XPMod] %N used xpmreroll while ghosted -> requested %s.", iClient, INFECTED_NAME[iNewClass]);

	return Plugin_Handled;
}
