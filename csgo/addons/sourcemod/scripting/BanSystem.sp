#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <float>

#include <BanSystem>
#include <jb_core>
#include <jb_jailbreak>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "BanSystem",
	author = PLUGIN_AUTHOR,
	description = "Ban System Plugin",
	version = PLUGIN_VERSION,
	url = ""
};

#define MAX_REASON_LENGTH 128

static Handle DB = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("IsBanned", __IsBanned);

	RegPluginLibrary("BanSystem.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegAdminCmd("sm_ban", CMDBan, ADMFLAG_BAN, "Ban player");
	RegAdminCmd("sm_addban", CMDAddBan, ADMFLAG_BAN, "Add ban by steamID");
	
	RegAdminCmd("sm_ctban", CMDBan, ADMFLAG_BAN, "CT Ban");
	RegAdminCmd("sm_addctban", CMDAddBan, ADMFLAG_BAN, "Add CT Ban");
	
	RegAdminCmd("sm_unban", CMDUnban, ADMFLAG_UNBAN, "Unban player");

	char error[256];
	DB = SQL_Connect("banlist", true, error, sizeof(error));
	if (DB == INVALID_HANDLE)
	{
		PrintToServer("Failed to connect to Banlist database: ERROR: %s", error);
		SetFailState(error);
	}
	else
	{
		PrintToServer("Connection to Banlist successful");
		CreateTimer(60.0, TimerCallbackRemoveBans, INVALID_HANDLE, TIMER_REPEAT);
	}
}

public void OnClientPostAdminCheck(int client)
{
	char auth[32];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	
	char query[128];
	Format(query, sizeof(query), "SELECT victimAuth, reason, type FROM Banlist WHERE victimAuth='%s'", auth);
	DBResultSet queryResult = SQL_Query(DB, query);
	if (queryResult == INVALID_HANDLE)
	{
		char error[256];
		SQL_GetError(DB, error, sizeof(error));
		PrintToServer("Error with Banlist database: %s", error);
		return;
	}
	
	if (SQL_FetchRow(queryResult))
	{
		BanType type = view_as<BanType>(queryResult.FetchInt(2));
		if (type == BT_NORMAL)
		{
			char reason[MAX_REASON_LENGTH];
			queryResult.FetchString(1, reason, sizeof(reason));
			KickClient(client, "You are banned. Reason: %s", reason);
			
			PrintToChatAll(" \x07 [URNA] Hráč %N\x07(%s) sa nemôže pripojiť, pretože je zabanovaný. Dôvod: %s", client, auth, reason);
		}
	}
	
	CloseHandle(queryResult);
}

bool AddSqlBan(const char[] adminAuth, const char[] adminName, const char[] targetAuth, const char[] targetName, const char[] reason, int banLength, BanType type, char[] error, int errorLength)
{
	int curTime = GetTime();
	char timeFormat[32];
	FormatTime(timeFormat, sizeof(timeFormat), "%d/%m/%Y, %H:%M:%S", curTime);
	
	char query[256];
	Format(query, sizeof(query), "INSERT INTO Banlist VALUES ('%s', '%s', '%s', '%s', '%s', '%i', '%i', '%s', '%i')", adminName, adminAuth, targetName, targetAuth, reason, banLength, view_as<int>(type), timeFormat, curTime);
	DBResultSet queryResult = SQL_Query(DB, query);
	if (queryResult == INVALID_HANDLE)
	{
		SQL_GetError(queryResult, error, errorLength);
		return false;
	}
	
	CloseHandle(queryResult);
	return true;
}

bool RemoveSqlBan(const char[] auth, char[] error, int maxLength)
{
	if (!IsBanned(auth, error, maxLength))
	{
		if (strlen(error) == 0)
		{
			Format(error, maxLength, "This steamID is not banned");
			return false;
		}
		
		return false;
	}
	
	char query[256];
	Format(query, sizeof(query), "DELETE FROM Banlist WHERE victimAuth='%s'", auth);
	Handle queryResult = SQL_Query(DB, query);
	if (queryResult == INVALID_HANDLE)
	{
		SQL_GetError(DB, error, maxLength);
		return false;
	}
	
	CloseHandle(queryResult);
	return true;
}

