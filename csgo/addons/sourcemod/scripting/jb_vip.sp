#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sdktools>
#include <sourcemod>
#include <clientprefs>

#include <jb_core>
#include <jb_vip>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Jailbreak VIP Plugin",
	author = PLUGIN_AUTHOR,
	description = "Jailbreak VIP Plugin",
	version = PLUGIN_VERSION,
	url = ""
};

VipMode vips[MAXPLAYERS + 1] = VM_None;

Handle DB = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("IsClientVip", native_IsVip);
	CreateNative("IsClientExtraVip", native_IsExtraVip);

	RegPluginLibrary("jb_vip.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_hurt", OnPlayerHurtPost, EventHookMode_Post);
	
	AddCommandListener(SayHook, "say");
	AddCommandListener(SayHook, "say_team");
	
	char error[70];
	DB = SQL_Connect("AdminVip", true, error, sizeof(error));
	if (DB == INVALID_HANDLE)
	{
		PrintToServer("Cannot connect to SQL Server: %s", error);
		SetFailState(error);
		return;
	}
	
	PrintToServer("Connection to AdminVip database successful");
	
	RegAdminCmd("sm_addvip", CMD_AddVip, ADMFLAG_CUSTOM1, "Add VIP");
	RegAdminCmd("sm_addextravip", CMD_AddExtraVip, ADMFLAG_CUSTOM1, "Add ExtraVIP");
	RegAdminCmd("sm_removevip", CMDRemoveVip, ADMFLAG_CUSTOM1, "Remove VIP");
}

public void OnClientAuthorized(int client, const char[] auth)
{
	char query[150];
	Format(query, sizeof(query), "SELECT steamid, type FROM AdminVip WHERE steamid='%s'", auth);
	
	Handle queryH = SQL_Query(DB, query);
	if (queryH == INVALID_HANDLE)
	{
		char error[70];
		SQL_GetError(DB, error, sizeof(error));
		PrintToServer("Could not query message: %s", query);
		PrintToServer("Error: %s", error);
		return;
	}
	
	if (SQL_FetchRow(queryH))
	{
		char type[32];
		SQL_FetchString(queryH, 1, type, sizeof(type));
		if (StrEqual(type, "s"))
		{
			vips[client] = VM_Vip;
		}
		else if (StrEqual(type, "t"))
		{
			vips[client] = VM_ExtraVip;
		}
	}
	else
	{
		vips[client] = VM_None;
	}
}

public Action OnPlayerHurtPost(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int healthLeft = GetEventInt(event, "health");
	int damage = GetEventInt(event, "dmg_health");
	if (IsClientValid(attacker) && IsClientExtraVip(attacker) && victim != attacker)
	{
		PrintCenterText(attacker, "You hit <font color='#0000ff'> %N </font> for <font color='#ff0000'> %d </font> HP\n%d HP left", victim, damage, healthLeft);
	}
	
	return Plugin_Continue;
}

public Action SayHook(int client, const char[] command, int args)
{
	char szText[512];
	GetCmdArg(1, szText, sizeof(szText));
	if (!strcmp(szText, ""))
		return Plugin_Handled;
	
	char text[512];
	int team = GetClientTeam(client);
	if (!IsPlayerAlive(client))
	{
		Format(text, sizeof(text), "\x01(DEAD)");
	}
	
	char message[512];
	if (IsAdmin(client))
	{
		Format(message, sizeof(message), " \x07[URNA] \x04%N\x01 : \x10%s", client, szText);
	}
	else if (IsClientExtraVip(client))
	{
		Format(message, sizeof(message), " \x07[ExtraVIP] \x04%N\x01 : \x10%s", client, szText);
	}
	else if (IsClientVip(client))
	{
		Format(message, sizeof(message), " \x07[VIP] \x04%N\x01 : %s", client, szText);
	}
	else
	{
		if (team == CS_TEAM_T)
			Format(message, sizeof(message), " \x09 %N \x01: %s", client, szText);
		else if (team == CS_TEAM_CT)
			Format(message, sizeof(message), " \x0B %N \x01: %s", client, szText);
		else
			Format(message, sizeof(message), " \x01 %N \x01: %s", client, szText);
	}
	
	StrCat(text, sizeof(text), message);
	
	if (StrEqual(command, "say_team"))
	{
		if (team == CS_TEAM_T)
			PrintToChatTeam(team, true, " \x09 ● \x01(Prisoner Chat) %s", text);
		else if (team == CS_TEAM_CT)
			PrintToChatTeam(team, true, " \x09 ● \x01(Guard Chat) %s", text);
		else
			PrintToChatTeam(team, true, " \x09 ● \x01(Spectator Chat) %s", text);
	}
	else
		PrintToChatAll(" \x09 ● %s", text);
	
	return Plugin_Handled;
}

