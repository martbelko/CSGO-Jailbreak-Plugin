#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>

#pragma newdecls required

#include <jb_core>
#include <jb_lastrequest>

static ConVar sv_alltalk = null;
static ConVar sv_deadtalk = null;
static ConVar sv_full_alltalk = null;
static ConVar sv_talk_enemy_dead = null;
static ConVar sv_talk_enemy_living = null;

static float g_Min = 300.0;

static Handle g_DoorList;

static EngineVersion s_GameEngine;

static int s_OffsetGroundEnt;

// For djump
static int g_fLastButtons[MAXPLAYERS + 1];
static int g_fLastFlags[MAXPLAYERS + 1];
static int g_iJumps[MAXPLAYERS + 1];
static int g_iJumpMax = 1;
static int s_DJumpPlayer[MAXPLAYERS + 1] = { false };

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("Disarm", native_Disarm);
	CreateNative("DisarmIn", native_DisarmIn);
	CreateNative("GivePlayerItemIn", native_GivePlayerItemIn);
	CreateNative("HasWeapon", native_HasWeapon);
	CreateNative("GetEntitiesDistance", native_GetEntitiesDistance);
	CreateNative("SetPlayerArmor", native_SetPlayerArmor);
	CreateNative("SetPlayerHelmet", native_SetPlayerHelmet);
	CreateNative("SetPlayerHeavySuit", __SetPlayerHeavySuit);
	CreateNative("GetRandomPlayer", native_GetRandomPlayer);
	CreateNative("GetNumberOfPlayers", native_GetNumberOfPlayers);
	CreateNative("AddPlayersToMenuSelection", native_AddPlayersToMenuSelection);
	CreateNative("GivePlayerAmmoEx", native_GivePlayerAmmoEx);
	CreateNative("SetPlayerAmmo", native_SetPlayerAmmo);
	CreateNative("SetPlayerMagAmmo", native_SetPlayerMagAmmo);
	CreateNative("SetNoScope", native_SetNoScope);
	CreateNative("ChickenFightCheck", native_ChickenFightCheck);
	CreateNative("DropPlayerWeapons", native_DropPlayerWeapons);
	CreateNative("OpenDoors", native_OpenDoors);
	CreateNative("CloseDoors", native_CloseDoors);
	CreateNative("SetPlayerInvisible", native_SetPlayerInvisible);
	CreateNative("SetPlayerVisible", native_SetPlayerVisible);
	CreateNative("IsPlayerInvisible", native_IsPlayerInvisible);
	CreateNative("EmitSoundToAny", __EmitSoundToAny);
	CreateNative("EmitSoundToAllAny", __EmitSoundToAllAny);
	CreateNative("IsVisibleTo", __IsVisibleTo);
	CreateNative("EnableDoubleJump", __EnableDoubleJump);

	RegPluginLibrary("jb_core.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	s_GameEngine = GetEngineVersion();
	if(s_GameEngine != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");
	}
	
	g_DoorList = CreateArray();
	
	// Hooks
	HookEvent("round_start", OnRoundStart);
	
	// Convars
	sv_alltalk = FindConVar("sv_alltalk");
	sv_deadtalk = FindConVar("sv_deadtalk");
	sv_full_alltalk = FindConVar("sv_full_alltalk");
	sv_talk_enemy_dead = FindConVar("sv_talk_enemy_dead");
	sv_talk_enemy_living = FindConVar("sv_talk_enemy_living");
	
	// Offsets
	s_OffsetGroundEnt = FindSendPropInfo("CBasePlayer", "m_hGroundEntity");
	
	// Commands
	RegAdminCmd("sm_opendoors", CMDOpenDoors, ADMFLAG_CHEATS, "Open Jailbreak doors");
	RegAdminCmd("sm_closedoors", CMDCloseDoors, ADMFLAG_CHEATS, "Close Jailbreak doors");
	RegAdminCmd("sm_visible", CMDVisible, ADMFLAG_CHEATS, "Make player visible");
	RegAdminCmd("sm_invisible", CMDInvisible, ADMFLAG_CHEATS, "Make player invisible");
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i))
			OnClientDisconnect(i);
}

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/music/urna_jailbreak/wheelOfFortune.mp3");
	
	PrecacheSound("music/urna_jailbreak/wheelOfFortune.mp3");
	
	CacheDoors();
	
	ServerCommand("exec jailbreak.cfg");
	ServerCommand("bot_kick");
}

public void OnMapEnd()
{
	ClearArray(g_DoorList);
}

