#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <float>

#include <jb_core>
#include <jb_warden>
#include <jb_lastrequest>
#include <jb_vip>
#include <jb_menu>
#include <jb_jailbreak>
#include <BanSystem>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Jailbreak Plugin",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

#define RATIO_T_ON_CT 3
#define RATIO_TOLERANCE 1

#define MUTE_TIME_T 30.0

#define RULES_STRING "Read rules on this website: http://urna.smsmc.net/"

static char s_OriginalNames[MAXPLAYERS + 1][MAX_NAME_LENGTH];
static bool g_Rebels[MAXPLAYERS + 1];
static ArrayList s_Owners;

bool s_AllowDropWeapons = true;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("IsRebel", __IsRebel);
	CreateNative("GetRules", __GetRules);

	RegPluginLibrary("jb_jailbreak.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_connect_full", OnFullConnectPost, EventHookMode_Post);
	HookEvent("round_start", OnRoundStartPost, EventHookMode_Pre);
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("player_team", OnPlayerTeam, EventHookMode_Post);
	
	HookUserMessage(GetUserMessageId("SayText2"), SayText2, true);
	
	AddCommandListener(AltJoin, "jointeam");
	
	RegConsoleCmd("sm_rules", CMDRules, "Rules");
	
	s_Owners = new ArrayList(sizeof(Handle));
	
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public Action SayText2(UserMsg msg_id, Handle bf, players[], int playersNum, bool reliable, bool init)
{
    if (!reliable)
        return Plugin_Continue;

    char buffer[25];
    if (GetUserMessageType() == UM_Protobuf) // CSGO
    {
        PbReadString(bf, "msg_name", buffer, sizeof(buffer));
        if (StrEqual(buffer, "#Cstrike_Name_Change"))
            return Plugin_Handled;
    }
    else // CSS
    {
        BfReadChar(bf);
        BfReadChar(bf);
        BfReadString(bf, buffer, sizeof(buffer));
        if (StrEqual(buffer, "#Cstrike_Name_Change"))
            return Plugin_Handled;
    }
    
    return Plugin_Continue;
} 

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_SpawnPost, OnPlayerSpawnPost);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	
	GetClientName(client, s_OriginalNames[client], MAX_NAME_LENGTH);
}

public Action AltJoin(int client, const char[] command, int argc)
{
	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));
	int teamJoin = StringToInt(arg);
	if (teamJoin == CS_TEAM_NONE) // Autojoin
	{
		PrintCenterText(client, "You can't auto join");
		return Plugin_Handled;
	}
	
	if (teamJoin == CS_TEAM_SPECTATOR)
	{
		if (IsAdmin(client))
		{
			if (IsPlayerAlive(client))
				ForcePlayerSuicide(client); // Restart round if last alive player join specs
			
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
			return Plugin_Continue;
		}
		
		PrintCenterText(client, "You can't join spectator");
		return Plugin_Handled;
	}
	
	if (teamJoin == CS_TEAM_CT)
	{
		char auth[32];
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
		if (IsBanned(auth, "", 0))
		{
			PrintCenterText(client, "Máš CT ban");
			return Plugin_Handled;
		}
		
		int team = GetClientTeam(client);
		int tPlayers = GetNumberOfPlayers(CS_TEAM_T, false);
		int ctPlayers = GetNumberOfPlayers(CS_TEAM_CT, false) + 1;
		if (ctPlayers == 1) // If CT team is empty
		{
			ChangeClientTeam(client, CS_TEAM_CT);
			return Plugin_Continue;
		}
		
		if (team == CS_TEAM_T)
			--tPlayers;
		
		int x = Balance(tPlayers, ctPlayers);
		if (x > 0)
		{
			PrintCenterText(client, "CT team is full!");
			return Plugin_Handled;
		}
	}
	
	ChangeClientTeam(client, teamJoin);
	return Plugin_Continue;
}

int Balance(int tPlayers, int ctPlayers)
{
	float den = float(RATIO_T_ON_CT + RATIO_TOLERANCE);
	float x = (ctPlayers * RATIO_T_ON_CT - RATIO_TOLERANCE - tPlayers) / den;
	return RoundToCeil(x);
}

public Action OnRoundStartPost(Handle event, const char[] name, bool dontBroadcast)
{
	s_AllowDropWeapons = false;
	CreateTimer(0.1, TimerCallbackSwap);
	for (int i = 0; i < s_Owners.Length; ++i)
		CloseHandle(s_Owners.Get(i));
	s_Owners.Clear();
}

