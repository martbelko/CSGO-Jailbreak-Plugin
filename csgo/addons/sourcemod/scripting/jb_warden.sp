#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <clientprefs>
#include <smlib/strings>

#include <jb_core>
#include <jb_jailbreak>
#include <jb_menu>
#include <HUD>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Warden Plugin",
	author = PLUGIN_AUTHOR,
	description = "Warden plugin for jailbreak servers",
	version = PLUGIN_VERSION,
	url = ""
};

enum WardenGame
{
	WG_NONE = 0,
	WG_HNS,
	WG_SPARTA,
}

enum BoxMode
{
	BM_NONE = 0,
	BM_RESTRICT,
	BM_CLASSIC
}

#define MODEL_BALL "models/props/de_dust/hr_dust/dust_soccerball/dust_soccer_ball001.mdl"

static int s_Warden = -1; // Active Warden client index
static WardenGame s_Wg = WG_NONE;
static ArrayList s_Menus; // Vector to hold menus, when we want to roll back
static ArrayList s_TeamA; // Vector to hold client indices of team A
static ArrayList s_TeamB; // Vector to hold client indices of team B
static BoxMode s_BoxMode = BM_NONE; // Box mode on/off
static int s_Ball = -1; // Warden's spawned ball entity index

static Handle s_WardenTimer = INVALID_HANDLE;

void ResetWardenTimer()
{
	if (s_WardenTimer != INVALID_HANDLE)
	{
		KillTimer(s_WardenTimer);
		s_WardenTimer = INVALID_HANDLE;
	}
}

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("GetWarden", __GetWarden);
	
	RegPluginLibrary("jb_lastrequest.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_warden", CMDWarden, "");
	RegConsoleCmd("sm_w", CMDWarden, "");
	RegConsoleCmd("sm_W", CMDWarden, "");
	RegConsoleCmd("sm_unwarden", CMDUnwarden, "");
	RegConsoleCmd("sm_uw", CMDUnwarden, "");
	RegConsoleCmd("sm_wardenmenu", CMDWardenMenu, "");
	RegConsoleCmd("sm_wmenu", CMDWardenMenu, "");
	RegConsoleCmd("sm_open", CMDOpen, "");
	RegConsoleCmd("sm_o", CMDOpen, "");
	
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("player_team", OnPlayerChangeTeam);
	
	s_TeamA = new ArrayList(MAXPLAYERS + 1);
	ClearArray(s_TeamA);
	s_TeamB = new ArrayList(MAXPLAYERS + 1);
	ClearArray(s_TeamB);
	
	s_Menus = new ArrayList(1);
	ClearArray(s_Menus);
	
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnMapEnd()
{
	ResetWardenTimer();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	if (client == s_Warden)
	{
		ResetWardenTimer();
		s_Warden = -1;
		PrintToChatAll("\x03 [JailBreak] \x04 Warden died: \x0C %N", client);
	}
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3])
{
	if (victim == attacker || attacker == 0)
		return Plugin_Continue;

	if (IsClientValid(victim) && IsClientValid(attacker))
	{
		int victimTeam = GetClientTeam(victim);
		int attackerTeam = GetClientTeam(attacker);
		bool fists = damagetype == 4224;
		if (victimTeam == CS_TEAM_T && victimTeam == attackerTeam)
		{
			if (s_BoxMode == BM_RESTRICT && fists)
				return Plugin_Continue;
			else if (s_BoxMode == BM_CLASSIC)
				return Plugin_Continue;
			return Plugin_Handled;
		}
		else if (victimTeam == CS_TEAM_CT && attackerTeam == victimTeam)
			return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action OnPlayerDeath(Handle event, const char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientValid(client))
	{
		return Plugin_Handled;
	}
	
	if (client == s_Warden)
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(s_Warden, name, sizeof(name));
		if (String_StartsWith(name, "WARDEN "))
		{
			char newName[MAX_NAME_LENGTH];
			strcopy(newName, sizeof(newName), name[7]);
			SetClientName(s_Warden, newName);
		}
		
		ResetWardenTimer();
		s_Warden = -1;
		PrintToChatAll("\x03 [URNA Warden] \x04 Warden died: \x0C %N", client);
	}
	
	return Plugin_Handled;
}

public Action OnRoundStart(Handle event, const char[] eventName, bool dontBroadcast)
{
	if (IsClientValid(s_Warden))
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(s_Warden, name, sizeof(name));
		if (String_StartsWith(name, "WARDEN "))
		{
			char newName[MAX_NAME_LENGTH];
			strcopy(newName, sizeof(newName), name[7]);
			SetClientName(s_Warden, newName);
		}
	}
	
	s_Ball = -1;
	int lastWarden = s_Warden;
	s_Warden = -1;
	s_BoxMode = BM_NONE;
	s_Wg = WG_NONE;
	ClearArray(s_TeamA);
	ClearArray(s_TeamB);
	DeleteMenus(s_Menus);
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	ResetWardenTimer();
	s_BoxMode = BM_NONE;
}