public void OnClientDisconnect(int client)
{
	s_DJumpPlayer[client] = false;
}

public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && s_DJumpPlayer[i])
		{
			DoubleJump(i);
		}
	}
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Forcing sv_full_alltalk etc
	if(sv_alltalk != null)
		sv_alltalk.BoolValue = true;
	if(sv_deadtalk != null)
		sv_deadtalk.BoolValue = true;
	if(sv_full_alltalk != null)
		sv_full_alltalk.BoolValue = true;
	if(sv_talk_enemy_dead != null)
		sv_talk_enemy_dead.BoolValue = true;
	if(sv_talk_enemy_living != null)
		sv_talk_enemy_living.BoolValue = true;
		
	ServerCommand("bot_kick");
}

/* This is for complete disarming on round start */
public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "game_player_equip", false))
	{
		SDKHook(entity, SDKHook_Spawn, OnEntitySpawn);
	}
}

public Action OnEntitySpawn(int entity)
{
	if (!(GetEntProp(entity, Prop_Data, "m_spawnflags") & 1))
	{
		SetEntProp(entity, Prop_Data, "m_spawnflags", GetEntProp(entity, Prop_Data, "m_spawnflags") | 2);
	}
	
	return Plugin_Continue;
}

public Action CMDOpenDoors(int client, int args)
{
	OpenDoors();
	return Plugin_Handled;
}

public Action CMDCloseDoors(int client, int args)
{
	CloseDoors();
	return Plugin_Handled;
}

public Action CMDInvisible(int client, int argc)
{
	if (argc != 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_invisible <target>");
		return Plugin_Handled;
	}
	
	char buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	int targetList[MAXPLAYERS];
	char targetName[MAX_NAME_LENGTH];
	bool tn_is_ml;
	int targetCount = ProcessTargetString(buffer, client, targetList, MAXPLAYERS, COMMAND_FILTER_ALIVE | COMMAND_FILTER_CONNECTED, targetName, MAX_NAME_LENGTH, tn_is_ml);
	if (targetCount <= 0)
	{
		ReplyToCommand(client, "[URNA] No matching clients were found");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < targetCount; ++i)
	{
		SetPlayerInvisible(targetList[i]);
		ReplyToCommand(client, "[URNA] %N is now invisible", targetList[i]);
	}
	
	return Plugin_Handled;
}

public Action CMDVisible(int client, int argc)
{
	if (argc != 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_visible <target>");
		return Plugin_Handled;
	}
	
	char buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	int targetList[MAXPLAYERS];
	char targetName[MAX_NAME_LENGTH];
	bool tn_is_ml;
	int targetCount = ProcessTargetString(buffer, client, targetList, MAXPLAYERS, COMMAND_FILTER_ALIVE | COMMAND_FILTER_CONNECTED, targetName, MAX_NAME_LENGTH, tn_is_ml);
	if (targetCount <= 0)
	{
		ReplyToCommand(client, "[URNA] No matching clients were found");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < targetCount; ++i)
	{
		SetPlayerVisible(targetList[i]);
		ReplyToCommand(client, "[URNA] %N is now visible", targetList[i]);
	}
	
	return Plugin_Handled;
}

// void AddSkin(const char[] path)
public int __AddSkin(Handle plugin, int numParams)
{

}

// void Disarm(int client, bool removeArmor)
public int native_Disarm(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool removeArmor = GetNativeCell(2);
	for (int i = 0; i < 10; ++i)
	{
		int weapon = -1;
		while ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
		{
			if (IsValidEntity(weapon))
			{
				RemovePlayerItem(client, weapon);
				RemoveEdict(weapon);
			}
		}
	}
	
	if (removeArmor)
	{
		SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", false);
		SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
		SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
	}
}

// int DisarmIn(float time, int client, bool removeArmor);
public int native_DisarmIn(Handle plugin, int numParams)
{
	float time = GetNativeCell(1);
	int client = GetNativeCell(2);
	bool removeArmor = GetNativeCell(3);
	
	Handle kv = CreateKeyValues("data");
	KvSetNum(kv, "client", client);
	KvSetNum(kv, "removeArmor", removeArmor);
	
	CreateTimer(time, timerDisarm, kv);
}

public Action timerDisarm(Handle timer, Handle data)
{
	int client = KvGetNum(data, "client");
	bool removeArmor = view_as<bool>(KvGetNum(data, "removeArmor"));
	Disarm(client, removeArmor);
	
	CloseHandle(data);
}

