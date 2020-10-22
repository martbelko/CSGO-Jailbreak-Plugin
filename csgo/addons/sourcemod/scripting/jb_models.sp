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
	name = "Player Model Plugin",
	author = PLUGIN_AUTHOR,
	description = "Player Model plugin for jailbreak servers",
	version = PLUGIN_VERSION,
	url = ""
};

#define MAX_LINE_LEN 1024

#define PATH_MODELS_DOWNLOAD "configs/modelsdownload.ini"
#define PATH_MODELS_GROUPS "configs/modelsgroups.ini"

enum ModelVipMode
{
	MVM_ALL = 0,
	MVM_VIP,
	MVM_EVIP,
	MVM_ADMIN,
	MVM_CUSTOM
}

enum struct Model
{
	char displayName[64];
	char path[256];
	char arms[256];
	int team;
	ModelVipMode vipMode;
	char auth[32];
}

static char anarchistModelsT[][] = 
{
	"models/player/custom_player/legacy/tm_anarchist.mdl",
	"models/player/custom_player/legacy/tm_anarchist_variantA.mdl",
	"models/player/custom_player/legacy/tm_anarchist_variantB.mdl",
	"models/player/custom_player/legacy/tm_anarchist_variantC.mdl",
	"models/player/custom_player/legacy/tm_anarchist_variantD.mdl"
};

static char phoenixModelsT[][] = 
{
	"models/player/custom_player/legacy/tm_phoenix.mdl",
	"models/player/custom_player/legacy/tm_phoenix_heavy.mdl",
	"models/player/custom_player/legacy/tm_phoenix_variantA.mdl",
	"models/player/custom_player/legacy/tm_phoenix_variantB.mdl",
	"models/player/custom_player/legacy/tm_phoenix_variantC.mdl",
	"models/player/custom_player/legacy/tm_phoenix_variantD.mdl"
};

static char pirateModelsT[][] = 
{
	"models/player/custom_player/legacy/tm_pirate.mdl",
	"models/player/custom_player/legacy/tm_pirate_variantA.mdl",
	"models/player/custom_player/legacy/tm_pirate_variantB.mdl",
	"models/player/custom_player/legacy/tm_pirate_variantC.mdl",
	"models/player/custom_player/legacy/tm_pirate_variantD.mdl"
};

static char fbiModelsCT[][] = 
{
	"models/player/custom_player/legacy/ctm_fbi.mdl",
	"models/player/custom_player/legacy/ctm_fbi_variantA.mdl",
	"models/player/custom_player/legacy/ctm_fbi_variantB.mdl",
	"models/player/custom_player/legacy/ctm_fbi_variantC.mdl",
	"models/player/custom_player/legacy/ctm_fbi_variantD.mdl"
};

static char gignModelsCT[][] = 
{
	"models/player/custom_player/legacy/ctm_gign.mdl",
	"models/player/custom_player/legacy/ctm_gign_variantA.mdl",
	"models/player/custom_player/legacy/ctm_gign_variantB.mdl",
	"models/player/custom_player/legacy/ctm_gign_variantC.mdl",
	"models/player/custom_player/legacy/ctm_gign_variantD.mdl"
};

static char sasModelsCT[][] = 
{
	"models/player/custom_player/legacy/ctm_sas.mdl",
	"models/player/custom_player/legacy/ctm_sas_variantA.mdl",
	"models/player/custom_player/legacy/ctm_sas_variantB.mdl",
	"models/player/custom_player/legacy/ctm_sas_variantC.mdl",
	"models/player/custom_player/legacy/ctm_sas_variantD.mdl",
	"models/player/custom_player/legacy/ctm_sas_variantE.mdl"
};

static ArrayList s_ModelArrayList;

static int s_PlayerTModelIndex[MAXPLAYERS + 1];
static int s_PlayerCtModelIndex[MAXPLAYERS + 1];

/*
bool CanUseModel(int client, int modelIndex)
{
	Model mdl;
	s_ModelArrayList.GetArray(modelIndex, mdl, sizeof(mdl));
	if (mdl.team != GetClientTeam(client))
		return false;
	
	if (mdl.authType == AT_FLAG)
	{
		if (GetClientVipMode(client) >= mdl.vipMode && mdl.vipMode != VM_CUSTOM)
			return true;
		if (mdl.vipMode == VM_CUSTOM)
		{
			char steamid[32];
			GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
			if (StrEqual(steamid, mdl.auth))
				return true;
		}
		
		return false;
	}
}
*/

