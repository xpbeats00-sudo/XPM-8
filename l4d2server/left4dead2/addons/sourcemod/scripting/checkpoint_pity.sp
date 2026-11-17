#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define ALL_PRESENT_GRACE 3.0

ConVar g_hEnabled;
ConVar g_hGraceTime;
ConVar g_hStartRatio;

Handle g_hCheckTimer = null;

bool g_bRoundOver = false;          // round_end seen, or we already forced the end
bool g_bGraceTimerActive = false;
float g_fGraceEndTime = 0.0;

// Set once per round the first time every living survivor is in the checkpoint,
// so that transition is logged/acted on exactly once.
bool g_bAllPresentLogged = false;
float g_fAllPresentSince = 0.0;

public Plugin myinfo =
{
    name = "Checkpoint Pity Timer",
    author = "XP (built for your 8v8 XP server)",
    description = "Forces checkpoint completion after a grace period once most survivors have reached the safe room",
    version = "2.0",
    url = ""
};

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("sm_checkpointpity_enabled", "1", "Enable checkpoint pity timer", _, true, 0.0, true, 1.0);
    g_hGraceTime = CreateConVar("sm_checkpointpity_grace", "45.0", "Seconds stragglers get once enough survivors are in the safe room, before the round is ended without them", _, true, 5.0);
    g_hStartRatio = CreateConVar("sm_checkpointpity_ratio", "0.5", "Fraction of standing (not incapped/pinned) living survivors that must be in the safe room before the straggler countdown starts", _, true, 0.01, true, 1.0);
    AutoExecConfig(true, "checkpoint_pity");

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

// DIAGNOSTIC: left4dhooks calls this when the engine itself attempts to end a
// versus round.
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    LogMessage("[checkpoint_pity] L4D2_OnEndVersusModeRound FIRED (countSurvivors=%d).", countSurvivors);
    return Plugin_Continue;
}

public void OnMapEnd()
{
    // TIMER_FLAG_NO_MAPCHANGE timers are killed by SourceMod at map end.
    g_hCheckTimer = null;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    delete g_hCheckTimer;

    g_bRoundOver = false;
    g_bGraceTimerActive = false;
    g_bAllPresentLogged = false;
    g_fAllPresentSince = 0.0;

    if (g_hEnabled.BoolValue)
        g_hCheckTimer = CreateTimer(2.0, Timer_CheckCheckpointStatus, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bRoundOver = true;
    delete g_hCheckTimer;
}

void ForceRoundEnd(const char[] reason)
{
    if (g_bRoundOver)
        return;

    g_bRoundOver = true;
    LogMessage("[checkpoint_pity] %s - forcing completion via L4D_EndVersusModeRound(true).", reason);
    L4D_EndVersusModeRound(true);
}

bool IsDowned(int client)
{
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0
        || GetEntProp(client, Prop_Send, "m_isHangingFromLedge") != 0
        || L4D_IsPlayerPinned(client);
}

Action Timer_CheckCheckpointStatus(Handle timer)
{
    if (!g_hEnabled.BoolValue || g_bRoundOver)
    {
        g_hCheckTimer = null;
        return Plugin_Stop;
    }

    int aliveCount = 0;
    int standingCount = 0;
    int inCheckpointCount = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
            continue;

        aliveCount++;
        bool inside = L4D_IsInLastCheckpoint(i);
        if (inside)
            inCheckpointCount++;
        if (!IsDowned(i) || inside)
            standingCount++;
    }

    // Nobody alive, or the checkpoint emptied again: cancel any countdown so a
    // later entry starts a fresh, announced one.
    if (aliveCount == 0 || inCheckpointCount == 0)
    {
        if (g_bGraceTimerActive)
        {
            g_bGraceTimerActive = false;
            PrintToChatAll("\x04[Checkpoint] \x01Safe Room is empty again - straggler countdown cancelled.");
        }
        g_bAllPresentLogged = false;
        return Plugin_Continue;
    }

    // Everyone alive is inside. Give the engine a moment to end the round on its
    // own, then force it once.
    if (inCheckpointCount >= aliveCount)
    {
        g_bGraceTimerActive = false;

        if (!g_bAllPresentLogged)
        {
            g_bAllPresentLogged = true;
            g_fAllPresentSince = GetGameTime();
            PrintToChatAll("\x04[Checkpoint] \x01All survivors are in the Safe Room.");
        }
        else if (GetGameTime() - g_fAllPresentSince >= ALL_PRESENT_GRACE)
        {
            ForceRoundEnd("All living survivors in last checkpoint");
        }
        return Plugin_Continue;
    }

    g_bAllPresentLogged = false;

    // Only start the straggler clock once a real share of the standing team is
    // inside - one rusher or one bot reaching the door no longer dooms everyone
    // else mid-fight.
    if (!g_bGraceTimerActive)
    {
        if (float(inCheckpointCount) < g_hStartRatio.FloatValue * float(standingCount))
            return Plugin_Continue;

        g_bGraceTimerActive = true;
        g_fGraceEndTime = GetGameTime() + g_hGraceTime.FloatValue;
        PrintToChatAll("\x04[Checkpoint] \x01Most survivors are in the Safe Room. Stragglers have \x03%.0f seconds\x01 to arrive!", g_hGraceTime.FloatValue);
        return Plugin_Continue;
    }

    if (GetGameTime() >= g_fGraceEndTime)
    {
        g_bGraceTimerActive = false;

        // Standing stragglers who chose not to come in are left behind.
        // Incapped, ledge-hanging and pinned survivors are not killed - the
        // round simply ends without them (they don't count toward the score).
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)
                && !L4D_IsInLastCheckpoint(i) && !IsDowned(i))
            {
                PrintToChatAll("\x04[Checkpoint] \x03%N \x01was left behind!", i);
                ForcePlayerSuicide(i);
            }
        }

        ForceRoundEnd("Straggler grace period expired");
    }

    return Plugin_Continue;
}