// void DropPlayerWeapons(int client);
public int native_DropPlayerWeapons(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	for (int i = 0; i < 10; ++i)
	{
		int weapon = -1;
		while ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
		{
			SDKHooks_DropWeapon(client, weapon);
		}
	}
}

// int GivePlayerItemIn(float time, int client, const char[] weaponName);
public int native_GivePlayerItemIn(Handle plugin, int numParams)
{
	float time = GetNativeCell(1);
	int client = GetNativeCell(2);
	char weaponName[64];
	GetNativeString(3, weaponName, sizeof(weaponName));
	
	Handle kv = CreateKeyValues("data");
	KvSetNum(kv, "client", client);
	KvSetString(kv, "weaponName", weaponName);
	
	CreateTimer(time, timerGivePlayerItem, kv);
}

public Action timerGivePlayerItem(Handle timer, Handle data)
{
	int client = KvGetNum(data, "client");
	if (IsClientValid(client) && IsPlayerAlive(client))
	{
		char weaponName[64];
		KvGetString(data, "weaponName", weaponName, sizeof(weaponName));
		GivePlayerItem(client, weaponName);
	}
	
	CloseHandle(data);
}

// bool HasWeapon(int client, const char[] weaponName);
public int native_HasWeapon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char classname[64];
	GetNativeString(2, classname, sizeof(classname));

	int index;
	int weapon;
	char sName[64];
    
	while ((weapon = GetNextWeapon(client, index)) != -1)
	{
		GetEdictClassname(weapon, sName, sizeof(sName));
		if (StrEqual(sName, classname))
			return true;
	}
    
	return false;
}

int GetNextWeapon(int client, int &weaponIndex)
{
    static int weaponsOffset = -1;
    if (weaponsOffset == -1)
        weaponsOffset = FindDataMapInfo(client, "m_hMyWeapons");
    
    int offset = weaponsOffset + (weaponIndex * 4);
    
    int weapon;
    while (weaponIndex < 48) 
    {
        ++weaponIndex;
        
        weapon = GetEntDataEnt2(client, offset);
        
        if (IsValidEdict(weapon)) 
            return weapon;
        
        offset += 4;
    }
    
    return -1;
}

// float GetEntitiesDistance(int entity1, int entity2);
public int native_GetEntitiesDistance(Handle plugin, int numParams)
{
	int ent1 = GetNativeCell(1);
	int ent2 = GetNativeCell(2);
	
	float orig1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", orig1);
	
	float orig2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", orig2);

	return view_as<int>(GetVectorDistance(orig1, orig2));
}

// void SetPlayerArmor(int client, int armor);
public int native_SetPlayerArmor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int armorValue = GetNativeCell(2);
	
	SetEntProp(client, Prop_Send, "m_ArmorValue", armorValue);
	
	return 0;
}

// void SetPlayerHelmet(int client, bool helmet);
public int native_SetPlayerHelmet(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool helmet = GetNativeCell(2);
	
	SetEntProp(client, Prop_Send, "m_bHasHelmet", helmet);
	
	return 0;
}

// void SetPlayerHeavySuit(int client, bool enable);
public int __SetPlayerHeavySuit(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool enable = GetNativeCell(2);
	
	SetEntProp(client, Prop_Send, "m_bHasHeavyArmor", enable);
	
	return 0;
}

// int GetRandomPlayer(int team, bool aliveOnly = true);
public int native_GetRandomPlayer(Handle plugin, int numParams)
{
	int team = GetNativeCell(1);
	bool aliveOnly = GetNativeCell(2);
	
	ArrayList ValidClients = new ArrayList();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientValid(i) && GetClientTeam(i) == team && (aliveOnly ? IsPlayerAlive(i) : true))
		{
			ValidClients.Push(i);
		}
	}
    
	int randomClient = (ValidClients.Length > 0 ? ValidClients.Get(GetRandomInt(0, ValidClients.Length - 1)) : -1);
	delete ValidClients;
	return randomClient;
}

// int GetNumberOfPlayers(int team, bool aliveOnly);
public int native_GetNumberOfPlayers(Handle plugin, int numParams)
{
	int team = GetNativeCell(1);
	bool aliveOnly = GetNativeCell(2);
	int count = 0;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientValid(i) && (team == CS_TEAM_NONE || GetClientTeam(i) == team))
		{
			if (aliveOnly)
			{
				if (IsPlayerAlive(i))
					++count;
			}
			else
				++count;
		}
	}
	
	return count;
}

