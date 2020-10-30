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

#define MAX_REASON_LENGTH 64
#define MAX_ERROR_LENGTH  64

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
	// RegAdminCmd("sm_addban", CMDAddBan, ADMFLAG_BAN, "Add ban by steamID");
	
	RegAdminCmd("sm_ctban", CMDBan, ADMFLAG_BAN, "CT Ban");
	// RegAdminCmd("sm_addctban", CMDAddBan, ADMFLAG_BAN, "Add CT Ban");
	
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
	char steam2[32], steam3[32], steam64[32], ip[32];
	GetClientAuthId(client, AuthId_Steam2, steam2, sizeof(steam2));
	GetClientAuthId(client, AuthId_Steam3, steam3, sizeof(steam3));
	GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
	GetClientIP(client, ip, sizeof(ip), true);
	
	char query[512];
	Format(query, sizeof(query), "SELECT targetSteam2, targetSteam3, targetSteam64, targetIP, reason, banType FROM Banlist WHERE targetSteam2='%s' || targetSteam3='%s' || targetSteam64='%s' || targetIP='%s' and banType=%i",
	       steam2, steam3, steam64, ip, BT_NORMAL);
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
		BanType type = view_as<BanType>(queryResult.FetchInt(5));
		if (type == BT_NORMAL)
		{
			char reason[MAX_REASON_LENGTH];
			queryResult.FetchString(4, reason, sizeof(reason));
			KickClient(client, "You are banned. Reason: %s", reason);
			
			PrintToChatAll(" \x07 [URNA] Hráč %N\x07(%s) sa nemôže pripojiť, pretože je zabanovaný. Dôvod: %s", client, steam2, reason);
		}
	}
	
	CloseHandle(queryResult);
}

enum struct BanItem
{
	char adminName[MAX_NAME_LENGTH];
	char adminSteam2[32];
	
	char targetName[MAX_NAME_LENGTH];
	char targetSteam2[32];
	char targetSteam3[32];
	char targetSteam64[32];
	char targetIP[32]; // 192.168.100.100
	
	char reason[MAX_REASON_LENGTH];
	int banLength;
	BanType type;
	char error[MAX_ERROR_LENGTH];
}

bool AddSqlBan(BanItem item)
{
	int curTime = GetTime();
	char timeFormat[32];
	FormatTime(timeFormat, sizeof(timeFormat), "%d/%m/%Y, %H:%M:%S", curTime);
	
	char query[512];
	Format(query, sizeof(query),
	"INSERT INTO Banlist (adminName, adminSteam2, targetName, targetSteam2, targetSteam3, targetSteam64, targetIP, reason, banLength, banType, rawTime) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%i', '%i', '%i')",
	item.adminName, item.adminSteam2, item.targetName, item.targetSteam2, item.targetSteam3, item.targetSteam64, item.targetIP, item.reason, item.banLength, view_as<int>(item.type), curTime);
	DBResultSet queryResult = SQL_Query(DB, query);
	if (queryResult == INVALID_HANDLE)
	{
		SQL_GetError(queryResult, item.error, MAX_ERROR_LENGTH);
		return false;
	}
	
	CloseHandle(queryResult);
	return true;
}

BanType GetBanType(int id, char[] error, int maxErrorLength)
{
	char query[256];
	Format(query, sizeof(query), "SELECT id, banType FROM Banlist WHERE id=%i", id);
	DBResultSet queryResult = SQL_Query(DB, query);
	if (queryResult == INVALID_HANDLE)
	{
		SQL_GetError(DB, error, maxErrorLength);
		return BT_NONE;
	}
	
	if (SQL_FetchRow(queryResult))
	{
		BanType type = view_as<BanType>(queryResult.FetchInt(1));
		CloseHandle(queryResult);
		return type;
	}
	
	CloseHandle(queryResult);
	return BT_NONE;
}