void AddToDatabase(int client, char[] steamid, char[] type, int length)
{
	char time[32];
	Format(time, sizeof(time), "%d/%m/%Y, %H:%M:%S", GetTime());
	
	char query[300];
	Format(query, sizeof(query), "INSERT INTO AdminVip (steamid, type, time, length) VALUES ('%s', '%s', '%s', '%d')", steamid, type, time, length);
	
	Handle queryH = SQL_Query(DB, query);
	if (queryH == INVALID_HANDLE)
	{
		char error[70];
		SQL_GetError(DB, error, sizeof(error));
		ReplyToCommand(client, "Could not query message: %s", query);
		ReplyToCommand(client, "Error: %s", error);
		return;
	}
	
	ReplyToCommand(client, "Added to database");
}

bool IsSteamidInDatabase(const char[] steamid)
{
	char query[150];
	Format(query, sizeof(query), "SELECT steamid FROM AdminVip WHERE steamid='%s'", steamid);
	Handle queryH = SQL_Query(DB, query);
	if (queryH == INVALID_HANDLE)
	{
		char error[70];
		SQL_GetError(DB, error, sizeof(error));
		PrintToServer("Could not query message: %s", query);
		PrintToServer("Error: %s", error);
		return false;
	}
	
	if (SQL_FetchRow(queryH))
	{
		return true;
	}
	
	return false;
}

void RemoveFromDatabase(int client, const char[] steamid)
{
	if (!IsSteamidInDatabase(steamid))
	{
		ReplyToCommand(client, "Unable to find steamid '%s' in database", steamid);
		return;
	}
	
	char query[300];
	Format(query, sizeof(query), "DELETE FROM AdminVip WHERE steamid='%s'", steamid);
	
	Handle queryH = SQL_Query(DB, query);
	if (queryH == INVALID_HANDLE)
	{
		char error[70];
		SQL_GetError(DB, error, sizeof(error));
		ReplyToCommand(client, "Could not query message: %s", query);
		ReplyToCommand(client, "Error: %s", error);
		return;
	}
	
	ReplyToCommand(client, "Removed from VIP");
}

public Action CMD_AddVip(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_addvip <steamid1>");
		return Plugin_Handled;
	}
	
	char steamid[32];
	GetCmdArgString(steamid, sizeof(steamid));
	
	AddToDatabase(client, steamid, "s", 30);
	
	return Plugin_Handled;
}

public Action CMD_AddExtraVip(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_addvip <steamid1>");
		return Plugin_Handled;
	}
	
	char steamid[32];
	GetCmdArgString(steamid, sizeof(steamid));
	
	AddToDatabase(client, steamid, "t", 30);
	
	return Plugin_Handled;
}

public Action CMDRemoveVip(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "Usage: sm_removevip <steamid>");
		return Plugin_Handled;
	}
	
	char steamid[32];
	GetCmdArgString(steamid, sizeof(steamid));
	
	RemoveFromDatabase(client, steamid);
	return Plugin_Handled;
}

// native bool IsVip(int client);
public int native_IsVip(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return (vips[client] == VM_Vip || vips[client] == VM_ExtraVip);
}

// native bool IsExtraVip(int client);
public int native_IsExtraVip(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return (vips[client] == VM_ExtraVip);
}
