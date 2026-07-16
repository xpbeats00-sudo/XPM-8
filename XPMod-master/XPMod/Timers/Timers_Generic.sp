//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////           TIMERS           ///////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


Action Timer1SecondGlobalRepeating(Handle timer, int data)
{
	// Non Client specific Functions
	LoopThroughAllPlayersAndHandleAFKPlayers();

	// Client specific Functions
	for(int iClient = 1;iClient <= MaxClients; iClient++)
	{
		if (RunClientChecks(iClient)==false || 
			g_bTalentsConfirmed[iClient] == false ||
			IsPlayerAlive(iClient) == false)
			continue;

		// Handle DPS Meters
		Handle1SecondClientTimers_DPSMeter(iClient);
		
		if(g_iClientTeam[iClient] == TEAM_SURVIVORS)
		{
			switch(g_iChosenSurvivor[iClient])
			{
			// 	case BILL:		Handle1SecondClientTimers_Bill(iClient);
			// 	case ROCHELLE:	Handle1SecondClientTimers_Rochelle(iClient);
			// 	case COACH:		Handle1SecondClientTimers_Coach(iClient);
			// 	case ELLIS:		Handle1SecondClientTimers_Ellis(iClient);
			// 	case NICK:		Handle1SecondClientTimers_Nick(iClient);
			// 	case LOUIS:		Handle1SecondClientTimers_Louis(iClient);
				case ZOEY:		Handle1SecondClientTimers_Zoey(iClient);
			}
		}
		else if(g_iClientTeam[iClient] == TEAM_INFECTED)
		{
			switch(g_iInfectedCharacter[iClient])
			{
				// case SMOKER:	Handle1SecondClientTimers_Smoker(iClient);
				// case BOOMER:	Handle1SecondClientTimers_Boomer(iClient);
				case HUNTER:	Handle1SecondClientTimers_Hunter(iClient);
				// case SPITTER:	Handle1SecondClientTimers_Spitter(iClient);
				case JOCKEY:	Handle1SecondClientTimers_Jockey(iClient);
				// case CHARGER:	Handle1SecondClientTimers_Charger(iClient);
			}
		}
	}

	return Plugin_Continue;
}

Action Timer2SecondGlobalRepeating(Handle timer, int data)
{
	// Non Client specific Functions


	// Client specific Functions
	for(int iClient = 1;iClient <= MaxClients; iClient++)
	{
		if (RunClientChecks(iClient)==false || 
			g_bTalentsConfirmed[iClient] == false ||
			IsPlayerAlive(iClient) == false)
			continue;
		
			if(g_iClientTeam[iClient] == TEAM_SURVIVORS)
			{
				switch(g_iChosenSurvivor[iClient])
				{
				// case BILL:		Handle2SecondClientTimers_Bill(iClient);
					case ROCHELLE:	Handle2SecondClientTimers_Rochelle(iClient);
					case COACH:		Handle2SecondClientTimers_Coach(iClient);
				// case ELLIS:		Handle2SecondClientTimers_Ellis(iClient);
				// case NICK:		Handle2SecondClientTimers_Nick(iClient);
				// case LOUIS:		Handle2SecondClientTimers_Louis(iClient);
				// case ZOEY:		Handle2SecondClientTimers_Zoey(iClient);
				}
			}
		// else if(g_iClientTeam[iClient] == TEAM_INFECTED)
		// {
		// 	switch(g_iInfectedCharacter[iClient])
		// 	{
		// 		case SMOKER:	Handle2SecondClientTimers_Smoker(iClient);
		// 		case BOOMER:	Handle2SecondClientTimers_Boomer(iClient);
		// 		case HUNTER:	Handle2SecondClientTimers_Hunter(iClient);
		// 		case SPITTER:	Handle2SecondClientTimers_Spitter(iClient);
		// 		case JOCKEY:	Handle2SecondClientTimers_Jockey(iClient);
		// 		case CHARGER:	Handle2SecondClientTimers_Charger(iClient);
		// 	}
		// }
		}

	return Plugin_Continue;
}

// Director-spawned "bot" Special Infected (see AddInfected in AnyBotManager/abm.sp) are
// pure server-side NPCs, not clients - they never occupy a player slot, so there's no
// client for the native scoreboard to list them by. Real slotted SI bots would need new
// binary SDK signatures XPMod doesn't have (NextBotCreatePlayerBot<Class> etc. - see the
// community "InfectedBots" plugin), which is a much bigger, riskier change and overlaps
// heavily with AnyBotManager's own bot-spawning. Scanning the actual SI entities in the
// world instead and showing human Infected players which ones are bot-controlled gets the
// same practical result (they can see their bot teammates) without any of that risk.
static const char INFECTED_SI_CLASSNAMES[][] = { "smoker", "boomer", "hunter", "spitter", "jockey", "charger" };
static const int INFECTED_SI_CLASSNAME_ENUM[] = { SMOKER, BOOMER, HUNTER, SPITTER, JOCKEY, CHARGER };