public Action TimerCallbackSwap(Handle timer, any data)
{
	int tPlayers = GetNumberOfPlayers(CS_TEAM_T, false);
	int ctPlayers = GetNumberOfPlayers(CS_TEAM_CT, false);
	if (tPlayers + ctPlayers == 1) // If CT team is empty
		return Plugin_Handled;
	if (tPlayers == 1 && ctPlayers == 1) // If its 1v1
		return Plugin_Handled;
		
	int x = Balance(tPlayers, ctPlayers);
	if (x > 0)
	{
		for (int i = 0; i < x; ++i)
		{
			int client = GetRandomPlayer(CS_TEAM_CT, false);
			CS_SwitchTeam(client, CS_TEAM_T);
			if (IsPlayerAlive(client))
				CS_RespawnPlayer(client);
		}
	}
	
	return Plugin_Handled;
}

public Action OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (IsClientValid(attacker) && GetClientTeam(victim) == CS_TEAM_CT && GetClientTeam(attacker) == CS_TEAM_T /*&& !IsLrInProgress()*/ && !g_Rebels[attacker])
	{
		g_Rebels[attacker] = true;
	}
	
	return Plugin_Continue;
}

public Action OnPlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsClientValid(victim) && !IsAdmin(victim))
	{
		SetClientListeningFlags(victim, VOICE_MUTED);
		PrintToChat(victim, " \x04 Si mutnutý do ďalšieho respawnu");
	}
}

public Action OnPlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetEventInt(event, "team");
	if (IsClientValid(client) && !IsAdmin(client))
	{
		if (team == CS_TEAM_T)
		{
			if (IsClientVip(client) && IsPlayerAlive(client))
				SetClientListeningFlags(client, VOICE_NORMAL);
			else
				SetClientListeningFlags(client, VOICE_MUTED);
		}
		else if (team == CS_TEAM_CT)
		{
			if (IsPlayerAlive(client))
				SetClientListeningFlags(client, VOICE_NORMAL);
		}
	}
}

public Action OnFullConnectPost(Handle event, const char[] name_t, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientValid(client) || IsFakeClient(client) || IsClientSourceTV(client))
		return Plugin_Continue;

	ChangeClientTeam(client, CS_TEAM_T);
	CreateTimer(1.0, TimerCallbackChangeClan, GetClientUserId(client));
	return Plugin_Continue;
}

public Action TimerCallbackChangeClan(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsClientValid(client))
	{
		if (IsAdmin(client))
			CS_SetClientClanTag(client, "[URNA]");
		else if (IsClientExtraVip(client))
			CS_SetClientClanTag(client, "ExtraVIP");
		else if (IsClientVip(client))
			CS_SetClientClanTag(client, "VIP");
		else
			CS_SetClientClanTag(client, "");
	}
}