bool RemoveSqlBan(int id, char[] error, int maxLength)
{
	if (GetBanType(id, error, maxLength) == BT_NONE)
	{
		if (strlen(error) == 0)
		{
			Format(error, maxLength, "This steamID is not banned");
			return false;
		}
		
		return false;
	}
	
	char query[256];
	Format(query, sizeof(query), "DELETE FROM Banlist WHERE id=%i", id);
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
	
	BanItem item;
	
	char victimStr[MAX_NAME_LENGTH];
	GetCmdArg(1, victimStr, sizeof(victimStr));
	char lengthStr[32];
	GetCmdArg(2, lengthStr, sizeof(lengthStr));
	item.banLength = StringToInt(lengthStr, 10);
	GetCmdArg(3, item.reason, sizeof(item.reason));

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
	
	GetClientAuthId(client, AuthId_Steam2, item.adminSteam2, sizeof(item.adminSteam2));
	GetClientAuthId(victim, AuthId_Steam2, item.targetSteam2, sizeof(item.targetSteam2));
	GetClientAuthId(victim, AuthId_Steam3, item.targetSteam3, sizeof(item.targetSteam3));
	GetClientAuthId(victim, AuthId_SteamID64, item.targetSteam64, sizeof(item.targetSteam64));
	GetClientIP(victim, item.targetIP, sizeof(item.targetIP), true);
	
	GetClientName(client, item.adminName, sizeof(item.adminName));
	GetClientName(victim, item.targetName, sizeof(item.targetName));
	
	item.type = BT_NORMAL;
	if (StrEqual(command, "sm_ctban"))
		item.type = BT_CT;
	
	if (!AddSqlBan(item))
	{
		ReplyToCommand(client, item.error);
		return Plugin_Handled;
	}
	
	if (item.type == BT_NORMAL)
	{
		KickClient(victim, "You have been banned. Reason: %s", item.reason);
	
		ReplyToCommand(client, "[URNA] Sucessfully banned steamID %s", item.targetSteam2);
		if (item.banLength > 0)
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal ban. Admin: %N. Dĺžka banu: %i minút. Dôvod: %s",
			               item.targetName, item.targetSteam2, client, item.banLength, item.reason);
		else
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal permanentný ban. Admin: %N. Dôvod: %s",
			               item.targetName, item.targetSteam2, client, item.reason);
	}
	else if (item.type == BT_CT)
	{
		if (GetClientTeam(victim) == CS_TEAM_CT)
			ChangeClientTeam(victim, CS_TEAM_T);
		
		ReplyToCommand(client, "[URNA] Sucessfully CT banned steamID %s", item.targetSteam2);
		if (item.banLength > 0)
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal CT ban. Admin: %N. Dĺžka banu: %i minút. Dôvod: %s",
			               item.targetName, item.targetSteam2, client, item.banLength, item.reason);
		else
			PrintToChatAll(" \x07 [URNA] Hráč %s (%s) dostal permanentný CT ban. Admin: %N. Dôvod: %s",
			               item.targetName, item.targetSteam2, client, item.reason);
	}
	
	return Plugin_Handled;
}

public Action CMDUnban(int client, int argc)
{
	if (argc != 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_unban <banid>");
		return Plugin_Handled;
	}
	
	char idStr[32];
	GetCmdArg(1, idStr, sizeof(idStr));
	char error[256];
	int id = StringToInt(idStr, 10);
	if (!RemoveSqlBan(id, error, sizeof(error)))
	{
		ReplyToCommand(client, "[URNA] Error: %s", error);
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "[URNA] Unbanned successfully");
	return Plugin_Handled;
}

/*public Action CMDAddBan(int client, int argc)
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
}*/

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

// native BanType IsBanned(int client, char[] error, int maxErrorLength);
public int __IsBanned(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int maxLength = GetNativeCell(3);
	char steam2[32], steam3[32], steam64[32], ip[32];
	GetClientAuthId(client, AuthId_Steam2, steam2, sizeof(steam2));
	GetClientAuthId(client, AuthId_Steam3, steam3, sizeof(steam3));
	GetClientAuthId(client, AuthId_SteamID64, steam64, sizeof(steam64));
	GetClientIP(client, ip, sizeof(ip), true);
	
	char error[256], query[512];
	Format(query, sizeof(query), "SELECT targetSteam2, targetSteam3, targetSteam64, targetIP, reason, banType FROM Banlist WHERE targetSteam2='%s' || targetSteam3='%s' || targetSteam64='%s' || targetIP='%s' and banType=%i",
	       steam2, steam3, steam64, ip, BT_CT);
	DBResultSet queryResult = SQL_Query(DB, query);
	if (queryResult == INVALID_HANDLE)
	{
		SQL_GetError(DB, error, sizeof(error));
		SetNativeString(2, error, maxLength);
		return view_as<int>(BT_NONE);
	}
	
	if (SQL_FetchRow(queryResult))
	{
		BanType type = view_as<BanType>(queryResult.FetchInt(5));
		CloseHandle(queryResult);
		return view_as<int>(type);
	}
	
	CloseHandle(queryResult);
	return view_as<int>(BT_NONE);
}