// void AddPlayersToMenuSelection(Menu menu, int team, bool aliveOnly, int ignorePlayer);
public int native_AddPlayersToMenuSelection(Handle plugin, int numParams)
{
	Menu menu = GetNativeCell(1);
	int team = GetNativeCell(2);
	bool aliveOnly = GetNativeCell(3);
	int ignorePlayer = GetNativeCell(4);
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientValid(i) && i != ignorePlayer)
		{
			if (team == CS_TEAM_NONE || team == GetClientTeam(i))
			{
				if (aliveOnly)
				{
					if (IsPlayerAlive(i))
					{
						char name[MAX_NAME_LENGTH];
						GetClientName(i, name, sizeof(name));
						char clientNumberString[3];
						IntToString(i, clientNumberString, sizeof(clientNumberString));
						menu.AddItem(clientNumberString, name);
					}
				}
				else
				{
					char name[MAX_NAME_LENGTH];
					GetClientName(i, name, sizeof(name));
					char clientNumberString[3];
					IntToString(i, clientNumberString, sizeof(clientNumberString));
					menu.AddItem(clientNumberString, name);
				}
			}
		}
	}
	
	return 0;
}

// void GivePlayerAmmoEx(int client, int weapon, int amount, bool supressSound);
public int native_GivePlayerAmmoEx(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int weapon = GetNativeCell(2);
	int amount = GetNativeCell(3);
	bool supressSound = GetNativeCell(4);
	GivePlayerAmmo(client, amount, GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType"), supressSound);
}

// void SetPlayerAmmo(int client, int weapon, int amount);
public int native_SetPlayerAmmo(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int weapon = GetNativeCell(2);
	int amount = GetNativeCell(3);
	
	int ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", amount);
	SetEntProp(client, Prop_Send, "m_iAmmo", amount, _, ammotype);
}

// void SetPlayerMagAmmo(int weapon, int amount);
public int native_SetPlayerMagAmmo(Handle plugin, int numParams)
{
	int weapon = GetNativeCell(1);
	int amount = GetNativeCell(2);
	SetEntProp(weapon, Prop_Send, "m_iClip1", amount);
}

// void SetNoScope(int weapon);
public int native_SetNoScope(Handle plugin, int numParams)
{
	int weapon = GetNativeCell(1);
	if (IsValidEdict(weapon))
	{
		char classname[MAX_NAME_LENGTH];
		GetEdictClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname[7], "ssg08") || StrEqual(classname[7], "aug") || StrEqual(classname[7], "sg550") || StrEqual(classname[7], "sg552") || StrEqual(classname[7], "sg556") || StrEqual(classname[7], "awp") || StrEqual(classname[7], "scar20") || StrEqual(classname[7], "g3sg1"))
			SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 2.0);
	}
}

// int ChickenFightCheck(int client1, int client2);
public int native_ChickenFightCheck(Handle plugin, int numParams)
{
	int client1 = GetNativeCell(1);
	int client2 = GetNativeCell(2);
	
	int p1EntityBelow = GetEntDataEnt2(client1, s_OffsetGroundEnt);
	int p2EntityBelow = GetEntDataEnt2(client2, s_OffsetGroundEnt);
	
	if (p1EntityBelow == client2)
		return client1;
	else if (p2EntityBelow == client1)
		return client2;
	return -1;
}

// void OpenDoors();
public int native_OpenDoors(Handle plugin, int numParams)
{
	for(int i = 0; i < GetArraySize(g_DoorList); i++)
	{
		int door = GetArrayCell(g_DoorList, i);
		AcceptEntityInput(door, "Open");
	}
}

// void CloseDoors();
public int native_CloseDoors(Handle plugin, int numParams)
{
	for(int i = 0; i < GetArraySize(g_DoorList); i++)
	{
		int door = GetArrayCell(g_DoorList, i);
		AcceptEntityInput(door, "Close");
	}
}

