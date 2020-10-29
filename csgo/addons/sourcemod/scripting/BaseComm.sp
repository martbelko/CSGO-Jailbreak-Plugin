#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#pragma newdecls required

#include <BaseComm>
#include <jb_core>

public Plugin myinfo = 
{
	name = "URNA BaseComm",
	author = PLUGIN_AUTHOR,
	description = "Provides methods of controlling communication.",
	version = PLUGIN_VERSION,
	url = ""
};

enum struct PlayerState
{
	bool isMuted;
	bool isGagged;
}

static PlayerState s_PlayerState[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("IsGagged", __IsClientGagged);
	CreateNative("IsMuted", __IsClientMuted);

	RegPluginLibrary("jb_models.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basecomm.phrases");
	
	RegAdminCmd("sm_mute", CMDMute, ADMFLAG_CHAT, "sm_mute <player> - Removes a player's ability to use voice.");
	RegAdminCmd("sm_gag", CMDGag, ADMFLAG_CHAT, "sm_gag <player> - Removes a player's ability to use chat.");
	RegAdminCmd("sm_silence", CMDSilence, ADMFLAG_CHAT, "sm_silence <player> - Removes a player's ability to use voice or chat.");
	
	RegAdminCmd("sm_unmute", CMDUnmute, ADMFLAG_CHAT, "sm_unmute <player> - Restores a player's ability to use voice.");
	RegAdminCmd("sm_ungag", CMDUngag, ADMFLAG_CHAT, "sm_ungag <player> - Restores a player's ability to use chat.");
	RegAdminCmd("sm_unsilence", CMDUnsilence, ADMFLAG_CHAT, "sm_unsilence <player> - Restores a player's ability to use voice and chat.");
}

public void OnClientPutInServer(int client)
{
	s_PlayerState[client].isGagged = false;
	s_PlayerState[client].isMuted = false;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (IsClientValid(client) && s_PlayerState[client].isGagged)
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action CMDMute(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_mute <player>");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; ++i)
	{
		int target = target_list[i];
		PerformMute(client, target);
	}

	if (tn_is_ml)
		ShowActivity2(client, "[URNA] ", "%t", "Muted target", target_name);
	else
		ShowActivity2(client, "[URNA] ", "%t", "Muted target", "_s", target_name);
	
	return Plugin_Handled;
}

public Action CMDGag(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_gag <player>");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; ++i)
	{
		int target = target_list[i];
		PerformGag(client, target);
	}

	if (tn_is_ml)
		ShowActivity2(client, "[URNA] ", "%t", "Gagged target", target_name);
	else
		ShowActivity2(client, "[URNA] ", "%t", "Gagged target", "_s", target_name);
	
	return Plugin_Handled;
}

public Action CMDSilence(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_silence <player>");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; ++i)
	{
		int target = target_list[i];
		PerformSilence(client, target);
	}

	if (tn_is_ml)
		ShowActivity2(client, "[URNA] ", "%t", "Silenced target", target_name);
	else
		ShowActivity2(client, "[URNA] ", "%t", "Silenced target", "_s", target_name);
	
	return Plugin_Handled;
}

public Action CMDUnmute(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_unmute <player>");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; ++i)
	{
		int target = target_list[i];
		PerformUnmute(client, target);
	}

	if (tn_is_ml)
		ShowActivity2(client, "[URNA] ", "%t", "Unmuted target", target_name);
	else
		ShowActivity2(client, "[URNA] ", "%t", "Unmuted target", "_s", target_name);
	
	return Plugin_Handled;
}

public Action CMDUngag(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_ungag <player>");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; ++i)
	{
		int target = target_list[i];
		PerformUngag(client, target);
	}
	
	if (tn_is_ml)
		ShowActivity2(client, "[URNA] ", "%t", "Ungagged target", target_name);
	else
		ShowActivity2(client, "[URNA] ", "%t", "Ungagged target", "_s", target_name);
	
	return Plugin_Handled;
}

public Action CMDUnsilence(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[URNA] Usage: sm_unsilence <player>");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (int i = 0; i < target_count; ++i)
	{
		int target = target_list[i];
		PerformUnsilence(client, target);
	}
	
	if (tn_is_ml)
		ShowActivity2(client, "[URNA] ", "%t", "Unsilenced target", target_name);
	else
		ShowActivity2(client, "[URNA] ", "%t", "Unsilenced target", "_s", target_name);
	
	return Plugin_Handled;
}

void PerformMute(int client, int target, bool silent = false)
{
	s_PlayerState[target].isMuted = true;
	SetClientListeningFlags(target, VOICE_MUTED);
	PrintToChatAll(" \x07 [URNA] %N dostal mute. Admin: %N", target, client);
	if (!silent)
		LogAction(client, target, "\"%L\" muted \"%L\"", client, target);
}

void PerformGag(int client, int target, bool silent = false)
{
	s_PlayerState[target].isGagged = true;
	PrintToChatAll(" \x07 [URNA] %N dostal gag. Admin: %N", target, client);
	if (!silent)
		LogAction(client, target, "\"%L\" gagged \"%L\"", client, target);
}

void PerformSilence(int client, int target, bool silent = false)
{
	s_PlayerState[target].isGagged = true;
	s_PlayerState[target].isMuted = true;
	SetClientListeningFlags(target, VOICE_MUTED);
	PrintToChatAll(" \x07 [URNA] %N dostal mute a gag. Admin: %N", target, client);
	if (!silent)
		LogAction(client, target, "\"%L\" silenced \"%L\"", client, target);
}

void PerformUnmute(int client, int target, bool silent = false)
{
	s_PlayerState[target].isMuted = false;
	SetClientListeningFlags(target, VOICE_NORMAL);
	PrintToChatAll(" \x04 [URNA] %N už nemá mute. Admin: %N", target, client);
	if (!silent)
		LogAction(client, target, "\"%L\" unmuted \"%L\"", client, target);
}

void PerformUngag(int client, int target, bool silent = false)
{
	s_PlayerState[target].isGagged = false;
	PrintToChatAll(" \x04 [URNA] %N už nemá gag. Admin: %N", target, client);
	if (!silent)
		LogAction(client, target, "\"%L\" ungagged \"%L\"", client, target);
}

void PerformUnsilence(int client, int target, bool silent = false)
{
	s_PlayerState[target].isGagged = false;
	s_PlayerState[target].isMuted = false;
	SetClientListeningFlags(target, VOICE_NORMAL);
	PrintToChatAll(" \x04 [URNA] %N už nemá mute ani gag. Admin: %N", target, client);
	if (!silent)
		LogAction(client, target, "\"%L\" unsilenced \"%L\"", client, target);
}

// native bool IsClientGagged(int client);
public int __IsClientGagged(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	if (IsClientValid(client))
		return s_PlayerState[client].isGagged;
	return false;
}

// native bool IsClientMuted(int client);
public int __IsClientMuted(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	if (IsClientValid(client))
		return s_PlayerState[client].isMuted;
	return false;
}