Action TimerShowBotInfectedSI(Handle timer, int data)
{
	char strBotList[192];
	int iBotCount = 0;

	for (int c = 0; c < sizeof(INFECTED_SI_CLASSNAMES); c++)
	{
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, INFECTED_SI_CLASSNAMES[c])) != -1)
		{
			// Entity indexes 1..MaxClients belong to clients (human, or a bot someone took
			// over) - anything above that has no owning client at all, i.e. a Director NPC.
			if (entity <= MaxClients || IsValidEntity(entity) == false)
				continue;

			if (GetEntProp(entity, Prop_Send, "m_iHealth") <= 0)
				continue;

			iBotCount++;
			if (strlen(strBotList) > 0)
				StrCat(strBotList, sizeof(strBotList), ", ");
			StrCat(strBotList, sizeof(strBotList), INFECTED_NAME[INFECTED_SI_CLASSNAME_ENUM[c]]);
		}
	}

	if (iBotCount == 0)
		return Plugin_Continue;

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (RunClientChecks(iClient) == false ||
			IsFakeClient(iClient) == true ||
			g_iClientTeam[iClient] != TEAM_INFECTED)
			continue;

		PrintHintText(iClient, "Bot Special Infected active (%d): %s", iBotCount, strBotList);
	}

	return Plugin_Continue;
}

Action Timer_ResetGlow(Handle timer, int iClient)
{
	SetClientRenderAndGlowColor(iClient);
	
	g_hTimer_ResetGlow[iClient] = null;
	
	return Plugin_Stop;
}

Action TimerGiveHudBack(Handle timer, int iClient)
{
	if(IsClientInGame(iClient) == true && IsFakeClient(iClient) == false)
		SetEntProp(iClient, Prop_Send, "m_iHideHUD", 0);
	
	return Plugin_Stop;
}

Action ResetBind1AttemptCooldown(Handle timer, int iClient)
{
	g_bBind1InCooldown[iClient] = false;
	return Plugin_Handled;
}

Action TimerResetZombieDamage(Handle timer, int iClient)
{
	SetConVarInt(FindConVar("z_common_limit"), 30);
	g_bCommonInfectedDoMoreDamage = false;
	
	return Plugin_Stop;
}

Action TimerUnfreezeNotification(Handle timer, int data)
{
	if(g_iUnfreezeNotifyRunTimes-- > 1)
	{
		PrintHintTextToAll("Survivors will be unfrozen in %i seconds", g_iUnfreezeNotifyRunTimes);
		return Plugin_Continue;
	}

	g_hTimer_FreezeCountdown = null;

	return Plugin_Stop;
}

Action TimerChangeSpectator(Handle timer, int iClient)
{
	if(iClient > 0 && g_bClientSpectating[iClient] == true && IsClientInGame(iClient) && IsFakeClient(iClient) == false)
	{
		ChangeClientTeam(iClient, TEAM_SPECTATORS);
		g_iClientTeam[iClient] = 1;
		PrintToChat(iClient, "\n\x03[XPMod] \x04You're Spectator until you change teams in the XPM Menu.\n ");
		PrintHintText(iClient, "You're Spectator until you change teams in the XPM Menu.");
	}
	
	return Plugin_Stop;
}

Action TimerResetPlayerChangeTeamCoolDown(Handle timer, int iClient)
{
	g_bPlayerInTeamChangeCoolDown[iClient] = false;

	return Plugin_Stop;
}