public Action OnPlayerSpawnPost(int client)
{
	if (IsAdmin(client))
		CS_SetClientClanTag(client, "[URNA]");
	else if (IsClientExtraVip(client))
		CS_SetClientClanTag(client, "ExtraVIP");
	else if (IsClientVip(client))
		CS_SetClientClanTag(client, "VIP");
	else
		CS_SetClientClanTag(client, "");
	
	SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);
	
	int userid = GetClientUserId(client);
	CreateTimer(0.1, TimerShowPlayerHud, userid, TIMER_REPEAT);
	CreateTimer(0.1, TimerHideRadar, userid);
	CreateTimer(0.5, TImerCallbackGiveWeapons, userid);
	
	// TODO: Add check for sm_mute command
	if (!IsClientVip(client) && GetClientTeam(client) == CS_TEAM_T)
	{
		SetClientListeningFlags(client, VOICE_MUTED);
		PrintToChat(client, "You have been muted");
	}
	else
		SetClientListeningFlags(client, VOICE_NORMAL);
	
	g_Rebels[client] = false;
	
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3])
{
	if (victim == attacker || attacker == 0)
		return Plugin_Continue;

	if (!IsClientValid(attacker) && IsClientValid(victim) && IsValidEntity(attacker) && attacker != 0)
	{
		char name[32];
		GetEntityClassname(attacker, name, sizeof(name));
		if (StrEqual(name, "weapon_melee"))
		{
			for (int i = 0; i < s_Owners.Length; ++i)
			{
				Handle kv = s_Owners.Get(i);
				int wepIndex = KvGetNum(kv, "weapon");
				if (wepIndex == attacker)
				{
					int team = KvGetNum(kv, "team");
					if (team == GetClientTeam(victim))
						return Plugin_Handled;
					
					int owner = KvGetNum(kv, "owner");
					if (IsClientValid(owner) && IsPlayerAlive(owner))
					{
						int damageDone = 30;
						int armor = GetClientArmor(victim);
						if (armor < 15)
							damageDone += (15 - armor) * 2;
						
						int healthLeft = GetClientHealth(victim) - damageDone;
						PrintCenterText(owner, "You hit <font color='#0000ff'> %N </font> for <font color='#ff0000'> %d </font> HP\n%d HP left", victim, damage, healthLeft);
						if (healthLeft <= 0)
						{
							AddPointsForFrag(victim, owner);
						}
					}
					
					return Plugin_Continue;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnWeaponDrop(int client, int weapon)
{
	if (!s_AllowDropWeapons)
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	/*if (IsArrested(client))
	{
		return Plugin_Handled;
	}
	if (GetActiveSimonGame() == SG_HIDE_AND_SEEK && GetClientTeam(client) == CS_TEAM_T && !StrEqual("weapon_fists", classname))
	{
		return Plugin_Handled;
	}*/
	if ((StrEqual(classname, "weapon_melee") || StrEqual(classname, "weapon_knife")) && ((!HasWeapon(client, "weapon_melee") && !HasWeapon(client, "weapon_knife"))))
 	{
 		EquipPlayerWeapon(client, weapon);
 		return Plugin_Continue;
    }
	else if (StrEqual(classname, "weapon_fists") && !HasWeapon(client, "weapon_fists"))
	{
		EquipPlayerWeapon(client, weapon);
		return Plugin_Continue;
	}
    
	return Plugin_Continue;
}

public Action OnWeaponEquipPost(int client, int weapon)
{
	if (IsValidEntity(weapon))
	{
		char name[32];
		GetEntityClassname(weapon, name, sizeof(name));
		if (StrEqual(name, "weapon_melee"))
		{
			// Try to find weapon index in dropped weapons
			for (int i = 0; i < s_Owners.Length; ++i)
			{
				Handle kv = s_Owners.Get(i);
				int index = KvGetNum(kv, "weapon");
				if (weapon == index)
				{
					KvSetNum(kv, "owner", client);
					KvSetNum(kv, "team", GetClientTeam(client));
				}
			}
			
			// If its new weapon, create and push
			Handle kv = CreateKeyValues("data");
			KvSetNum(kv, "weapon", weapon);
			KvSetNum(kv, "owner", client);
			KvSetNum(kv, "team", GetClientTeam(client));
			s_Owners.Push(kv);
		}
	}
}

public Action TimerShowPlayerHud(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsClientValid(client)) // if player disconnect or is dead
		return Plugin_Stop;
	
	int target = GetClientAimTarget(client, true);
	if (!IsClientValid(target))
		return Plugin_Handled;
		
	if (!IsVisibleTo(client, target))
		return Plugin_Handled;
	
	if (IsPlayerInvisible(target))
		return Plugin_Handled;
	
	if (GetClientTeam(client) == GetClientTeam(target))
		SetHudTextParams(-1.0, 0.59, 0.4, 0, 0, 255, 255, 1);
	else
		SetHudTextParams(-1.0, 0.59, 0.4, 255, 0, 0, 255, 1);
	
	if (IsClientVip(client))
		ShowHudText(client, 4, "%N [%d]", target, GetClientHealth(target));
	else
		ShowHudText(client, 4, "%N", target);
	
	return Plugin_Continue;
}

public Action TimerHideRadar(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsClientValid(client))
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | (1 << 12));
}

public Action TImerCallbackGiveWeapons(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (IsClientValid(client) && IsPlayerAlive(client))
	{
		Disarm(client, true);
		if (GetClientTeam(client) == CS_TEAM_T)
		{
			GivePlayerItem(client, "weapon_fists");
			if (IsClientExtraVip(client))
				GivePlayerItem(client, "weapon_knife");
			else if (IsClientVip(client))
				GivePlayerItem(client, "weapon_hammer");
		}
		else
		{
			GivePlayerItem(client, "weapon_fists");
			GivePlayerItem(client, "weapon_knife");
			GivePlayerItem(client, "weapon_usp_silencer");
			GivePlayerItem(client, "weapon_m4a1_silencer");
			SetPlayerArmor(client, 100);
			if (IsClientExtraVip(client))
				SetPlayerHelmet(client, true);
			if (IsClientVip(client))
				GivePlayerItem(client, "weapon_healthshot");
		}
	}
	
	s_AllowDropWeapons = true;
}

public Action CMDRules(int client, int argc)
{
	PrintToChat(client, RULES_STRING);
	return Plugin_Handled;
}

// bool IsRebel(int client);
public int __IsRebel(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_Rebels[client];
}

// void GetRules(int client, char[] rules, int maxLength);
public int __GetRules(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	if (IsClientValid(client))
	{
		// TODO: Translate
		int length = GetNativeCell(3);
		SetNativeString(2, RULES_STRING, length);
	}
	else
	{
		int length = GetNativeCell(3);
		SetNativeString(2, RULES_STRING, length);
	}
}