void CacheDoors()
{
	int ent = -1;
	int door = -1;
	
	while((ent = FindEntityByClassname(ent, "info_player_terrorist")) != -1)
	{
		float prisoner_pos[3];
		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", prisoner_pos);
		
		while((door = FindEntityByClassname(door, "func_door")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				g_Min = GetVectorDistance(door_pos, prisoner_pos);
			}
		}
		
		while((door = FindEntityByClassname(door, "func_door_rotating")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				g_Min = GetVectorDistance(door_pos, prisoner_pos);
			}
		}
		
		while((door = FindEntityByClassname(door, "func_movelinear")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				g_Min = GetVectorDistance(door_pos, prisoner_pos);
			}
		}
		
		while((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				g_Min = GetVectorDistance(door_pos, prisoner_pos);
			}
		}
	}
	
	g_Min += 100;
	
	while((ent = FindEntityByClassname(ent, "info_player_terrorist")) != -1)
	{
		float prisoner_pos[3];
		GetEntPropVector(ent, Prop_Data, "m_vecOrigin", prisoner_pos);
		
		while((door = FindEntityByClassname(door, "func_door")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				PushArrayCell(g_DoorList, door);
			}
		}
		
		while((door = FindEntityByClassname(door, "func_door_rotating")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				PushArrayCell(g_DoorList, door);
			}
		}
		
		while((door = FindEntityByClassname(door, "func_movelinear")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				PushArrayCell(g_DoorList, door);
			}
		}
		
		while((door = FindEntityByClassname(door, "prop_door_rotating")) != -1)
		{
			float door_pos[3];
			GetEntPropVector(door, Prop_Data, "m_vecOrigin", door_pos);
			
			if(GetVectorDistance(door_pos, prisoner_pos) <= g_Min)
			{
				PushArrayCell(g_DoorList, door);
			}
		}
	}
}

// void SetPlayerInvisible(int client);
public int native_SetPlayerInvisible(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	SetEntityRenderMode(client, RENDER_NONE);
}

// void SetPlayerVisible(int client);
public int native_SetPlayerVisible(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
}

// bool IsPlayerInvisible(int client);
public int native_IsPlayerInvisible(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return GetEntityRenderMode(client) == RENDER_NONE;
}

// void EmitSoundToAny(int client, const char[] path)
public int __EmitSoundToAny(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (IsClientValid(client))
	{
		int len;
		GetNativeStringLength(2, len);
		char[] path = new char[len + 1];
		GetNativeString(2, path, len + 1);
		char command[100] = "play ";
		StrCat(command, sizeof(command), path);
		ClientCommand(client, command);
	}
}

// void EmitSoundToAllAny(const char[] path)
public int __EmitSoundToAllAny(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	char[] path = new char[len + 1];
	GetNativeString(1, path, len + 1);
	char command[100] = "play ";
	StrCat(command, sizeof(command), path);
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientValid(i))
			ClientCommand(i, command);
}

bool _DI_TraceFilter(int entity, int contentsMask, any client)
{
	if (entity == client)
		return false;
	return true;
} 

// bool IsVisibleTo(int client, int entity);
public int __IsVisibleTo(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int entity = GetNativeCell(2);
	float vAngles[3], vOrigin[3], vEnt[3], vLookAt[3];
    
	GetClientEyePosition(client,vOrigin);
	GetClientAbsOrigin(entity, vEnt);
    
	MakeVectorFromPoints(vOrigin, vEnt, vLookAt);
    
	GetVectorAngles(vLookAt, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_PLAYERSOLID, RayType_Infinite, _DI_TraceFilter, client);

	bool isVisible = false;
	if (TR_DidHit(trace))
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace);
		int target = TR_GetEntityIndex(trace);
		if (target == entity)
        	isVisible = true;
	}
	
	CloseHandle(trace);
	return isVisible;
}

// native void EnableDoubleJump(int client, bool enable);
public int __EnableDoubleJump(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool enable = GetNativeCell(2);
	s_DJumpPlayer[client] = enable;
	return 0;
}

void DoubleJump(int client)
{
	int fCurFlags = GetEntityFlags(client), fCurButtons = GetClientButtons(client);
	if (g_fLastFlags[client] & FL_ONGROUND)
	{
		if (!(fCurFlags & FL_ONGROUND) && !(g_fLastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
		{
			OriginalJump(client);
		}
	}
	else if (fCurFlags & FL_ONGROUND)
	{
		Landed(client);
	}
	else if (!(g_fLastButtons[client] & IN_JUMP) && fCurButtons & IN_JUMP)
	{
		ReJump(client);
	}
	
	g_fLastFlags[client] = fCurFlags;
	g_fLastButtons[client] = fCurButtons;
}

void OriginalJump(const any client)
{
	g_iJumps[client]++;
}

void Landed(const any client)
{
	g_iJumps[client] = 0;
}

void ReJump(const any client)
{
	if (1 <= g_iJumps[client] <= g_iJumpMax)
	{
		g_iJumps[client]++;
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		
		vVel[2] = 250.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}