static char s_ModelDownloadPath[256];
static char s_ModelGroupsPath[256];

static int s_DefaultTModelIndex = -1;
static int s_DefaultCtModelIndex = -1;

static bool s_HasCustomTModel[MAXPLAYERS + 1];
static bool s_HasCustomCtModel[MAXPLAYERS + 1];

void CheckCustomModels(int client)
{
	s_HasCustomTModel[client] = false;
	s_HasCustomCtModel[client] = false;
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	for (int i = 0; i < s_ModelArrayList.Length; ++i)
	{
		Model mdl;
		s_ModelArrayList.GetArray(i, mdl, sizeof(mdl));
		if (StrEqual(mdl.auth, steamid))
		{
			if (mdl.team == CS_TEAM_T)
				s_HasCustomTModel[client] = true;
			else if (mdl.team == CS_TEAM_CT)
				s_HasCustomCtModel[client] = true;
		}
	}
}

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("DisplayModelsMenu", __DisplayModelsMenu);
	CreateNative("SetPlayerModel", __SetPlayerModel);

	RegPluginLibrary("jb_models.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_models", CMDModels);
	HookEvent("player_spawn", OnPlayerSpawn);
	
	s_ModelArrayList = new ArrayList(sizeof(Model));
	
	BuildPath(Path_SM, s_ModelDownloadPath, sizeof(s_ModelDownloadPath), PATH_MODELS_DOWNLOAD);
	BuildPath(Path_SM, s_ModelGroupsPath, sizeof(s_ModelGroupsPath), PATH_MODELS_GROUPS);
	
	OnMapStart();
	
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
	s_PlayerTModelIndex[client] = s_DefaultTModelIndex;
	s_PlayerCtModelIndex[client] = s_DefaultCtModelIndex;
	CheckCustomModels(client);
}

void LoadModelsDownload(const char[] path)
{
	// TODO: Add check if file exists, if not set fail state
	Handle file = OpenFile(path, "r");
	char line[MAX_LINE_LEN];
	while (ReadFileLine(file, line, sizeof(line)))
	{
		String_Trim(line, line, sizeof(line));
		if (strlen(line) == 0)
			continue;
		if (String_StartsWith(line, "//"))
			continue;
		
		AddFileToDownloadsTable(line);
		if (String_EndsWith(line, ".mdl"))
			PrecacheModel(line);
	}

	CloseHandle(file);
}

void LoadModelsGroups(const char[] path, ArrayList& modelArrayList)
{
	Handle kv = CreateKeyValues("Models");
	FileToKeyValues(kv, path);
	int index = 0;
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			char teamStr[3];
			KvGetSectionName(kv, teamStr, sizeof(teamStr));
			int team;
			if (StrEqual(teamStr, "T", false))
				team = CS_TEAM_T;
			else
				team = CS_TEAM_CT;

			if (KvGotoFirstSubKey(kv))
			{
				do
				{
					// TODO: Add error checking
					Model temp;
					KvGetSectionName(kv, temp.displayName, sizeof(temp.displayName));
					KvGetString(kv, "path", temp.path, sizeof(temp.path));
					KvGetString(kv, "arms", temp.arms, sizeof(temp.arms));
					temp.team = team;
					char tempStr[32];
					KvGetString(kv, "auth", tempStr, sizeof(tempStr));
					if (StrEqual(tempStr, "all"))
						temp.vipMode = MVM_ALL;
					else if (StrEqual(tempStr, "vip"))
						temp.vipMode = MVM_VIP;
					else if (StrEqual(tempStr, "evip"))
						temp.vipMode = MVM_EVIP;
					else if (StrEqual(tempStr, "admin"))
						temp.vipMode = MVM_ADMIN;
					else if (String_StartsWith(tempStr, "STEAM_"))
					{
						strcopy(temp.auth, sizeof(temp.auth), tempStr);
						temp.vipMode = MVM_CUSTOM;
					}
					else
					{
						SetFailState("Model loading failed. Model name: %s", temp.displayName);
						return;
					}
					
					s_ModelArrayList.PushArray(temp, sizeof(temp));
					if (team == CS_TEAM_T && s_DefaultTModelIndex == -1)
						s_DefaultTModelIndex = index;
					else if (team == CS_TEAM_CT && s_DefaultCtModelIndex == -1)
						s_DefaultCtModelIndex = index;
					++index;
				}
				while (KvGotoNextKey(kv));
			}
							
			KvGoBack(kv);
		}
		while (KvGotoNextKey(kv));
	}
}

