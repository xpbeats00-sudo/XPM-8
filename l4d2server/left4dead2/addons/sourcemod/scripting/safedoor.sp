#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar g_hKeyTimeout;
ConVar g_hCountdownTime;
ConVar g_hEnabled;

int g_iKeyHolder = -1;
bool g_bDoorLocked = true;
bool g_bCountdownActive = false;
float g_fCountdownEndTime = 0.0;
int g_iSafeRoomDoor = -1;

// Versus fires round_start multiple times per map (once per team side).
// Every timer below must be tracked and killed on the next round_start,
// or a stale timer from an earlier (possibly shorter) round can fire
// mid-way through a later round and force-unlock/countdown the wrong
// round's door.
Handle g_hFindDoorTimer = null;
Handle g_hForceUnlockTimer = null;
Handle g_hCountdownTimer = null;

public Plugin myinfo = 
{
    name = "Safe Room Key System",
    author = "XP (built for your 8v8 XP server)",
    description = "Locked safe room with transferable key + force unlock + death timer",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("sm_saferoomkey_enabled", "1", "Enable Safe Room Key System");
    g_hKeyTimeout = CreateConVar("sm_saferoomkey_timeout", "75.0", "Seconds before force unlock if key not used");
    g_hCountdownTime = CreateConVar("sm_saferoomkey_countdown", "90.0", "Countdown timer after force unlock");
    
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("finale_vehicle_leaving", Event_FinaleEnd); // Backup trigger
}

public void OnMapStart()
{
    g_iKeyHolder = -1;
    g_bDoorLocked = true;
    g_bCountdownActive = false;
    // Timers are auto-killed by SourceMod on map change; just drop our
    // references so we don't try to KillTimer handles that are already gone.
    g_hFindDoorTimer = null;
    g_hForceUnlockTimer = null;
    g_hCountdownTimer = null;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Kill any timers still pending from the previous round before this
    // round's state (new door lock, new key holder) gets set up, so a
    // stale timer can't act on the new round using old assumptions.
    if (g_hFindDoorTimer != null) { KillTimer(g_hFindDoorTimer); g_hFindDoorTimer = null; }
    if (g_hForceUnlockTimer != null) { KillTimer(g_hForceUnlockTimer); g_hForceUnlockTimer = null; }
    if (g_hCountdownTimer != null) { KillTimer(g_hCountdownTimer); g_hCountdownTimer = null; }
    g_bCountdownActive = false;
    g_bDoorLocked = true;

    if (!g_hEnabled.BoolValue) return Plugin_Continue;

    g_hFindDoorTimer = CreateTimer(5.0, Timer_FindSafeRoomDoor);
    return Plugin_Continue;
}

// Backup safety net: if the finale ends (vehicle leaving = survivors won),
// force-unlock and reset state so nothing is left locked/counting down
// into the next round.
public Action Event_FinaleEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bCountdownActive = false;

    if (g_hForceUnlockTimer != null) { KillTimer(g_hForceUnlockTimer); g_hForceUnlockTimer = null; }
    if (g_hCountdownTimer != null) { KillTimer(g_hCountdownTimer); g_hCountdownTimer = null; }

    if (g_iSafeRoomDoor != -1 && g_bDoorLocked)
    {
        SetEntProp(g_iSafeRoomDoor, Prop_Data, "m_bLocked", 0);
        g_bDoorLocked = false;
    }

    return Plugin_Continue;
}

