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

#pragma newdecls required

public Plugin myinfo = 
{
	name = "BanSystem",
	author = PLUGIN_AUTHOR,
	description = "Ban System Plugin",
	version = PLUGIN_VERSION,
	url = ""
};

#define MAX_REASON_LENGTH 256

static Handle DB = INVALID_HANDLE;

public void OnPluginStart()
{
	RegAdminCmd("sm_ban", CMDBan, ADMFLAG_BAN, "Ban player");
}

void AddBan()
{
	
}

public Action CMDBan(int client, int args)
{
	if (!IsClientValid(client) || client == 0)
		return Plugin_Handled;
		
	if (args != 2 && args != 3)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_ban <#userid|name> <minutes|0> [reason]");
		return Plugin_Handled;
	}
	
	PrintToChatAll("%d", MAX_NAME_LENGTH);
	
	char victimStr[MAX_NAME_LENGTH];
	GetCmdArg(1, victimStr, sizeof(victimStr));
	char lengthStr[32];
	GetCmdArg(2, lengthStr, sizeof(lengthStr));
	int banLength = StringToInt(lengthStr, 10);
	char reason[MAX_REASON_LENGTH];
	if (args == 3)
		GetCmdArg(3, reason, sizeof(reason));
	else
		strcopy(reason, sizeof(reason), "NO REASON SPECIFIED");

	int targetList[MAXPLAYERS];
	char targetName[MAX_NAME_LENGTH];
	bool tn_is_ml;
	int targetCount = ProcessTargetString(victimStr, client, targetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, MAX_NAME_LENGTH, tn_is_ml);
	if (targetCount <= 0)
	{
		ReplyToCommand(client, "[URNA] No matching clients were found");
		return Plugin_Handled;
	}
	
	if (targetCount != 1)
	{
		ReplyToCommand(client, "[URNA] Multiple clients found");
		return Plugin_Handled;
	}
	
	int victim = targetList[0];
	if (!CanUserTarget(client, victim))
	{
		ReplyToCommand(client, "[URNA] Cannot target player %N", victim);
		return Plugin_Handled;
	}
	
	char adminAuth[32], victimAuth[32], victimName[MAX_NAME_LENGTH], adminName[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, adminAuth, sizeof(adminAuth));
	GetClientAuthId(victim, AuthId_Steam2, victimAuth, sizeof(victimAuth));
	
	
	return Plugin_Handled;
}
