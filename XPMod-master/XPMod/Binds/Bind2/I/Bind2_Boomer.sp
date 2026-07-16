void Bind2Press_Boomer(int iClient)
{
    // Binds.sp only reaches this function when g_iInfectedCharacter[iClient] == BOOMER
    // already - checking the separate "3 saved class slots" array here instead was
    // redundant and desync-prone (see SyncInfectedClassSlotFromCurrent), and could wrongly
    // show "You dont have the Boomer as one of your classes" instead of the real reason.
    if(g_iInfectedCharacter[iClient] == BOOMER)
    {
        if(g_iNorovirusLevel[iClient] > 0)
        {
            if(g_iClientBindUses_2[iClient] < 3)
            {
                if(g_bIsSuicideBoomer[iClient] == false && g_bIsSuicideJumping[iClient] == false)
                {
                    g_bIsSuicideBoomer[iClient] = true;
                    PrintHintText(iClient, "You have inhaled %d Atomic Burritos! Jump to release.", g_iNorovirusLevel[iClient]);
                }
            }
            else
                PrintToChat(iClient, "\x03[XPMod] \x05You are out of Atomic Burritos");
        }
        else
            PrintToChat(iClient, "\x03[XPMod] \x05You must have a Noro-Virus for Bind 2");
    }
    else
        PrintToChat(iClient, "\x03[XPMod] \x05You dont have the Boomer as one of your classes");
}