public void OnMapStart()
{
	PrecacheModel("models/weapons/t_arms_phoenix.mdl");
	PrecacheModel("models/weapons/t_arms_leet.mdl");
	PrecacheModel("models/weapons/ct_arms_sas.mdl");

	for (int i = 0; i < sizeof(fbiModelsCT); i++)
	{
		if(fbiModelsCT[i][0] && !IsModelPrecached(fbiModelsCT[i]))
			PrecacheModel(fbiModelsCT[i]);
	}

	for (int i = 0; i < sizeof(gignModelsCT); i++)
	{
		if(gignModelsCT[i][0] && !IsModelPrecached(gignModelsCT[i]))
			PrecacheModel(gignModelsCT[i]);
	}

	for (int i = 0; i < sizeof(sasModelsCT); i++)
	{
		if(sasModelsCT[i][0] && !IsModelPrecached(sasModelsCT[i]))
			PrecacheModel(sasModelsCT[i]);
	}

	for (int i = 0; i < sizeof(anarchistModelsT); i++)
	{
		if(anarchistModelsT[i][0] && !IsModelPrecached(anarchistModelsT[i]))
			PrecacheModel(anarchistModelsT[i]);
	}

	for (int i = 0; i < sizeof(phoenixModelsT); i++)
	{
		if(phoenixModelsT[i][0] && !IsModelPrecached(phoenixModelsT[i]))
			PrecacheModel(phoenixModelsT[i]);
	}

	for (int i = 0; i < sizeof(pirateModelsT); i++)
	{
		if(pirateModelsT[i][0] && !IsModelPrecached(pirateModelsT[i]))
			PrecacheModel(pirateModelsT[i]);
	}
	
	s_ModelArrayList.Clear();

	LoadModelsDownload(s_ModelDownloadPath);
	LoadModelsGroups(s_ModelGroupsPath, s_ModelArrayList);
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientValid(i))
			CheckCustomModels(i);
}

public void OnMapEnd()
{
	s_ModelArrayList.Clear();
}

public Action OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetClientTeam(client);
	if (team == CS_TEAM_T)
	{
		Handle kv = CreateKeyValues("root");
		KvSetNum(kv, "client", client);
		KvSetNum(kv, "index", s_PlayerTModelIndex[client]);
		CreateTimer(0.1, TimerCallbackOnSpawn, kv);
	}
	else if (team == CS_TEAM_CT)
	{
		Handle kv = CreateKeyValues("root");
		KvSetNum(kv, "client", client);
		KvSetNum(kv, "index", s_PlayerCtModelIndex[client]);
		CreateTimer(0.1, TimerCallbackOnSpawn, kv);
	}
}

public Action TimerCallbackOnSpawn(Handle timer, Handle kv)
{
	int client = KvGetNum(kv, "client");
	int index = KvGetNum(kv, "index");
	UseModel(client, index);
	CloseHandle(kv);
}

public Action CMDModels(int client, int args)
{
	DisplayModelsMenu(client);
	return Plugin_Handled;
}

Menu CreateModelsMenu(int client)
{
	Menu menu = new Menu(MenuCallbackModelsMenu);
	menu.AddItem("free", "Free");
	if (IsClientVip(client))
		menu.AddItem("vip", "VIP");
	if (IsClientExtraVip(client))
		menu.AddItem("evip", "ExtraVIP");
	if (IsAdmin(client))
		menu.AddItem("admin", "Admin");
	int team = GetClientTeam(client);
	if (team == CS_TEAM_T && s_HasCustomTModel[client] || team == CS_TEAM_CT && s_HasCustomCtModel[client])
		menu.AddItem("custom", "Custom");
	
	return menu;
}

public int MenuCallbackModelsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(param2, item, sizeof(item));
			if (StrEqual(item, "free"))
			{
				DisplayMenuModelDetailed(param1, MVM_ALL);
			}
			else if (StrEqual(item, "vip"))
			{
				DisplayMenuModelDetailed(param1, MVM_VIP);
			}
			else if (StrEqual(item, "evip"))
			{
				DisplayMenuModelDetailed(param1, MVM_EVIP);
			}
			else if (StrEqual(item, "admin"))
			{
				DisplayMenuModelDetailed(param1, MVM_ADMIN);
			}
			else if (StrEqual(item, "custom"))
			{
				DisplayMenuModelDetailed(param1, MVM_CUSTOM);
			}
		}
		case MenuAction_End:
			delete menu;
	}
	
	return 0;
}

