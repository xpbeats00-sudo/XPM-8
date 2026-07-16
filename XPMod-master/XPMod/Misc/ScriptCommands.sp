stock void L4D2_RunScript(const char[] sCode, any ...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) 
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

stock void SendAllSurvivorBotsFocusedOnXPMGoal(float xyzLocation[3], int iTarget = -1)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		SetBotFocusedOnXPMGoal(iClient, xyzLocation, iTarget);
}

stock void SetBotFocusedOnXPMGoal(int iClient, float xyzLocation[3], int iTarget = -1)
{
	if (RunClientChecks(iClient) == false || 
		IsPlayerAlive(iClient) == false ||
		g_iClientTeam[iClient] != TEAM_SURVIVORS ||
		IsFakeClient(iClient) == false)
		return;

	g_iBotXPMGoalTarget[iClient] = iTarget;
	g_xyzBotXPMGoalLocation[iClient][0] = xyzLocation[0];
	g_xyzBotXPMGoalLocation[iClient][1] = xyzLocation[1];
	g_xyzBotXPMGoalLocation[iClient][2] = xyzLocation[2];
	g_bBotXPMGoalAccomplished[iClient] = false;
	delete g_hTimer_TimerKeepBotFocusedOnXPModGoal[iClient];
	g_hTimer_TimerKeepBotFocusedOnXPModGoal[iClient] = CreateTimer(0.1, TimerKeepBotFocusedOnXPMGoal, iClient, TIMER_REPEAT)

	DebugLog(DEBUG_MODE_VERBOSE, "[XPMod] SetBotFocusedOnXPMGoal %i", iClient);
}

Action TimerKeepBotFocusedOnXPMGoal(Handle timer, int iClient)
{
	if (g_bBotXPMGoalAccomplished[iClient] == true ||
		RunClientChecks(iClient) == false ||
		IsPlayerAlive(iClient) == false ||
		IsFakeClient(iClient) == false)
	{
		DebugLog(DEBUG_MODE_VERBOSE, "[XPMod] Bot Lost Focus On Goal %i", iClient);

		g_hTimer_TimerKeepBotFocusedOnXPModGoal[iClient] = null;
		return Plugin_Stop;
	}


	float fGameTime = GetGameTime();
	if (fGameTime - g_fGameTimeOfLastGoalSet[iClient] <= 5.0 ||
		fGameTime - g_fGameTimeOfLastDamageTaken[iClient] <= 5.0 ||
		fGameTime - g_fGameTimeOfLastViableTargetSeen[iClient] <= 5.0)
		return Plugin_Continue;


	if (CheckForViableSITargetForSurvivor(iClient))
		return Plugin_Continue;


	// Set their focus on the goal
	g_fGameTimeOfLastGoalSet[iClient] = fGameTime;
	SendBotToLocation(iClient, g_xyzBotXPMGoalLocation[iClient]);

	return Plugin_Continue;
}

bool CheckForViableSITargetForSurvivor(int iClient)
{
	float xyzClientLocation[3], xyzTargetLocation[3];
	GetClientEyePosition(iClient, xyzClientLocation);

	// Check for visible targets that are within range
	for (int iTarget; iTarget <= MaxClients; iTarget++)
	{
		if (RunClientChecks(iTarget) == false || 
			g_iClientTeam[iTarget] != TEAM_INFECTED ||
			IsPlayerAlive(iTarget) == false)
			continue;

		GetClientEyePosition(iTarget, xyzTargetLocation);
		// Get if the target is visible to and check the range if target to worry about
		if (IsVisibleTo(xyzClientLocation, xyzTargetLocation) &&
			GetVectorDistance(xyzClientLocation, xyzTargetLocation) < 1500.0)
		{
			// Its a potential threat, reset focus and kill it
			DebugLog(DEBUG_MODE_VERBOSE, "[XPMod] Viable Target %N Spotted by %N", iTarget, iClient);
			ResetBotCommand(iClient);
			g_fGameTimeOfLastViableTargetSeen[iClient] = GetGameTime();
			return true;
		}
	}

	return false;
}

stock void SendAllSurvivorBotsToLocation(float xyzLocation[3])
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		SendBotToLocation(iClient, xyzLocation);
}

