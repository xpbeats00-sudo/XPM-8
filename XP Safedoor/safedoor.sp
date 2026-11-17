#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

// Round state machine. Exactly one repeating 1-second "think" timer drives
// everything while the state is LOCKED or COUNTDOWN.
#define STATE_IDLE      0   // no door locked this round (finale map, disabled, not set up yet)
#define STATE_LOCKED    1   // end saferoom door is locked, waiting for the key
#define STATE_COUNTDOWN 2   // door unlocked, stragglers are on the clock
#define STATE_DONE      3   // nothing left to do this round

#define USE_RANGE       150.0   // key holder must be this close to the door to use the key
#define ARRIVAL_RANGE   300.0   // a survivor this close to the door starts the force-unlock timeout

ConVar g_hEnabled;
ConVar g_hKeyTimeout;
ConVar g_hCountdownTime;

bool g_bLateLoad = false;

int g_iState = STATE_IDLE;
int g_iDoorRef = INVALID_ENT_REFERENCE;   // entity REFERENCE, never a raw index
int g_iKeyHolder = 0;                     // client index, 0 = nobody
float g_fArrivalTime = 0.0;               // game time the first survivor reached the door, 0 = not yet
float g_fCountdownEndTime = 0.0;

Handle g_hSetupTimer = null;
Handle g_hThinkTimer = null;

public Plugin myinfo =
{
    name = "Safe Room Key System",
    author = "XP (built for your 8v8 XP server)",
    description = "Locked end saferoom with transferable key + force unlock + straggler timer",
    version = "2.0",
    url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("sm_saferoomkey_enabled", "1", "Enable Safe Room Key System", _, true, 0.0, true, 1.0);
    g_hKeyTimeout = CreateConVar("sm_saferoomkey_timeout", "75.0", "Seconds after the first survivor reaches the locked door before it force-unlocks. 0 = never force-unlock.", _, true, 0.0);
    g_hCountdownTime = CreateConVar("sm_saferoomkey_countdown", "90.0", "Seconds survivors have to get inside once the door is unlocked, before anyone still outside is killed. 0 = no countdown.", _, true, 0.0);
    AutoExecConfig(true, "safedoor");

    g_hEnabled.AddChangeHook(OnEnabledChanged);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);

    // Loaded/reloaded mid-map: set up for the round already in progress.
    if (g_bLateLoad && g_hEnabled.BoolValue)
        g_hSetupTimer = CreateTimer(1.0, Timer_Setup, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnPluginEnd()
{
    // Never leave the door locked behind us if the plugin is unloaded.
    ResetRound(true);
}

public void OnMapEnd()
{
    // TIMER_FLAG_NO_MAPCHANGE timers are killed by SourceMod here; drop our
    // references so nothing tries to close a handle that is already gone.
    g_hSetupTimer = null;
    g_hThinkTimer = null;
    g_iState = STATE_IDLE;
    g_iDoorRef = INVALID_ENT_REFERENCE;
    g_iKeyHolder = 0;
}

void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // Turned off mid-round: unlock and stop immediately. Turned on mid-round:
    // takes effect from the next round_start.
    if (!convar.BoolValue)
        ResetRound(true);
}

// Versus fires round_start once per team side on the same map, and the map's
// entities (including the door) are recreated each time, so all state is
// rebuilt from scratch here.
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    ResetRound(false);

    if (g_hEnabled.BoolValue)
        g_hSetupTimer = CreateTimer(5.0, Timer_Setup, _, TIMER_FLAG_NO_MAPCHANGE);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    ResetRound(true);
}

// Stops every timer and clears all per-round state. Safe to call at any time
// EXCEPT from inside Timer_Think/Timer_Setup (they clean up after themselves).
void ResetRound(bool unlockDoor)
{
    delete g_hSetupTimer;
    delete g_hThinkTimer;

    if (unlockDoor && g_iState == STATE_LOCKED)
    {
        int door = EntRefToEntIndex(g_iDoorRef);
        if (door != INVALID_ENT_REFERENCE)
            AcceptEntityInput(door, "Unlock");
    }

    g_iState = STATE_IDLE;
    g_iDoorRef = INVALID_ENT_REFERENCE;
    g_iKeyHolder = 0;
    g_fArrivalTime = 0.0;
    g_fCountdownEndTime = 0.0;
}

