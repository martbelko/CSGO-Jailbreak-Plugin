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
	name = "HUD Plugin",
	author = PLUGIN_AUTHOR,
	description = "HUD plugin that displays available points for shop, current skin, current warden etc",
	version = PLUGIN_VERSION,
	url = ""
};

static int s_Points[MAXPLAYERS + 1] = {0, ...};
static char s_Skins[MAXPLAYERS + 1][64];
static int s_Warden = -1;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("OnPointsChanged", __OnPointsChanged);
	CreateNative("OnSkinChanged", __OnSkinChanged);
	CreateNative("OnWardenChanged", __OnWardenChanged);
	CreateNative("OnPlayerGetItem", __OnPlayerGetItem);
	
	RegPluginLibrary("HUD.inc");
	return APLRes_Success;
}

void RedrawBottomHUD(int client, const char[] format, any ...)
{
	char text[256];
	VFormat(text, sizeof(text), format, 3);
	SetHudTextParams(-1.0, 0.92, 9999.0, 255, 255, 255, 255, 0);
	ShowHudText(client, 1, text);
}

void RedrawCenterHUD(int client, const char[] format, any ...)
{
	char text[256];
	VFormat(text, sizeof(text), format, 3);
	SetHudTextParams(-1.0, -1.0, 9999.0, 255, 255, 255, 255, 0);
	ShowHudText(client, 2, text);
}

void RedrawTopHUD(int client, const char[] format, any ...)
{
	char text[256];
	VFormat(text, sizeof(text), format, 3);
	SetHudTextParams(-1.0, 0.05, 9999.0, 255, 255, 0, 255, 0);
	ShowHudText(client, 3, text);
}

// native void OnPointsChanged(int client, int numPoints);
public int __OnPointsChanged(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	s_Points[client] = GetNativeCell(2);
	
	RedrawBottomHUD(client, "Points: %d | Skin: %s", s_Points[client], s_Skins[client]);
}

// native void OnSkinChanged(int client, const char[] skinName);
public int __OnSkinChanged(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	GetNativeString(2, s_Skins[client], 64);
	
	RedrawBottomHUD(client, "Points: %d | Skin: %s", s_Points[client], s_Skins[client]);
}

// native void OnWardenChanged(int warden);
public int __OnWardenChanged(Handle plugin, int argc)
{
	s_Warden = GetNativeCell(1);
	if (IsClientValid(s_Warden))
	{
		char text[256];
		char name[MAX_NAME_LENGTH];
		GetClientName(s_Warden, name, sizeof(name));
		if (String_StartsWith(name, "WARDEN") || String_StartsWith(name, "Warden"))
		{
			strcopy(name, sizeof(name), name[6]);
		}
		
		Format(text, sizeof(text), "%s je WARDEN a všetci ho musia poslúchať", name);
		for (int i = 1; i <= MaxClients; ++i)
			if (IsClientInGame(i))
				RedrawTopHUD(i, text);
	}
	else
	{
		for (int i = 1; i <= MaxClients; ++i)
			if (IsClientInGame(i))
				RedrawTopHUD(i, "");
	}
}

// native void native void OnPlayerGetItem(int client, const char[] text);
public int __OnPlayerGetItem(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	char text[64];
	GetNativeString(2, text, sizeof(text));
	
	RedrawCenterHUD(client, text);
}