public Action CMDBan(int client, int args)
{
	if (!IsClientValid(client) || client == 0)
		return Plugin_Handled;
	
	char command[32];
	GetCmdArg(0, command, sizeof(command));
	if (args != 3)
	{
		ReplyToCommand(client, "[URNA] Usage: %s <#userid|name> <minutes|0> <reason>", command);
		return Plugin_Handled;
	}
	
	char victimStr[MAX_NAME_LENGTH];
	GetCmdArg(1, victimStr, sizeof(victimStr));
	char lengthStr[32];
	GetCmdArg(2, lengthStr, sizeof(lengthStr));
	int banLength = StringToInt(lengthStr, 10);
	char reason[MAX_REASON_LENGTH];
	GetCmdArg(3, reason, sizeof(reason));

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
	GetClientName(client, adminName, sizeof(adminName));
	GetClientName(victim, victimName, sizeof(victimName));
	
	char error[256];
	BanType type = BT_NORMAL;
	if (StrEqual(command, "sm_ctban"))
		type = BT_CT;
		
	if (!AddSqlBan(adminAuth, adminName, victimAuth, victimName, reason, banLength, type, error, sizeof(error)))
	{
		ReplyToCommand(client, error);
		return Plugin_Handled;
	}
	
	if (type == BT_NORMAL)
	{
		KickClient(victim, "You have been banned. Reason: %s", reason);
	
		ReplyToCommand(client, "[URNA] Sucessfully banned steamID %s", victimAuth);
		if (banLength > 0)
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal ban. Admin: %N. Dĺžka banu: %i minút. Dôvod: %s", victimName, victimAuth, client, banLength, reason);
		else
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal permanentný ban. Admin: %N. Dôvod: %s", victimName, victimAuth, client, reason);
	}
	else if (type == BT_CT)
	{
		if (GetClientTeam(victim) == CS_TEAM_CT)
			ChangeClientTeam(victim, CS_TEAM_T);
		
		ReplyToCommand(client, "[URNA] Sucessfully CT banned steamID %s", victimAuth);
		if (banLength > 0)
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal CT ban. Admin: %N. Dĺžka banu: %i minút. Dôvod: %s", victimName, victimAuth, client, banLength, reason);
		else
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal permanentný CT ban. Admin: %N. Dôvod: %s", victimName, victimAuth, client, reason);
	}
	
	return Plugin_Handled;
}

public Action CMDUnban(int client, int argc)
{
	if (argc != 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_unban <steamid>");
		return Plugin_Handled;
	}
	
	char auth[32];
	GetCmdArg(1, auth, sizeof(auth));
	
	char error[256];
	if (!RemoveSqlBan(auth, error, sizeof(error)))
	{
		ReplyToCommand(client, "[URNA] Error: %s", error);
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "[URNA] Unbanned successfully");
	return Plugin_Handled;
}

public Action CMDAddBan(int client, int argc)
{
	char command[32];
	GetCmdArg(0, command, sizeof(command));
	
	if (argc != 3)
	{
		ReplyToCommand(client, "[URNA] Usage: %s <steamid> <0|minutes> <reason>", command);
		return Plugin_Handled;
	}
	
	char targetAuth[32];
	GetCmdArg(1, targetAuth, sizeof(targetAuth));
	
	char lenStr[32];
	GetCmdArg(2, lenStr, sizeof(lenStr));
	int banLen = StringToInt(lenStr, 10);
	
	char reason[MAX_REASON_LENGTH];
	GetCmdArg(3, reason, sizeof(reason));
	
	char adminAuth[32];
	GetClientAuthId(client, AuthId_Steam2, adminAuth, sizeof(adminAuth));
	
	char adminName[MAX_NAME_LENGTH];
	GetClientName(client, adminName, sizeof(adminName));
	
	char error[256];
	if (IsBanned(targetAuth, error, sizeof(error)))
	{
		ReplyToCommand(client, "[URNA] This steamID is already banned");
		return Plugin_Handled;
	}
	
	BanType type = BT_NORMAL;
	if (StrEqual(command, "sm_addctban"))
		type = BT_CT;
	
	if (!AddSqlBan(adminAuth, adminName, targetAuth, "UNKNOWN", reason, banLen, type, error, sizeof(error)))
	{
		ReplyToCommand(client, "[URNA] Error: %s");
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "[URNA] Ban added successfully");
	return Plugin_Handled;
}

public Action TimerCallbackRemoveBans(Handle timer, any data)
{
	int curTime = GetTime();
	char query[256];
	Format(query, sizeof(query), "DELETE FROM Banlist WHERE rawTime+banLength*60<%i AND NOT banLength=0", curTime);
	DBResultSet queryH = SQL_Query(DB, query);
	if (queryH == INVALID_HANDLE)
	{
		char error[256];
		SQL_GetError(DB, error, sizeof(error));
		PrintToServer("Banlist database error: %s", error);
		return Plugin_Stop;
	}
	
	return Plugin_Handled;
}

// native BanType IsBanned(const char[] auth, char[] error, int maxErrorLength);
public int __IsBanned(Handle plugin, int argc)
{
	char auth[32];
	GetNativeString(1, auth, sizeof(auth));
	
	char error[256];
	int maxLength = GetNativeCell(3);
	
	char query[256];
	Format(query, sizeof(query), "SELECT victimAuth, type FROM Banlist WHERE victimAuth='%s'", auth);
	DBResultSet queryResult = SQL_Query(DB, query);
	if (queryResult == INVALID_HANDLE)
	{
		SQL_GetError(DB, error, sizeof(error));
		SetNativeString(2, error, maxLength);
		return view_as<int>(BT_NONE);
	}
	
	if (SQL_FetchRow(queryResult))
	{
		BanType type = view_as<BanType>(queryResult.FetchInt(1));
		CloseHandle(queryResult);
		return view_as<int>(type);
	}
	
	CloseHandle(queryResult);
	return view_as<int>(BT_NONE);
}