public Action Timer_FindSafeRoomDoor(Handle timer)
{
    g_hFindDoorTimer = null;

    // Find saferoom door entity (common in most maps)
    // NOTE: matches by targetname, not classname - every prop_door_rotating
    // shares the same classname, so that never distinguished a saferoom door.
    // You'll likely need to adjust "saferoom" below to match the actual
    // targetname used on your target maps (varies by campaign).
    int door = -1;
    char doorName[64];
    while ((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
    {
        GetEntPropString(door, Prop_Data, "m_iName", doorName, sizeof(doorName));
        if (StrContains(doorName, "saferoom", false) != -1)
        {
            g_iSafeRoomDoor = door;
            LockDoor(door);
            AssignKeyToRandomSurvivor();
            g_hForceUnlockTimer = CreateTimer(g_hKeyTimeout.FloatValue, Timer_ForceUnlockTimeout);
            break;
        }
    }
    return Plugin_Continue;
}

// sm_saferoomkey_timeout fallback: if the key was never used to open the
// door, force it open anyway so a lost/disconnected key holder can't
// softlock the round.
public Action Timer_ForceUnlockTimeout(Handle timer)
{
    g_hForceUnlockTimer = null;

    if (g_bDoorLocked)
    {
        PrintToChatAll("\x04[Key System] \x01Timeout reached - force unlocking Safe Room.");
        UnlockDoor();
    }
    return Plugin_Continue;
}

void LockDoor(int door)
{
    if (door != -1)
    {
        SetEntProp(door, Prop_Data, "m_bLocked", 1);
        g_bDoorLocked = true;
        PrintToChatAll("\x04[Key System] \x01Safe Room door is \x03LOCKED\x01. Find the Key holder!");
    }
}

void AssignKeyToRandomSurvivor()
{
    int clients[MAXPLAYERS + 1];
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
        {
            clients[count++] = i;
        }
    }
    
    if (count > 0)
    {
        g_iKeyHolder = clients[GetRandomInt(0, count-1)];
        PrintToChatAll("\x04[Key System] \x03%N \x01has the Safe Room Key!", g_iKeyHolder);
        // Optional: Glow effect on key holder
        SetEntProp(g_iKeyHolder, Prop_Send, "m_iGlowType", 3);
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim == g_iKeyHolder && g_bDoorLocked)
    {
        PrintToChatAll("\x04[Key System] \x03Key holder died! Transferring key...");
        CreateTimer(1.0, Timer_TransferKey);
    }
    return Plugin_Continue;
}

public Action Timer_TransferKey(Handle timer)
{
    AssignKeyToRandomSurvivor();
    return Plugin_Continue;
}

// Player uses key on door (detect interaction)
public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (!g_bDoorLocked || client != g_iKeyHolder) return Plugin_Continue;
    
    if (buttons & IN_USE)
    {
        float pos[3];
        GetClientAbsOrigin(client, pos);

        float doorPos[3];
        if (g_iSafeRoomDoor != -1)
        {
            GetEntityOrigin(g_iSafeRoomDoor, doorPos);
            if (GetVectorDistance(pos, doorPos) < 150.0)
            {
                UnlockDoor();
            }
        }
    }
    return Plugin_Continue;
}

void UnlockDoor()
{
    if (g_iSafeRoomDoor != -1)
    {
        SetEntProp(g_iSafeRoomDoor, Prop_Data, "m_bLocked", 0);
        g_bDoorLocked = false;
        PrintToChatAll("\x04[Key System] \x03Safe Room Unlocked!");
        
        // Start countdown
        g_bCountdownActive = true;
        g_fCountdownEndTime = GetGameTime() + g_hCountdownTime.FloatValue;
        g_hCountdownTimer = CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT);
    }
}

public Action Timer_Countdown(Handle timer)
{
    if (!g_bCountdownActive)
    {
        g_hCountdownTimer = null;
        return Plugin_Stop;
    }

    float timeLeft = g_fCountdownEndTime - GetGameTime();

    if (timeLeft <= 0)
    {
        KillOutsideSurvivors();
        g_bCountdownActive = false;
        g_hCountdownTimer = null;
        return Plugin_Stop;
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
            PrintHintText(i, "Safe Room closes in: %.0f seconds!", timeLeft);
    }
    return Plugin_Continue;
}

void KillOutsideSurvivors()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
        {
            // Check if inside saferoom (simple distance check)
            if (g_iSafeRoomDoor != -1)
            {
                float pos[3];
                GetClientAbsOrigin(i, pos);
                float doorPos[3];
                GetEntityOrigin(g_iSafeRoomDoor, doorPos);
                if (GetVectorDistance(pos, doorPos) > 300.0)
                {
                    ForcePlayerSuicide(i);
                    PrintToChat(i, "\x04[Key System] You didn't make it inside in time!");
                }
            }
        }
    }
}

stock void GetEntityOrigin(int entity, float origin[3])
{
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
}