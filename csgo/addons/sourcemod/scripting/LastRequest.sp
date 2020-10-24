#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <smlib/strings>

#include <jb_models>
#include <jb_core>
#include <jb_jailbreak>
#include <jb_vip>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Last Request Plugin",
	author = PLUGIN_AUTHOR,
	description = "Last Request Plugin",
	version = PLUGIN_VERSION,
	url = ""
};

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("IsPlayerInLr", __IsPlayerInLr);
	CreateNative("GetPlayersInLr", __GetPlayersInLr);
	CreateNative("GetPlayerInLrFromTeam", __GetPlayerInLrFromTeam);
	CreateNative("GetActiveLr", __GetActiveLr);
	CreateNative("IsLrInProgress", __IsLrInProgress);

	RegPluginLibrary("LastRequest.inc");
	return APLRes_Success;
}