Action Timer_Setup(Handle timer)
{
    g_hSetupTimer = null;

    if (!g_hEnabled.BoolValue || g_iState != STATE_IDLE)
        return Plugin_Stop;

    // The END saferoom door specifically. Saferoom doors are
    // prop_door_rotating_checkpoint entities with inconsistent (often empty)
    // targetnames, so ask left4dhooks instead of guessing by name. Returns -1
    // on finales and any map without an end saferoom: nothing to lock there.
    int door = L4D_GetCheckpointLast();
    if (door == -1 || !IsValidEntity(door))
        return Plugin_Stop;

    g_iDoorRef = EntIndexToEntRef(door);
    AcceptEntityInput(door, "Lock");
    g_iState = STATE_LOCKED;
    g_fArrivalTime = 0.0;

    PrintToChatAll("\x04[Key System] \x01Safe Room door is \x03LOCKED\x01. Protect the Key holder!");
    AssignKey(false);

    g_hThinkTimer = CreateTimer(1.0, Timer_Think, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

Action Timer_Think(Handle timer)
{
    int door = EntRefToEntIndex(g_iDoorRef);
    if (door == INVALID_ENT_REFERENCE)
    {
        // Door entity is gone (round restarting) - nothing to manage.
        g_iState = STATE_IDLE;
    }
    else if (g_iState == STATE_LOCKED)
    {
        ThinkLocked(door);
    }
    else if (g_iState == STATE_COUNTDOWN)
    {
        ThinkCountdown();
    }

    if (g_iState != STATE_LOCKED && g_iState != STATE_COUNTDOWN)
    {
        g_hThinkTimer = null;
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

void ThinkLocked(int door)
{
    float doorPos[3];
    GetEntPropVector(door, Prop_Data, "m_vecAbsOrigin", doorPos);

    // Keep the key on a living survivor. This covers the holder dying,
    // disconnecting, going idle or switching team, and hands the key from a
    // bot to a human as soon as one is available (humans are usually still
    // loading when the round starts).
    if (!IsValidHolder(g_iKeyHolder))
        AssignKey(g_iKeyHolder != 0);
    else if (IsFakeClient(g_iKeyHolder) && CountSurvivors(true) > 0)
        AssignKey(true);

    // Bots never press USE on the door, so a bot holder opens it by arriving.
    if (IsValidHolder(g_iKeyHolder) && IsFakeClient(g_iKeyHolder)
        && !IsIncapacitated(g_iKeyHolder) && DistanceToPoint(g_iKeyHolder, doorPos) <= USE_RANGE)
    {
        PrintToChatAll("\x04[Key System] \x03%N \x01used the Key.", g_iKeyHolder);
        UnlockDoor(door);
        return;
    }

    // The force-unlock timeout only starts once somebody is actually waiting
    // at the door - not at round start.
    if (g_fArrivalTime == 0.0)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidHolder(i) && DistanceToPoint(i, doorPos) <= ARRIVAL_RANGE)
            {
                g_fArrivalTime = GetGameTime();
                if (IsValidHolder(g_iKeyHolder))
                    PrintToChatAll("\x04[Key System] \x01Survivors reached the Safe Room. \x03%N \x01has the Key!", g_iKeyHolder);
                if (g_hKeyTimeout.FloatValue > 0.0)
                    PrintToChatAll("\x04[Key System] \x01Door force-unlocks in \x03%.0f \x01seconds.", g_hKeyTimeout.FloatValue);
                break;
            }
        }
    }
    else if (g_hKeyTimeout.FloatValue > 0.0 && GetGameTime() - g_fArrivalTime >= g_hKeyTimeout.FloatValue)
    {
        PrintToChatAll("\x04[Key System] \x01Timeout reached - force unlocking Safe Room.");
        UnlockDoor(door);
    }
}

void ThinkCountdown()
{
    // Count living survivors and how many of them are inside. Uses the
    // game's own checkpoint area test, not a distance from the door.
    int alive = 0, outside = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidHolder(i))
        {
            alive++;
            if (!L4D_IsInLastCheckpoint(i))
                outside++;
        }
    }

    // Everyone alive made it (or nobody is left): countdown is over.
    if (alive == 0 || outside == 0)
    {
        g_iState = STATE_DONE;
        return;
    }

    float timeLeft = g_fCountdownEndTime - GetGameTime();
    if (timeLeft <= 0.0)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidHolder(i) && !L4D_IsInLastCheckpoint(i))
            {
                PrintToChat(i, "\x04[Key System] \x01You didn't make it inside in time!");
                ForcePlayerSuicide(i);
            }
        }
        g_iState = STATE_DONE;
        return;
    }

    // Hint only the human survivors, every 10s and then each of the last 10s,
    // so it doesn't bury other hint text for a minute and a half.
    int secs = RoundToCeil(timeLeft);
    if (secs <= 10 || secs % 10 == 0)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidHolder(i) && !IsFakeClient(i))
                PrintHintText(i, "Safe Room closes in: %d seconds!", secs);
        }
    }
}