void UseModel(int client, int index)
{
	Model mdl;
	s_ModelArrayList.GetArray(index, mdl);
	SetEntityModel(client, mdl.path);
	SetEntPropString(client, Prop_Send, "m_szArmsModel", mdl.arms);
	RequestFrame(RemoveItem, EntIndexToEntRef(client));
}

void SetPlayerModelIndex(int client, int index, bool instant = false)
{
	int team = GetClientTeam(client);
	if (team == CS_TEAM_T)
		s_PlayerTModelIndex[client] = index;
	else if (team == CS_TEAM_CT)
		s_PlayerCtModelIndex[client] = index;
	
	if (instant)
		UseModel(client, index);
}

public int MenuCallbackModelDetailed(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char indexStr[4];
			menu.GetItem(param2, indexStr, sizeof(indexStr));
			int index = StringToInt(indexStr, 10);
			if (index == -1)
				PrintToChat(param1, "No model found");
			else
				SetPlayerModelIndex(param1, index, false);
		}
		case MenuAction_End:
			delete menu;
	}
}

Menu CreateMenuModelDetailed(int client, ModelVipMode vipMode)
{
	Menu menu = new Menu(MenuCallbackModelDetailed);
	int team = GetClientTeam(client);
	if (vipMode == MVM_CUSTOM)
	{
		char steamid[32];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		for (int i = 0; i < s_ModelArrayList.Length; ++i)
		{
			Model mdl;
			s_ModelArrayList.GetArray(i, mdl, sizeof(mdl));
			if (mdl.team == team && StrEqual(mdl.auth, steamid))
			{
				char indexStr[4];
				IntToString(i, indexStr, sizeof(indexStr));
				menu.AddItem(indexStr, mdl.displayName);
			}
		}
	}
	else
	{
		for (int i = 0; i < s_ModelArrayList.Length; ++i)
		{
			Model mdl;
			s_ModelArrayList.GetArray(i, mdl, sizeof(mdl));
			if (mdl.team == team && mdl.vipMode == vipMode)
			{
				char indexStr[4];
				IntToString(i, indexStr, sizeof(indexStr));
				menu.AddItem(indexStr, mdl.displayName);
			}
		}
	}
	
	return menu;
}

void DisplayMenuModelDetailed(int client, ModelVipMode vipMode)
{
	Menu menu = CreateMenuModelDetailed(client, vipMode);
	menu.Display(client, MENU_TIME_FOREVER);
}

public void RemoveItem(int ref)
{
	int client = EntRefToEntIndex(ref);
	if (client != INVALID_ENT_REFERENCE)
	{
		int item = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (item > 0)
		{
			RemovePlayerItem(client, item);
			
			Handle ph = CreateDataPack();
			WritePackCell(ph, EntIndexToEntRef(client));
			WritePackCell(ph, EntIndexToEntRef(item));
			CreateTimer(0.15, AddItemTimer, ph, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action AddItemTimer(Handle timer ,any ph)
{  
	int client, item;
	
	ResetPack(ph);
	
	client = EntRefToEntIndex(ReadPackCell(ph));
	item = EntRefToEntIndex(ReadPackCell(ph));
	
	if (client != INVALID_ENT_REFERENCE && item != INVALID_ENT_REFERENCE)
	{
		EquipPlayerWeapon(client, item);
	}
}

// native void DisplayModelsMenu(int client);
public int __DisplayModelsMenu(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	if (IsClientValid(client))
	{
		Menu menu = CreateModelsMenu(client);
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

// native void SetPlayerModel(int client, int modelIndex);
public int __SetPlayerModel(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	int index = GetNativeCell(2);
	if (IsClientValid(client))
	{
		Model mdl;
		s_ModelArrayList.GetArray(index, mdl, sizeof(mdl));
		SetEntityModel(client, mdl.path);
		SetEntPropString(client, Prop_Send, "m_szArmsModel", mdl.arms);
		RequestFrame(RemoveItem, EntIndexToEntRef(client));
	}
}