public Action OnPlayerChangeTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	EndWarden(client);
}

void StartWarden(int client)
{
	if (!IsClientValid(client))
		return;
	
	if (s_Warden == -1)
	{
		if (GetClientTeam(client) != CS_TEAM_CT)
		{
			ReplyToCommand(client, "[URNA Warden] Only CTs can be warden");
		}
		else if (!IsPlayerAlive(client))
		{
			ReplyToCommand(client, "[URNA Warden] Only alive player can be wardens");
		}
		else
		{
			ResetWardenTimer();
			s_WardenTimer = CreateTimer(60.0, TimerCallbackWarden, GetClientUserId(client), TIMER_REPEAT);
			s_Warden = client;
			PrintCenterTextAll("%N is current Warden", s_Warden);
			ReplyToCommand(client, "[URNA Warden] You are Warden now! !wmenu to open warden menu, !uw (!unwarden) to leave Warden, !o (!open) to open cells");
			
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, sizeof(name));
			char newName[MAX_NAME_LENGTH];
			Format(newName, sizeof(newName), "WARDEN %s", name);
			SetClientName(client, newName);
			
			OnWardenChanged(s_Warden);
		}
	}
	else
	{
		ReplyToCommand(client, "[URNA Warden] Sorry, %N is current Warden", s_Warden);
	}
}

void EndWarden(int client)
{
	if (!IsClientValid(client))
		return;
	
	if (client == s_Warden)
	{
		ResetWardenTimer();
		PrintCenterTextAll("%N is not Warden anymore", s_Warden);
		ReplyToCommand(client, "[URNA Warden] You are not Warden anymore");
		s_Warden = -1;
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		if (String_StartsWith(name, "WARDEN "))
		{
			char newName[MAX_NAME_LENGTH];
			strcopy(newName, sizeof(newName), name[7]);
			SetClientName(client, newName);
		}
		
		OnWardenChanged(-1);
	}
	else
	{
		ReplyToCommand(client, "[URNA Warden] You are not Warden");
	}
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (StrEqual(sArgs, "!W", true))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
		StartWarden(client);
		SetCmdReplySource(old);
	}
}

public Action CMDWarden(int client, int argc)
{
	StartWarden(client);
	return Plugin_Handled;
}

public Action TimerCallbackWarden(Handle plugin, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client == s_Warden)
	{
		OnWardenMinute(client);
	}
}

public Action CMDUnwarden(int client, int args)
{
	EndWarden(client);
	return Plugin_Handled;
}

public Action CMDOpen(int client, int args)
{
	if (client == s_Warden)
	{
		OpenDoors();
		ReplyToCommand(client, "[URNA Warden] Cells were opened");
	}
	else
	{
		ReplyToCommand(client, "[URNA Warden] You need to be warden to use this command");
	}
	
	return Plugin_Handled;
}

void DisplayWardenMenu(int client)
{
	if (client == s_Warden)
	{
		Menu menu = new Menu(CallbackMenuWarden, MENU_ACTIONS_ALL);
		menu.SetTitle("Simon Menu");
		menu.AddItem("minigames", "Minigames");
		menu.AddItem("teamselect", "Team Select");
		menu.AddItem("box", "Box mode");
		menu.AddItem("opencells", "Open Cells");
		menu.AddItem("ball", "Spawn Ball");
			
		menu.Display(client, MENU_TIME_FOREVER);
		s_Menus.Push(menu);
	}
	else
	{
		ReplyToCommand(client, "[URNA Warden] You need to be Warden to use this command");
	}
}

public Action CMDWardenMenu(int client, int args)
{
	DisplayWardenMenu(client);
	return Plugin_Handled;
}

void CreateMenuBoxMode(Menu& menu)
{
	menu.RemoveAllItems();
	menu.SetTitle("Box Modes");
	if (s_BoxMode == BM_CLASSIC)
		menu.AddItem("classic", "Classic Box (On)");
	else
		menu.AddItem("classic", "Classic Box");
	if (s_BoxMode == BM_RESTRICT)
		menu.AddItem("restrict", "Restricted Box (On)");
	else
		menu.AddItem("restrict", "Restricted Box");
	menu.AddItem("off", "Off Box Mode");
	menu.ExitBackButton = true;
}