// Human key holder uses the key by pressing USE next to the door.
public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (g_iState != STATE_LOCKED || client != g_iKeyHolder || !(buttons & IN_USE))
        return Plugin_Continue;

    int door = EntRefToEntIndex(g_iDoorRef);
    if (door == INVALID_ENT_REFERENCE || !IsValidHolder(client) || IsIncapacitated(client))
        return Plugin_Continue;

    float doorPos[3];
    GetEntPropVector(door, Prop_Data, "m_vecAbsOrigin", doorPos);
    if (DistanceToPoint(client, doorPos) <= USE_RANGE)
    {
        PrintToChatAll("\x04[Key System] \x03%N \x01used the Key.", client);
        UnlockDoor(door);
    }
    return Plugin_Continue;
}

void UnlockDoor(int door)
{
    AcceptEntityInput(door, "Unlock");
    g_iKeyHolder = 0;

    float countdown = g_hCountdownTime.FloatValue;
    if (countdown > 0.0)
    {
        g_iState = STATE_COUNTDOWN;
        g_fCountdownEndTime = GetGameTime() + countdown;
        PrintToChatAll("\x04[Key System] \x03Safe Room Unlocked! \x01Get inside within \x03%.0f \x01seconds.", countdown);
    }
    else
    {
        g_iState = STATE_DONE;
        PrintToChatAll("\x04[Key System] \x03Safe Room Unlocked!");
    }
}

// Gives the key to a random living survivor, preferring humans over bots.
void AssignKey(bool isTransfer)
{
    int clients[MAXPLAYERS + 1];
    int count = 0;

    for (int pass = 0; pass < 2 && count == 0; pass++)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            // pass 0: humans only, pass 1: anyone (bots)
            if (IsValidHolder(i) && i != g_iKeyHolder && (pass == 1 || !IsFakeClient(i)))
                clients[count++] = i;
        }
    }

    if (count == 0)
    {
        // Nobody else can take it. Keep a still-valid holder, otherwise the
        // key is unheld until a survivor is alive again.
        if (!IsValidHolder(g_iKeyHolder))
            g_iKeyHolder = 0;
        return;
    }

    g_iKeyHolder = clients[GetRandomInt(0, count - 1)];

    if (isTransfer)
        PrintToChatAll("\x04[Key System] \x01The Key passed to \x03%N\x01!", g_iKeyHolder);
    else
        PrintToChatAll("\x04[Key System] \x03%N \x01has the Safe Room Key!", g_iKeyHolder);

    if (!IsFakeClient(g_iKeyHolder))
        PrintHintText(g_iKeyHolder, "You have the Safe Room Key! Press USE at the saferoom door.");
}

// A living survivor currently in the game.
bool IsValidHolder(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client)
        && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

int CountSurvivors(bool humansOnly)
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidHolder(i) && (!humansOnly || !IsFakeClient(i)))
            count++;
    }
    return count;
}

bool IsIncapacitated(int client)
{
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

float DistanceToPoint(int client, const float point[3])
{
    float pos[3];
    GetClientAbsOrigin(client, pos);
    return GetVectorDistance(pos, point);
}
