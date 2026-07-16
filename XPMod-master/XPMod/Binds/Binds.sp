/**************************************************************************************************************************
 *                                                    Bind Pressed                                                      *
 **************************************************************************************************************************/

void BindPress(int iClient, int iBindNumber)
{
	if(RunClientChecks(iClient) == false)
		return;

	// TEMP DEBUG - remove once bind dispatch is confirmed working on 8v8
	PrintToChat(iClient, "\x03[XPMod DEBUG] \x01Bind%d pressed. Team=%d ChosenSurvivor=%d InfectedChar=%d TalentsConfirmed=%d",
		iBindNumber, g_iClientTeam[iClient], g_iChosenSurvivor[iClient], g_iInfectedCharacter[iClient], g_bTalentsConfirmed[iClient]);

	if(g_bTalentsConfirmed[iClient] == false)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You must confirm your talents before using binds.");
		return;
	}

	if(!IsPlayerAlive(iClient))
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You cannot use binds while you are dead.");
		return;
	}

	if(GetEntData(iClient, g_iOffset_IsGhost, 1) == 1)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You cannot use binds while your a ghost.");
		return;
	}

	if(g_bGameFrozen == true)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You must wait till the game is unfrozen before using binds.");
		return;
	}

	if(g_bFrozenByTank[iClient] == true)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04You cannot use binds while frozen.");
		return;
	}

	// Louis's TIME OUT bind 2, temporarily disable infected binds
	if(g_bInfectedBindsDisabled == true && g_iClientTeam[iClient] == TEAM_INFECTED)
	{
		PrintToChat(iClient, "\x03[XPMod] \x04The Infected have been hacked. All Binds are corrupt.");
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
			// TEMP DEBUG - remove once bind dispatch is confirmed working on 8v8
			default: PrintToChat(iClient, "\x03[XPMod DEBUG] \x04No survivor case matched ChosenSurvivor=%d - bind did nothing.", g_iChosenSurvivor[iClient]);
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
			// TEMP DEBUG - remove once bind dispatch is confirmed working on 8v8
			default: PrintToChat(iClient, "\x03[XPMod DEBUG] \x04No infected case matched InfectedChar=%d - bind did nothing.", g_iInfectedCharacter[iClient]);
		}
	}
	else
	{
		// TEMP DEBUG - remove once bind dispatch is confirmed working on 8v8
		PrintToChat(iClient, "\x03[XPMod DEBUG] \x04Team=%d matched neither Survivors nor Infected - bind did nothing.", g_iClientTeam[iClient]);
	}
}

Action Bind1Press(int iClient, int args)
{
	// Handle Pressing the bind
	BindPress(iClient, 1);
	
	return Plugin_Handled;
}


Action Bind2Press(int iClient, int args)
{
	// Handle Pressing the bind
	BindPress(iClient, 2);

	return Plugin_Handled;
}