stock void SendBotToLocation(int iClient, float xyzLocation[3])
{
	if (RunClientChecks(iClient) == false || 
		IsPlayerAlive(iClient) == false ||
		IsFakeClient(iClient) == false)
		return;

	DebugLog(DEBUG_MODE_VERBOSE, "[XPMod] Sending bot %N to location.", iClient);
	// Note they will do this wihotut stopping to shoot, so need to handle dmamage elsewhere
	L4D2_RunScript("CommandABot({cmd=1,pos=Vector(%f,%f,%f),bot=GetPlayerFromUserID(%i)})",
		xyzLocation[0],
		xyzLocation[1],
		xyzLocation[2], 
		GetClientUserId(iClient));
}

stock void ResetBotCommand(int iClient)
{
	if (g_bBotXPMGoalAccomplished[iClient] == true ||
		RunClientChecks(iClient) == false ||
		IsPlayerAlive(iClient) == false ||
		IsFakeClient(iClient) == false)
		return;

	DebugLog(DEBUG_MODE_VERBOSE, "[XPMod] Resetting bot commands for %N", iClient);

	L4D2_RunScript("CommandABot({cmd=3,bot=GetPlayerFromUserID(%i)})",
		GetClientUserId(iClient));
}

// Checks whether the survivor team's map progress has stalled (an all-bot team will
// fight fine but won't reliably push forward on its own without a human) and, if so,
// nudges any bot that's also personally gone nowhere - toward whichever survivor is
// currently furthest along if it's lagging behind the group, or a short distance in
// whatever direction it's already facing if the whole group is stuck together.
Action TimerCheckStuckBotSurvivors(Handle timer, int data)
{
	if ((g_iGameMode != GAMEMODE_VERSUS && g_iGameMode != GAMEMODE_VERSUS_SURVIVAL) ||
		g_bGameFrozen || g_bEndOfRound)
		return Plugin_Continue;

	float fCurrentFlow = L4D2_GetFurthestSurvivorFlow();
	bool bTeamProgressed = (fCurrentFlow > g_fLastSurvivorFlowDistance + BOT_STUCK_MIN_FLOW_PROGRESS);
	g_fLastSurvivorFlowDistance = fCurrentFlow;

	// Find whichever survivor (human or bot) is furthest along, to use as a regroup
	// point for any bot that's fallen behind the rest of the group.
	int iPointClient = -1;
	float fPointFlow = -1.0;
	float xyzPointPosition[3];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (RunClientChecks(i) == false ||
			g_iClientTeam[i] != TEAM_SURVIVORS ||
			IsPlayerAlive(i) == false)
			continue;

		float fFlow = L4D2Direct_GetFlowDistance(i);
		if (fFlow > fPointFlow)
		{
			fPointFlow = fFlow;
			iPointClient = i;
		}
	}

	if (iPointClient != -1)
		GetClientAbsOrigin(iPointClient, xyzPointPosition);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (RunClientChecks(i) == false ||
			IsFakeClient(i) == false ||
			g_iClientTeam[i] != TEAM_SURVIVORS ||
			IsPlayerAlive(i) == false ||
			g_bIsClientDown[i] == true ||
			clienthanging[i] == true)
			continue;

		float fCurrentPos[3];
		GetClientAbsOrigin(i, fCurrentPos);

		bool bBotMoved = (GetVectorDistance(fCurrentPos, g_fLastBotSurvivorPosition[i]) > BOT_STUCK_MIN_MOVE_DISTANCE);
		g_fLastBotSurvivorPosition[i] = fCurrentPos;

		if (bTeamProgressed || bBotMoved)
			continue;

		if (iPointClient != -1 && i != iPointClient &&
			GetVectorDistance(fCurrentPos, xyzPointPosition) > BOT_STUCK_REGROUP_DISTANCE)
		{
			// Lagging behind the rest of the group - send it to catch up.
			SetBotFocusedOnXPMGoal(i, xyzPointPosition);
		}
		else
		{
			// Either this IS the point survivor, or it's already near the point but
			// the group as a whole isn't moving - nudge forward along its own facing.
			float fEyeAngles[3], fForward[3], xyzTarget[3];
			GetClientEyeAngles(i, fEyeAngles);
			GetAngleVectors(fEyeAngles, fForward, NULL_VECTOR, NULL_VECTOR);

			xyzTarget[0] = fCurrentPos[0] + (fForward[0] * BOT_STUCK_EXTRAPOLATE_DISTANCE);
			xyzTarget[1] = fCurrentPos[1] + (fForward[1] * BOT_STUCK_EXTRAPOLATE_DISTANCE);
			xyzTarget[2] = fCurrentPos[2];

			SetBotFocusedOnXPMGoal(i, xyzTarget);
		}
	}

	return Plugin_Continue;
}
