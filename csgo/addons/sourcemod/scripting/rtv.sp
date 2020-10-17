#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sdktools>
#include <sourcemod>
#include <clientprefs>

#include <jb_core>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Jailbreak VIP Plugin",
	author = PLUGIN_AUTHOR,
	description = "Jailbreak VIP Plugin",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_testrtv", CMDRtv, "Rock The Vote");
	RegConsoleCmd("sm_testrockthevote", CMDRtv, "Rock The Vote");
}

public Action CMDRtv(int client, int argc)
{
	ReplyToCommand(client, "Testing rtv");
	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!IsClientValid(client) || IsChatTrigger())
		return;
	
	if (strcmp(sArgs, "testrtv", false) == 0 || strcmp(sArgs, "testrockthevote", false) == 0)
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
		ReplyToCommand(client, "Testing rtv");
		SetCmdReplySource(old);
	}
}
