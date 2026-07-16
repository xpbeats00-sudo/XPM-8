#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define ALL_PRESENT_GRACE 3.0

ConVar g_hEnabled;
ConVar g_hGraceTime;

bool g_bGraceTimerActive = false;
float g_fGraceEndTime = 0.0;
Handle g_hCheckTimer = null;

// Set once per round the first time we detect every living survivor is
// in the checkpoint, so we log/act on that transition exactly once
// instead of spamming every 2-second tick.
bool g_bAllPresentLogged = false;
float g_fAllPresentSince = 0.0;
bool g_bAllPresentForceTried = false;
float g_fLastDiagnosticLog = 0.0;

public Plugin myinfo =
{
    name = "Checkpoint Pity Timer",
    author = "XP (built for your 8v8 XP server)",
    description = "Forces checkpoint completion after a grace period if some survivors never reach the safe room",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("sm_checkpointpity_enabled", "1", "Enable checkpoint pity timer");
    g_hGraceTime = CreateConVar("sm_checkpointpity_grace", "45.0", "Seconds to wait for stragglers once at least one survivor reaches the safe room, before leaving them behind");

    HookEvent("round_start", Event_RoundStart);
}

// DIAGNOSTIC: left4dhooks calls this automatically if/when the engine
// itself actually attempts to end a versus round. If this never fires
// even though we've confirmed every survivor is in the checkpoint, that's
// proof the engine's own completion check isn't triggering at all (as
// opposed to triggering but being blocked by something like a locked door).
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    LogMessage("[checkpoint_pity] L4D2_OnEndVersusModeRound FIRED (countSurvivors=%d). The engine IS attempting to end the round.", countSurvivors);
    return Plugin_Continue;
}

public void OnMapStart()
{
    g_bGraceTimerActive = false;
    // Timers are auto-killed by SourceMod on map change; just drop our
    // reference so we don't try to KillTimer a handle that's already gone.
    g_hCheckTimer = null;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bGraceTimerActive = false;
    g_bAllPresentLogged = false;
    g_fAllPresentSince = 0.0;
    g_bAllPresentForceTried = false;
    g_fLastDiagnosticLog = 0.0;

    // round_start fires more than once per map in Versus (once per team
    // side) - kill any timer from the previous round before starting a
    // fresh one, or they'd stack up and race on the shared state above.
    if (g_hCheckTimer != null)
    {
        KillTimer(g_hCheckTimer);
        g_hCheckTimer = null;
    }

    if (g_hEnabled.BoolValue)
        g_hCheckTimer = CreateTimer(2.0, Timer_CheckCheckpointStatus, _, TIMER_REPEAT);

    return Plugin_Continue;
}

public Action Timer_CheckCheckpointStatus(Handle timer)
{
    if (!g_hEnabled.BoolValue)
    {
        g_hCheckTimer = null;
        return Plugin_Stop;
    }

    int aliveCount = 0;
    int inCheckpointCount = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
        {
            aliveCount++;

            if (L4D_IsInLastCheckpoint(i))
                inCheckpointCount++;
        }
    }

    // Nobody alive, or nobody has arrived yet - nothing to do.
    if (aliveCount == 0 || inCheckpointCount == 0)
        return Plugin_Continue;

    // Everyone still alive is in the checkpoint. Log this explicitly the
    // moment it happens - this was previously silent, and we've since
    // confirmed via testing that native completion does NOT reliably fire
    // on its own in this 8v8/modded setup, so we now force it directly via
    // L4D_EndVersusModeRound() instead of guessing at door entity states.
    if (inCheckpointCount >= aliveCount)
    {
        g_bGraceTimerActive = false;

        if (!g_bAllPresentLogged)
        {
            g_bAllPresentLogged = true;
            g_fAllPresentSince = GetGameTime();
            LogMessage("[checkpoint_pity] All %d living survivor(s) detected in last checkpoint. Waiting %.0fs for native completion before forcing.", aliveCount, ALL_PRESENT_GRACE);
            PrintToChatAll("\x04[Checkpoint] \x01All survivors are in the Safe Room.");
        }

        // Give the engine a short window to complete the round on its own
        // before we force it - if native completion ever does work in some
        // situations, we don't want to short-circuit it unnecessarily.
        else if (!g_bAllPresentForceTried && GetGameTime() - g_fAllPresentSince >= ALL_PRESENT_GRACE)
        {
            g_bAllPresentForceTried = true;
            LogMessage("[checkpoint_pity] Round still active %.0fs after all survivors arrived - forcing completion via L4D_EndVersusModeRound(true).", ALL_PRESENT_GRACE);
            L4D_EndVersusModeRound(true);
        }

        // Keep logging every 10s in the rare case even the forced call
        // above doesn't take effect, so we have a continuous trace instead
        // of going silent.
        else if (g_bAllPresentForceTried && GetGameTime() - g_fLastDiagnosticLog >= 10.0)
        {
            g_fLastDiagnosticLog = GetGameTime();
            LogMessage("[checkpoint_pity] STILL stuck %.0fs after all survivors arrived, even after forcing L4D_EndVersusModeRound(true). FinaleEscapeInProgress=%d AnySurvivorInCheckpoint=%d",
                GetGameTime() - g_fAllPresentSince, L4D_IsFinaleEscapeInProgress(), L4D_IsAnySurvivorInCheckpoint());
        }

        return Plugin_Continue;
    }

    // At least one arrived, but not everyone - start (or continue) the
    // grace period countdown.
    if (!g_bGraceTimerActive)
    {
        g_bGraceTimerActive = true;
        g_fGraceEndTime = GetGameTime() + g_hGraceTime.FloatValue;
        PrintToChatAll("\x04[Checkpoint] \x01Survivors have reached the Safe Room. Stragglers have \x03%.0f seconds\x01 to arrive!", g_hGraceTime.FloatValue);
        return Plugin_Continue;
    }

    if (GetGameTime() >= g_fGraceEndTime)
    {
        g_bGraceTimerActive = false;

        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !L4D_IsInLastCheckpoint(i))
            {
                PrintToChatAll("\x04[Checkpoint] \x03%N \x01was left behind!", i);
                ForcePlayerSuicide(i);
            }
        }

        // Everyone still alive is now in the checkpoint by construction -
        // force completion now instead of waiting another full tick cycle
        // to notice it via the branch above.
        LogMessage("[checkpoint_pity] Stragglers left behind - forcing completion via L4D_EndVersusModeRound(true).");
        L4D_EndVersusModeRound(true);
    }

    return Plugin_Continue;
}