void SpawnWardenBall()
{
	if (!IsClientValid(s_Warden) || !IsClientInGame(s_Warden))
		return;
	
	float vec[2][3];
	GetClientEyePosition(s_Warden, vec[0]);
	GetClientEyeAngles(s_Warden, vec[1]);
	
	Handle trace = TR_TraceRayFilterEx(vec[0], vec[1], MASK_SOLID, RayType_Infinite, Filter_ExcludePlayers);
	if (!TR_DidHit(trace))
	{
		return;
	}
	TR_GetEndPosition(vec[0], trace);
	CloseHandle(trace);
	
	int ball = CreateEntityByName("prop_physics_multiplayer");
	if (!IsValidEntity(ball))
	{
		return;
	}
	
	DispatchKeyValue(ball, "model", MODEL_BALL);
	DispatchKeyValue(ball, "physicsmode", "2");
	DispatchSpawn(ball);
	
	vec[0][2] = vec[0][2] + 16.0;
	TeleportEntity(ball, vec[0], NULL_VECTOR, NULL_VECTOR);
	
	s_Ball = ball;
}

void DeleteWardenBall()
{
	RemoveEntity(s_Ball);
	s_Ball = -1;
}

public int CallbackMenuWarden(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DisplayItem:
		{
			char name[32];
			char displayName[64];
			int style;
			menu.GetItem(param2, name, sizeof(name), style, displayName, sizeof(displayName));
			if (StrEqual(name, "ball"))
			{
				if (s_Ball == -1)
					return RedrawMenuItem("Spawn Ball");
				else
					return RedrawMenuItem("Delete Ball");
			}
			
			return RedrawMenuItem(displayName);
		}
		case MenuAction_Select:
		{
			char itemName[32];
			menu.GetItem(param2, itemName, sizeof(itemName));
			if (StrEqual(itemName, "minigames"))
			{
				Menu newMenu = new Menu(MenuCallbackWardenGames);
				newMenu.SetTitle("Simon Games Menu");
				newMenu.AddItem("hns", "Hide and Seek", ITEMDRAW_DISABLED);
				newMenu.ExitBackButton = true;
				newMenu.Display(param1, MENU_TIME_FOREVER);
				
				s_Menus.Push(newMenu);
			}
			else if (StrEqual(itemName, "teamselect"))
			{
				Menu newMenu = new Menu(CallbackMenuWardenSelectTeam);
				newMenu.SetTitle("Aim at prisoners and press 1 / 2 to select their team");
				newMenu.AddItem("teama", "Team A");
				newMenu.AddItem("teamb", "Team B");
				newMenu.ExitBackButton = true;
				newMenu.Display(param1, MENU_TIME_FOREVER);
				
				s_Menus.Push(newMenu);
			}
			else if (StrEqual(itemName, "box"))
			{
				Menu newMenu = new Menu(CallbackMenuBoxMode);
				CreateMenuBoxMode(newMenu);
				newMenu.Display(param1, MENU_TIME_FOREVER);
				
				s_Menus.Push(newMenu);
			}
			else if (StrEqual(itemName, "opencells"))
			{
				OpenDoors();
				DisplayMenuThis(s_Menus, s_Warden);
			}
			else if (StrEqual(itemName, "ball"))
			{
				if (s_Ball == -1)
					SpawnWardenBall();
				else
					DeleteWardenBall();
				DisplayMenuThis(s_Menus, s_Warden);
			}
		}
		case MenuAction_End:
		{
			if (param1 == MenuEnd_ExitBack || param1 == MenuEnd_Exit)
			{
				DeleteMenus(s_Menus);
			}
		}
	}

	return 0;
}

public int MenuCallbackWardenGames(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char itemName[32];
			menu.GetItem(param2, itemName, sizeof(itemName));
			if (StrEqual(itemName, "hns"))
			{
				s_Wg = WG_HNS;
				PrintToChatAll(" \x03 [URNA Warden] \x04 Warden \x0C %N \x04 has selected the game Hide and Seek", s_Warden);
				// TODO: Implement HNS
				for (int i = 1; i <= MaxClients; ++i)
				{
					if (IsClientValid(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T)
					{
						Disarm(i);
					}
				}
			}
		}
		case MenuAction_End:
		{
			switch (param1)
			{
				case MenuEnd_Selected:
				{
					DisplayMenuThis(s_Menus, s_Warden);
				}
				case MenuEnd_ExitBack:
				{
					DisplayMenuLast(s_Menus, s_Warden);
				}
				default:
				{
					DeleteMenus(s_Menus);
				}
			}
		}
	}
	
	return 0;
}

public int CallbackMenuBoxMode(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char itemName[32];
			menu.GetItem(param2, itemName, sizeof(itemName));
			if (StrEqual(itemName, "classic"))
			{
				s_BoxMode = BM_CLASSIC;
				PrintCenterTextAll("Classic Box mode turned on");
			}
			else if (StrEqual(itemName, "restrict"))
			{
				s_BoxMode = BM_RESTRICT;
				PrintCenterTextAll("Restricted Box mode turned on");
			}
			else
			{
				s_BoxMode = BM_NONE;
				PrintCenterTextAll("Box mode turned off");
			}
			
			CreateMenuBoxMode(menu);
		}
		case MenuAction_End:
		{
			switch (param1)
			{
				case MenuEnd_Selected:
				{
					DisplayMenuThis(s_Menus, s_Warden);
				}
				case MenuEnd_ExitBack:
				{
					DisplayMenuLast(s_Menus, s_Warden);
				}
				default:
				{
					DeleteMenus(s_Menus);
				}
			}
		}
	}
	
	return 0;
}