Action TimerCheckTeam(Handle timer, int iClient)
{
	if (RunClientChecks(iClient) == false)
		return Plugin_Stop;
	
	if(g_bClientSpectating[iClient] == true && IsFakeClient(iClient) == false)
	{
		ChangeClientTeam(iClient, TEAM_SPECTATORS);
		g_iClientTeam[iClient] = 1;
	}
	
	// Get their team and store it for fast retrieval
	g_iClientTeam[iClient] = GetClientTeam(iClient);
	
	DeleteAllClientParticles(iClient);
	ResetAllVariables(iClient);
	
	if(g_iClientTeam[iClient] == TEAM_INFECTED)
	{
		// We now do not know which infected they have, because they switched team
		g_iInfectedCharacter[iClient] = UNKNOWN_INFECTED;

		// For checking if the player is a ghost
		g_bCanBeGhost[iClient] = true;
		g_bIsGhost[iClient] = false;

		// Rochelle's Listening Abilities
		for (int i = 1; i <= MaxClients; i++)
		{
			if(g_iGatherLevel[i] == 5 && IsClientInGame(i) == true && GetClientTeam(i) == TEAM_SURVIVORS)
				SetListenOverride(i, iClient, Listen_Yes);	//Sets the iClient to hear all the infected's voice comms
		}
	}

	// Display the Spectator message
	if (g_iClientTeam[iClient] == TEAM_SPECTATORS)
	{
		PrintToChat(iClient, "\n\x03[XPMod] \x04You're Spectator until you change teams in the XPM Menu.\n ");
		PrintHintText(iClient, "You're Spectator until you change teams in the XPM Menu.");
	}
	
	return Plugin_Stop;
}

Action FreezeColor(Handle timer, int iClient)
{
	if(IsClientInGame(iClient) == false)
		return Plugin_Stop;
		
	float xyzVector[3];
	GetClientEyePosition(iClient, xyzVector);
	EmitAmbientSound(SOUND_FREEZE, xyzVector, iClient, SNDLEVEL_NORMAL);
	
	SetEntityRenderMode(iClient, RenderMode:3);
	SetEntityRenderColor(iClient, 0, 180, 255, 160);
	
	return Plugin_Stop;
}

Action TimerUnfreeze(Handle timer, int data)
{
	g_bGameFrozen = false;
	
	SetConVarInt(FindConVar("sb_stop"), 0);	//Turn the bots back on
	
	for(int i = 1;i <= MaxClients;i++)
	{
		if(RunClientChecks(i) && IsPlayerAlive(i) == true)
		{
			if(g_iClientTeam[i] == TEAM_SURVIVORS)
			{
				//Play Ice Breaking Sound
				float vec[3];
				GetClientAbsOrigin(i, vec);
				EmitAmbientSound(SOUND_FREEZE, vec, i, SNDLEVEL_NORMAL);
			}
			
			SetClientRenderAndGlowColor(i);
			SetClientSpeed(i);

			SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);	//Player can take damage now
			SetEntProp(i, Prop_Send, "m_isGoingToDie", 0);		//Fix the black and white at the beginning of the round           (Working?>
			
			if(IsFakeClient(i)==false)
			{
				if(g_bClientLoggedIn[i] == true)
				{
					if(g_iClientTeam[i]==TEAM_SURVIVORS)
					{
						if(g_bTalentsConfirmed[i] == false)
						{
							AdvertiseConfirmXPModTalents(i);
						}
						//LoadTalents(i);
					}
				}
				else
					AdvertiseXPModToNewUser(i);
				//OpenMOTDPanel(i, " ", "make", MOTDPANEL_TYPE_INDEX);
				//OpenMOTDPanel(i, "How To Create And Login To Your Account", "http://xpmod.atspace.com/makeaccount.html", MOTDPANEL_TYPE_URL);
			}			
		}
	}
	
	PrintHintTextToAll("Survivors Are Unfrozen");
	
	return Plugin_Stop;
}


Action TimerDrugged(Handle timer, int iClient)
{
	if(IsClientInGame(iClient) == false || IsPlayerAlive(iClient) == false)
	{
		g_hTimer_DrugPlayer[iClient] = null;
		return Plugin_Stop;
	}
	
	if(g_iDruggedRuntimesCounter[iClient]++ < 10)
	{
		if(IsFakeClient(iClient)==false)
		{
			int red = GetRandomInt(0,255);
			int green = GetRandomInt(0,255);
			int blue = GetRandomInt(0,255);
			int alpha = GetRandomInt(190,230);
			ShowHudOverlayColor(iClient, red, green, blue, alpha, 700, FADE_IN);
		}
		
		DealDamage(iClient, iClient, 1);
		
		return Plugin_Continue;
	}
	
	//Do one long lasting final hud color overlay to fade it out
	if(IsFakeClient(iClient)==false)
	{
		int red = GetRandomInt(0,255);
		int green = GetRandomInt(0,255);
		int blue = GetRandomInt(0,255);
		int alpha = GetRandomInt(190,230);
		ShowHudOverlayColor(iClient, red, green, blue, alpha, 1600, FADE_OUT);
	}
	
	//Reset Client run speed
	//ResetSurvivorSpeed(iClient);
	
	g_hTimer_DrugPlayer[iClient] = null;
	return Plugin_Stop;
}