public int CallbackMenuWardenSelectTeam(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char itemName[32];
			menu.GetItem(param2, itemName, sizeof(itemName));
			int target = GetClientAimTarget(param1, true);
			if (IsClientValid(target) && IsPlayerAlive(param1) && GetClientTeam(target) == CS_TEAM_T)
			{
				bool inTeamA = s_TeamA.FindValue(target) != -1;
				bool inTeamB = s_TeamB.FindValue(target) != -1;
				if (StrEqual(itemName, "teama"))
				{
					if (!inTeamA && !inTeamB)
					{
						s_TeamA.Push(target);
						SetEntityRenderMode(target, RENDER_GLOW);
						SetEntityRenderColor(target, 0, 255, 0, 255);
						PrintCenterText(target, "You have been assigned to <font color='#ff0000'>Team A</font> (red)");
					}
					else if (inTeamB)
					{
						s_TeamA.Push(target);
						s_TeamB.Erase(s_TeamB.FindValue(target));
						SetEntityRenderMode(target, RENDER_TRANSCOLOR);
						SetEntityRenderColor(target, 0, 255, 0, 255);
						PrintCenterText(target, "You have been reassigned to <font color='#ff0000'>Team</font> A (red)");
					}
					else if (inTeamA)
					{
						s_TeamA.Erase(s_TeamA.FindValue(target));
						SetEntityRenderMode(target, RENDER_TRANSCOLOR);
						SetEntityRenderColor(target, 255, 255, 255, 255);
						PrintCenterText(target, "<font color='#ffffff'>You are not in a team anymore</font>");
					}
				}
				else // teamb
				{
					if (!inTeamB && !inTeamA)
					{
						s_TeamB.Push(target);
						SetEntityRenderMode(target, RENDER_TRANSCOLOR);
						SetEntityRenderColor(target, 0, 0, 255, 255);
						PrintCenterText(target, "You have been assigned to <font color='#0000ff'>Team B</font> (blue)");
					}
					else if (inTeamA)
					{
						s_TeamB.Push(target);
						s_TeamA.Erase(s_TeamA.FindValue(target));
						SetEntityRenderMode(target, RENDER_TRANSCOLOR);
						SetEntityRenderColor(target, 0, 0, 255, 255);
						PrintCenterText(target, "You have been reassigned to <font color='#0000ff'>Team B</font> (blue)");
					}
					else if (inTeamB)
					{
						s_TeamB.Erase(s_TeamB.FindValue(target));
						SetEntityRenderMode(target, RENDER_TRANSCOLOR);
						SetEntityRenderColor(target, 255, 255, 255, 255);
						PrintCenterText(target, "<font color='#ffffff'>You are not in a team anymore</font>");
					}
				}
			}
		}
		case MenuAction_End:
		{
			switch (param1)
			{
				case MenuEnd_Selected:
				{
					DisplayMenuThis(s_Menus, s_Warden);
				}
				case MenuEnd_ExitBack:
				{
					DisplayMenuLast(s_Menus, s_Warden);
				}
				default:
				{
					DeleteMenus(s_Menus);
				}
			}
		}
	}
}

void DisplayMenuThis(ArrayList& menuHandles, int client, int time = MENU_TIME_FOREVER)
{
	Menu thisMenu = view_as<Menu>(menuHandles.Get(menuHandles.Length - 1));
	thisMenu.Display(client, time);
}

void DisplayMenuLast(ArrayList& menuHandles, int client, int time = MENU_TIME_FOREVER)
{
	Menu thisMenu = view_as<Menu>(menuHandles.Get(menuHandles.Length - 1));
	Menu lastMenu = view_as<Menu>(menuHandles.Get(menuHandles.Length - 2));
	delete thisMenu;
	menuHandles.Erase(menuHandles.Length - 1);
	lastMenu.Display(client, time);
}

void DeleteMenus(ArrayList& menuHandles)
{
	for (int i = 0; i < menuHandles.Length; ++i)
	{
		Menu menu = view_as<Menu>(menuHandles.Get(i));
		delete menu;
	}
	
	ClearArray(menuHandles);
}

public bool Filter_ExcludePlayers(int entity, int contentsMask, any data)
{
	return !((entity > 0) && (entity <= MaxClients));
}

// int GetWarden()
public int __GetWarden(Handle plugin, int numParams)
{
	return s_Warden;
}