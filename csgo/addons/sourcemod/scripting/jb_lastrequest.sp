#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <cstrike>
#include <sdkhooks>

#include <jb_lastrequest>
#include <jb_core>
#include <jb_jailbreak>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Jailbreak LR Plugin",
	author = PLUGIN_AUTHOR,
	description = "Jailbreak Last Request",
	version = PLUGIN_VERSION,
	url = ""
};


static LrGroup s_ActiveLrGroup = LRG_NO_LR;
static LrGame s_ActiveLr = LR_NO_LR;
static LrGame s_PredictActiveLr = LR_NO_LR;
static int s_LrPlayerT = -1;
static int s_LrPlayerCt = -1;

// Gun Toss
static int s_LrDeagleT = -1;
static int s_LrDeagleCt = -1;
static float s_DeagleLastPosT[3] = { 0.0, 0.0, 0.0 };
static float s_DeagleLastPosCt[3] = { 0.0, 0.0, 0.0 };
static bool s_DeagleDroppedT = false;
static bool s_DeagleDroppedCt = false;

// Hot Potato
#define HOT_POTATO_TIME_UPPER 30.0
#define HOT_POTATO_TIME_LOWER 15.0

static int s_LrDeagle = -1;
static int s_LrDeagleLastOwner = -1;

static const char s_LrNames[view_as<int>(LR_REBEL) + 1][32];

static Timer s_LrFunctions[view_as<int>(LRG_REBEL) + 1];

int s_BeamSprite = -1;
int s_HaloSprite = -1;

void ResetLr()
{
	if (IsClientValid(s_LrPlayerT))
		SetEntityGravity(s_LrPlayerT, 1.0);
	if (IsClientValid(s_LrPlayerCt))
		SetEntityGravity(s_LrPlayerCt, 1.0);
	
	s_ActiveLrGroup = LRG_NO_LR;
	s_ActiveLr = LR_NO_LR;
	s_PredictActiveLr = LR_NO_LR;
	s_LrPlayerT = -1;
	s_LrPlayerCt = -1;
	
	// Gun Toss
	s_LrDeagleT = -1;
	s_LrDeagleCt = -1;
	s_DeagleLastPosT[0] = 0.0;
	s_DeagleLastPosT[1] = 0.0;
	s_DeagleLastPosT[2] = 0.0;
	s_DeagleLastPosCt[0] = 0.0;
	s_DeagleLastPosCt[1] = 0.0;
	s_DeagleLastPosCt[2] = 0.0;
	s_DeagleDroppedT = false;
	s_DeagleDroppedCt = false;
	
	// Hot Potato
	s_LrDeagle = -1;
	s_LrDeagleLastOwner = -1;
}

Action StartLrNoLr(Handle timer, any arg)
{
	
}

Action StartLrClose(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	LrGame activeLr = GetActiveLr();
	
	if (activeLr == LR_1HP_KNIFE ||activeLr == LR_100HP_KNIFE)
	{
		GivePlayerItem(tPlayer, "weapon_knife");
		GivePlayerItem(ctPlayer, "weapon_knife");
	}
	else
	{
		GivePlayerItem(tPlayer, "weapon_fists");
		GivePlayerItem(ctPlayer, "weapon_fists");
	}
	
	if (activeLr == LR_1HP_KNIFE || activeLr == LR_1HP_FISTS)
	{
		SetEntityHealth(tPlayer, 1);
		SetEntityHealth(ctPlayer, 1);
	}
	else
	{
		SetEntityHealth(tPlayer, 100);
		SetEntityHealth(ctPlayer, 100);
	}
}

Action StartLrNoscope(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	LrGame activeLr = GetActiveLr();
	
	GivePlayerItem(tPlayer, "weapon_knife");
	GivePlayerItem(ctPlayer, "weapon_knife");
	
	int weapon1, weapon2;
	if (activeLr == LR_NOSCOPE_SCOUT)
	{
		weapon1 = GivePlayerItem(tPlayer, "weapon_ssg08");
		weapon2 = GivePlayerItem(ctPlayer, "weapon_ssg08");
	}
	else if (activeLr == LR_NOSCOPE_AWP)
	{
		weapon1 = GivePlayerItem(tPlayer, "weapon_awp");
		weapon2 = GivePlayerItem(ctPlayer, "weapon_awp");
	}
	else if (activeLr == LR_NOSCOPE_G3SG1)
	{
		weapon1 = GivePlayerItem(tPlayer, "weapon_g3sg1");
		weapon2 = GivePlayerItem(ctPlayer, "weapon_g3sg1");
	}
	else // LR_NOSCOPE_SCAR20
	{
		weapon1 = GivePlayerItem(tPlayer, "weapon_scar20");
		weapon2 = GivePlayerItem(ctPlayer, "weapon_scar20");
	}
	
	GivePlayerAmmoEx(tPlayer, weapon1, 1000);
	GivePlayerAmmoEx(ctPlayer, weapon2, 1000);
	
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
}

Action StartLrDodgeball(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	LrGame activeLr = GetActiveLr();
	
	if (activeLr == LR_DODGEBALL_FLASHBANG)
	{
		GivePlayerItem(tPlayer, "weapon_flashbang");
		GivePlayerItem(ctPlayer, "weapon_flashbang");
	}
	else // LR_DODGEBALL_SNOWBALL
	{
		GivePlayerItem(tPlayer, "weapon_snowball");
		GivePlayerItem(ctPlayer, "weapon_snowball");
	}
	
	SetEntityGravity(tPlayer, 0.5);
	SetEntityGravity(ctPlayer, 0.5);
	SetEntityHealth(tPlayer, 1);
	SetEntityHealth(ctPlayer, 1);
}

Action StartLrShot4Shot(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	LrGame activeLr = GetActiveLr();
	
	GivePlayerItem(tPlayer, "weapon_knife");
	GivePlayerItem(ctPlayer, "weapon_knife");
	
	int weaponT, weaponCt;
	if (activeLr == LR_S4S_DEAGLE)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_deagle");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_deagle");
	}
	else if (activeLr == LR_S4S_REVOLVER)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_revolver");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_revolver");
	}
	else if (activeLr == LR_S4S_GLOCK)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_glock");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_glock");
	}
	else if (activeLr == LR_S4S_P2000)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_hkp2000");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_hkp2000");
	}
	else if (activeLr == LR_S4S_USP)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_usp_silencer");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_usp_silencer");
	}
	else if (activeLr == LR_S4S_P250)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_p250");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_p250");
	}
	else if (activeLr == LR_S4S_TEC9)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_tec9");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_tec9");
	}
	else if (activeLr == LR_S4S_FIVESEVEN)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_fiveseven");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_fiveseven");
	}
	else if (activeLr == LR_S4S_CZ75)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_cz75a");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_cz75a");
	}
	else if (activeLr == LR_S4S_DUALS)
	{
		weaponT = GivePlayerItem(tPlayer, "weapon_elite");
		weaponCt = GivePlayerItem(ctPlayer, "weapon_elite");
	}
	
	SetPlayerAmmo(tPlayer, weaponT, 0);
	SetPlayerMagAmmo(weaponT, 1);
	SetPlayerAmmo(ctPlayer, weaponCt, 0);
	SetPlayerMagAmmo(weaponCt, 0);
	
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
}

Action StartLrGunToss(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
	
	GivePlayerItem(tPlayer, "weapon_knife");
	GivePlayerItem(ctPlayer, "weapon_knife");
	s_LrDeagleT = GivePlayerItem(tPlayer, "weapon_deagle");
	s_LrDeagleCt = GivePlayerItem(ctPlayer, "weapon_deagle");
	SetPlayerAmmo(tPlayer, s_LrDeagleT, 0);
	SetPlayerAmmo(ctPlayer, s_LrDeagleCt, 0);
	SetPlayerMagAmmo(s_LrDeagleT, 0);
	SetPlayerMagAmmo(s_LrDeagleCt, 0);
}

Action StartLrHotPotato(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
	
	GivePlayerItem(tPlayer, "weapon_knife");
	GivePlayerItem(ctPlayer, "weapon_knife");
	if (GetRandomInt(0, 1) == 0)
	{
		s_LrDeagle = GivePlayerItem(ctPlayer, "weapon_deagle");
		s_LrDeagleLastOwner = ctPlayer;
		SetPlayerAmmo(ctPlayer, s_LrDeagle, 0);
	}
	else
	{
		s_LrDeagle = GivePlayerItem(tPlayer, "weapon_deagle");
		s_LrDeagleLastOwner = tPlayer;
		SetPlayerAmmo(tPlayer, s_LrDeagle, 0);
	}
	
	SetPlayerMagAmmo(s_LrDeagle, 0);
	
	float randomTime = GetRandomFloat(HOT_POTATO_TIME_LOWER, HOT_POTATO_TIME_UPPER);
	CreateTimer(randomTime, TimerCallbackHotPotato);
}

Action StartLrChickenFight(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
	
	CreateTimer(0.1, TimerLrChickenFightCheck, _, TIMER_REPEAT);
}

Action StartLrRebel(Handle timer, any arg)
{
	int tPlayer = GetPlayerInLrFromTeam(CS_TEAM_T);
	SetEntityHealth(tPlayer, 200);
	SetPlayerArmor(tPlayer, 100);
	GivePlayerItem(tPlayer, "weapon_m249");
	GivePlayerItem(tPlayer, "weapon_deagle");
	GivePlayerItem(tPlayer, "weapon_knife");
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientValid(i) && IsPlayerAlive(i))
		{
			SetEntityHealth(i, 100);
			SetPlayerArmor(i, 100);
			SetPlayerHelmet(i, true);
		}
	}
}

public Action TimerLrChickenFightCheck(Handle timer, any data)
{
	if (IsLrInProgress())
	{
		int tPlayer, ctPlayer;
		GetPlayersInLr(tPlayer, ctPlayer);
		int winner = ChickenFightCheck(tPlayer, ctPlayer);
		if (winner != -1)
		{
			int loser = (winner == tPlayer ? ctPlayer : tPlayer);
			PrintToChatAll("Chicken fight winner: %N", winner);
			PrintToChatAll("Slaying loser: %N", loser);
			
			ForcePlayerSuicide(loser);
			
			Handle event = CreateEvent("player_death");
			SetEventInt(event, "userid", GetClientUserId(loser));
			SetEventInt(event, "attacker", GetClientUserId(winner));
			SetEventString(event, "weapon", "");
			FireEvent(event, true);

			KillTimer(timer);
		}
	}
	else
		KillTimer(timer);
}


public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("IsPlayerInLr", native_IsPlayerInLr);
	CreateNative("GetPlayersInLr", native_GetPlayersInLr);
	CreateNative("GetPlayerInLrFromTeam", native_GetPlayerInLrFromTeam);
	CreateNative("GetActiveLr", native_GetActiveLr);
	CreateNative("GetActiveLrGroup", native_GetActiveLrGroup);
	CreateNative("IsLrInProgress", native_IsLrInProgress);

	RegPluginLibrary("jb_lastrequest.inc");
	return APLRes_Success;
}

// TODO: Duplication with player_death
public void OnClientDisconnect(int client)
{
	if (s_ActiveLr != LR_NO_LR)
	{
		if (client == s_LrPlayerT || client == s_LrPlayerCt)
		{
			if (IsClientValid(s_LrPlayerT))
				ServerCommand("sm_beacon #%i", GetClientUserId(s_LrPlayerT));
			if (IsClientValid(s_LrPlayerCt))
				ServerCommand("sm_beacon #%i", GetClientUserId(s_LrPlayerCt));
			ResetLr();
		}
	}
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_lr", CMDLastRequest);
	RegConsoleCmd("sm_pp", CMDLastRequest);
	RegConsoleCmd("sm_lastrequest", CMDLastRequest);
	
	HookEvent("player_death", OnPlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeathPost, EventHookMode_Post);
	HookEvent("grenade_thrown", OnGrenadeThrown, EventHookMode_Post);
	HookEvent("player_blind", OnPlayerBlind);
	HookEvent("weapon_fire", OnWeaponFire);
	
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	
	s_LrNames[0] = "No LR";
	s_LrNames[1] = "1HP Knife Fight";
	s_LrNames[2] = "Normal Knife Fight";
	s_LrNames[3] = "1HP Fist Fight";
	s_LrNames[4] = "Normal Fist Fight";
	s_LrNames[5] = "Chicken Fight";
	s_LrNames[6] = "Gun Toss";
	s_LrNames[7] = "Noscope SSG 08";
	s_LrNames[8] = "Noscope AWP";
	s_LrNames[9] = "Noscope G3SG1";
	s_LrNames[10] = "Noscope SCAR-20";
	s_LrNames[11] = "Dodgeball with Meelee";
	s_LrNames[12] = "Dodgeball with Flashbang";
	s_LrNames[13] = "Dodgeball with Snowball";
	s_LrNames[14] = "Hot Potato";
	s_LrNames[15] = "Shot4Shot Deagle";
	s_LrNames[16] = "Shot4Shot Revolver";
	s_LrNames[17] = "Shot4Shot Glock";
	s_LrNames[18] = "Shot4Shot P2000";
	s_LrNames[19] = "Shot4Shot USP";
	s_LrNames[20] = "Shot4Shot P250";
	s_LrNames[21] = "Shot4Shot Dual Berettas";
	s_LrNames[22] = "Shot4Shot Tec9";
	s_LrNames[23] = "Shot4Shot Fiveseven";
	s_LrNames[24] = "Shot4Shot CZ75";
	s_LrNames[25] = "Rebel";
	
	s_LrFunctions[0] = StartLrNoLr;
	s_LrFunctions[1] = StartLrClose;
	s_LrFunctions[2] = StartLrNoscope;
	s_LrFunctions[3] = StartLrDodgeball;
	s_LrFunctions[4] = StartLrShot4Shot;
	s_LrFunctions[5] = StartLrChickenFight;
	s_LrFunctions[6] = StartLrGunToss;
	s_LrFunctions[7] = StartLrHotPotato;
	s_LrFunctions[8] = StartLrRebel;
}

public void OnMapStart()
{
	s_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	s_HaloSprite = PrecacheModel("materials/sprites/glow01.vmt");
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, OnPreThink);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public Action OnPlayerDeathPre(Handle event, const char[] name, bool dontBroadcast)
{
	if (s_ActiveLr == LR_CHICKEN_FIGHT)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		if (client == attacker || attacker == 0)
		{
			if (IsPlayerInLr(client))
				return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action OnPlayerDeathPost(Handle event, const char[] name, bool dontBroadcast)
{
	if (s_ActiveLr != LR_NO_LR)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client == s_LrPlayerT || client == s_LrPlayerCt)
		{
			if (IsClientValid(s_LrPlayerT))
				ServerCommand("sm_beacon #%i", GetClientUserId(s_LrPlayerT));
			if (IsClientValid(s_LrPlayerCt))
				ServerCommand("sm_beacon #%i", GetClientUserId(s_LrPlayerCt));
			ResetLr();
		}
	}
}

public Action OnGrenadeThrown(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (s_ActiveLr == LR_DODGEBALL_FLASHBANG)
	{
		Disarm(client);
		GivePlayerItemIn(0.5, client, "weapon_flashbang");
	}
	else if (s_ActiveLr == LR_DODGEBALL_SNOWBALL)
	{
		Disarm(client);
		GivePlayerItemIn(0.5, client, "weapon_snowball");
	}
}

public Action OnPlayerBlind(Handle event, const char[] name, bool dontBroadcast)
{
	if (s_ActiveLr == LR_DODGEBALL_FLASHBANG)
	{
		int client = GetClientOfUserId(GetEventInt(event,"userid"));
		SetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha", 0.5);
	}
}

public Action OnWeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	if (s_ActiveLr == LR_S4S_DEAGLE || s_ActiveLr == LR_S4S_REVOLVER || s_ActiveLr == LR_S4S_CZ75 || s_ActiveLr == LR_S4S_DUALS || s_ActiveLr == LR_S4S_FIVESEVEN ||
		s_ActiveLr == LR_S4S_GLOCK || s_ActiveLr == LR_S4S_P2000 || s_ActiveLr == LR_S4S_USP || s_ActiveLr == LR_S4S_TEC9 ||
		s_ActiveLr == LR_S4S_P250)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (client == s_LrPlayerT)
		{
			int weapon = GetPlayerWeaponSlot(s_LrPlayerCt, CS_SLOT_SECONDARY);
			SetPlayerMagAmmo(weapon, 1);
		}
		else if (client == s_LrPlayerCt)
		{
			int weapon = GetPlayerWeaponSlot(s_LrPlayerT, CS_SLOT_SECONDARY);
			SetPlayerMagAmmo(weapon, 1);
		}
	}
	
	return Plugin_Continue;
}

public Action OnPreThink(int client)
{
	if (s_ActiveLr == LR_NOSCOPE_AWP || s_ActiveLr == LR_NOSCOPE_SCOUT || s_ActiveLr == LR_NOSCOPE_SCAR20 || s_ActiveLr == LR_NOSCOPE_G3SG1)
	{
		if (client == s_LrPlayerT || client == s_LrPlayerCt)
		{
			int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
			if (weapon != -1)
				SetNoScope(weapon);
		}
	}
	
	return Plugin_Continue;
}

public Action OnWeaponDrop(int client, int weapon)
{
	if (s_ActiveLr == LR_GUN_TOSS && IsPlayerInLr(client) && (weapon == s_LrDeagleT || weapon == s_LrDeagleCt))
	{
		if (weapon == s_LrDeagleT && s_DeagleDroppedT)
		{
			PrintCenterText(client, "Sorry, you can drop deagle only once");
			return Plugin_Handled;
		}
		else if (weapon == s_LrDeagleCt && s_DeagleDroppedCt)
		{
			PrintCenterText(client, "Sorry, you can drop deagle only once");
			return Plugin_Handled;
		}
		
		if (weapon == s_LrDeagleT)
			s_DeagleDroppedT = true;
		else if (weapon == s_LrDeagleCt)
			s_DeagleDroppedCt = true;

		Handle kv = CreateKeyValues("data");
		KvSetNum(kv, "client", client);
		KvSetNum(kv, "weapon", weapon);
		CreateTimer(0.5, TimerCallbackGunTossDeagleDropped, kv, TIMER_REPEAT);
	}
	
	return Plugin_Continue;
}

public Action OnWeaponEquipPost(int client, int weapon)
{
	if (weapon == s_LrDeagleT && s_DeagleDroppedT)
		SetPlayerMagAmmo(weapon, 7);
	else if (weapon == s_LrDeagleCt && s_DeagleDroppedCt)
		SetPlayerMagAmmo(weapon, 7);
	else if (weapon == s_LrDeagle)
	{
		if (client == s_LrPlayerT || client == s_LrPlayerCt)
			s_LrDeagleLastOwner = client;
	}
	
	return Plugin_Continue;
}

public Action TimerCallbackHotPotato(Handle timer, any data)
{
	if (IsClientValid(s_LrDeagleLastOwner) && IsPlayerAlive(s_LrDeagleLastOwner))
		ForcePlayerSuicide(s_LrDeagleLastOwner);
}

public Action TimerCallbackGunTossDeagleDropped(Handle timer, Handle kv)
{
	int client = KvGetNum(kv, "client");
	int weapon = KvGetNum(kv, "weapon");
	if (!IsClientValid(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
	if (!IsValidEntity(weapon))
		return Plugin_Handled;

	float deaglePos[3];
	GetEntPropVector(weapon, Prop_Data, "m_vecOrigin", deaglePos);
	if (weapon == s_LrDeagleT)
	{
		if (GetVectorDistance(deaglePos, s_DeagleLastPosT) < 3.0)
		{
			float beamStartP1[3];		
			float f_SubtractVec[3] = { 0.0, 0.0, -30.0 };
			MakeVectorFromPoints(f_SubtractVec, s_DeagleLastPosT, beamStartP1);
			int redColor[] = { 255, 25, 15, 255};
			float fBeamWidth = 2.0;
			
			TE_SetupBeamPoints(beamStartP1, s_DeagleLastPosT, s_BeamSprite, 0, 0, 0, 20.0, fBeamWidth, fBeamWidth, 7, 0.0, redColor, 0);
			TE_SendToAll();
			
			CloseHandle(kv);
			KillTimer(timer);
		}
		else
		{
			s_DeagleLastPosT[0] = deaglePos[0];
			s_DeagleLastPosT[1] = deaglePos[1];
			s_DeagleLastPosT[2] = deaglePos[2];
		}
	}
	else if (weapon == s_LrDeagleCt)
	{
		if (GetVectorDistance(deaglePos, s_DeagleLastPosCt) < 3.0)
		{
			float beamStartP1[3];		
			float f_SubtractVec[3] = { 0.0, 0.0, -30.0 };
			MakeVectorFromPoints(f_SubtractVec, s_DeagleLastPosCt, beamStartP1);
			int blueColor[] = { 15, 25, 255, 255 };
			float fBeamWidth = 2.0;
			
			TE_SetupBeamPoints(beamStartP1, s_DeagleLastPosCt, s_BeamSprite, 0, 0, 0, 20.0, fBeamWidth, fBeamWidth, 7, 0.0, blueColor, 0);
			TE_SendToAll();
			
			CloseHandle(kv);
			KillTimer(timer);
		}
		else
		{
			s_DeagleLastPosCt[0] = deaglePos[0];
			s_DeagleLastPosCt[1] = deaglePos[1];
			s_DeagleLastPosCt[2] = deaglePos[2];
		}
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3],
                             int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (s_ActiveLr == LR_DODGEBALL_MEELEE && IsPlayerInLr(client))
	{
		if (buttons & IN_ATTACK)
			buttons &= ~IN_ATTACK;
	}
	return Plugin_Continue;
}

public Action CMDLastRequest(int client, int args)
{
	if (!IsClientValid(client))
	{
		return Plugin_Handled;
	}
	if (GetClientTeam(client) != CS_TEAM_T)
	{
		ReplyToCommand(client, "[URNA Last Request] You can use this commnad only when you are on T side");
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[URNA Last Request] You can use this commnad only when you are alive");
		return Plugin_Handled;
	}
	if (GetNumberOfPlayers(CS_TEAM_T, true) != 1)
	{
		ReplyToCommand(client, "[URNA Last Request] You can use this command only if you are the last alive on T side");
		return Plugin_Handled;
	}
	if (GetNumberOfPlayers(CS_TEAM_CT, true) == 0)
	{
		ReplyToCommand(client, "[URNA Last Request] You cannot use this command, nobody is alive on CT side");
		return Plugin_Handled;
	}
	if (s_ActiveLr != LR_NO_LR)
	{
		ReplyToCommand(client, "[URNA Last Request] Last Request is still in progress");
		return Plugin_Handled;
	}
	
	Menu menu = new Menu(CallbackLrMenu);
	menu.AddItem("closefight", "Close Fight");
	menu.AddItem("shot4shot", "Shot4Shot");
	menu.AddItem("noscope", "No Scope fight");
	menu.AddItem("dodgeball", "Dodgeball");
	menu.AddItem("guntoss", "Gun Toss");
	menu.AddItem("hotpotato", "Hot Potato");
	menu.AddItem("chickenfight", "Chicken fight");
	menu.AddItem("rebel", "Rebel");
	menu.Display(client, 30);
	
	return Plugin_Handled;
}

public int CallbackLrMenu(Menu menu, MenuAction action, int client, int option)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(option, item, sizeof(item));
			if (StrEqual(item, "closefight"))
			{
				Menu newMenu = new Menu(CallbackDetailedLr);
				newMenu.AddItem("knife1hp", "1HP Knife Fight");
				newMenu.AddItem("knife100hp", "100HP Knife Fight");
				newMenu.AddItem("fists1hp", "1HP Fists Fight");
				newMenu.AddItem("fists100hp", "100HP Fists Fight");
				newMenu.Display(client, 30);
			}
			else if (StrEqual(item, "shot4shot"))
			{
				Menu newMenu = new Menu(CallbackDetailedLr);
				newMenu.AddItem("s4sglock", "Glock");
				newMenu.AddItem("s4sp2000", "P2000");
				newMenu.AddItem("s4susp", "USP");
				newMenu.AddItem("s4sp250", "P250");
				newMenu.AddItem("s4sduals", "Dual Berettas");
				newMenu.AddItem("s4sfiveseven", "Fiveseven");
				newMenu.AddItem("s4stec9", "Tec9");
				newMenu.AddItem("s4scz75", "CZ75");
				newMenu.AddItem("s4sdeagle", "Deagle");
				newMenu.AddItem("s4srevolver", "Revolver");
				newMenu.Display(client, 30);
			}
			else if (StrEqual(item, "noscope"))
			{
				Menu newMenu = new Menu(CallbackDetailedLr);
				newMenu.AddItem("nsscout", "SSG 08");
				newMenu.AddItem("nsawp", "AWP");
				newMenu.AddItem("nsg3sg1", "G3SG1");
				newMenu.AddItem("nsscar20", "SCAR-20");
				newMenu.Display(client, 30);
			}
			else if (StrEqual(item, "dodgeball"))
			{
				Menu newMenu = new Menu(CallbackDetailedLr);
				newMenu.AddItem("dbflashbang", "Flashbang");
				newMenu.AddItem("dbsnowball", "Snowball");
				newMenu.Display(client, 30);
			}
			else if (StrEqual(item, "guntoss"))
			{
				s_PredictActiveLr = LR_GUN_TOSS;
				Menu newMenu = new Menu(CallbackPlayerChoose);
				AddPlayersToMenuSelection(newMenu, CS_TEAM_CT, true);
				newMenu.Display(client, 30);
			}
			else if (StrEqual(item, "hotpotato"))
			{
				s_PredictActiveLr = LR_HOT_POTATO;
				Menu newMenu = new Menu(CallbackPlayerChoose);
				AddPlayersToMenuSelection(newMenu, CS_TEAM_CT, true);
				newMenu.Display(client, 30);
			}
			else if (StrEqual(item, "chickenfight"))
			{
				s_PredictActiveLr = LR_CHICKEN_FIGHT;
				Menu newMenu = new Menu(CallbackPlayerChoose);
				AddPlayersToMenuSelection(newMenu, CS_TEAM_CT, true);
				newMenu.Display(client, 30);
			}
			else if (StrEqual(item, "rebel"))
			{
				s_PredictActiveLr = LR_REBEL;
				s_LrPlayerT = client;
				s_LrPlayerCt = -1;
				s_ActiveLr = LR_REBEL;
				s_ActiveLrGroup = GetLrGroupFromLrGame(LR_REBEL);
				
				char lrName[64];
				GetNameOfLr(LR_REBEL, lrName, sizeof(lrName));
				PrintToChatAll("Player %N doesn't want LR. He wants to stand strong!", client, lrName);
				
				Disarm(client);
				
				CreateTimer(2.0, s_LrFunctions[s_ActiveLrGroup]);
			}
		}
		
		case MenuAction_End:
			delete menu;
	}
}

public int CallbackDetailedLr(Menu menu, MenuAction action, int client, int option)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char item[32];
			menu.GetItem(option, item, sizeof(item));
			Menu newMenu = new Menu(CallbackPlayerChoose);
			AddPlayersToMenuSelection(newMenu, CS_TEAM_CT, true);
			newMenu.Display(client, 30);
			if (StrEqual(item, "knife1hp"))
			{
				s_PredictActiveLr = LR_1HP_KNIFE;
			}
			else if (StrEqual(item, "knife100hp"))
			{
				s_PredictActiveLr = LR_100HP_KNIFE;
			}
			else if (StrEqual(item, "fists1hp"))
			{
				s_PredictActiveLr = LR_1HP_FISTS;
			}
			else if (StrEqual(item, "fists100hp"))
			{
				s_PredictActiveLr = LR_100HP_FISTS;
			}
			else if (StrEqual(item, "s4sdeagle"))
			{
				s_PredictActiveLr = LR_S4S_DEAGLE;
			}
			else if (StrEqual(item, "s4srevolver"))
			{
				s_PredictActiveLr = LR_S4S_REVOLVER;
			}
			else if (StrEqual(item, "s4sglock"))
			{
				s_PredictActiveLr = LR_S4S_GLOCK;
			}
			else if (StrEqual(item, "s4sp2000"))
			{
				s_PredictActiveLr = LR_S4S_P2000;
			}
			else if (StrEqual(item, "s4susp"))
			{
				s_PredictActiveLr = LR_S4S_USP;
			}
			else if (StrEqual(item, "s4sp250"))
			{
				s_PredictActiveLr = LR_S4S_P250;
			}
			else if (StrEqual(item, "s4sduals"))
			{
				s_PredictActiveLr = LR_S4S_DUALS;
			}
			else if (StrEqual(item, "s4stec9"))
			{
				s_PredictActiveLr = LR_S4S_TEC9;
			}
			else if (StrEqual(item, "s4sfiveseven"))
			{
				s_PredictActiveLr = LR_S4S_FIVESEVEN;
			}
			else if (StrEqual(item, "s4scz75"))
			{
				s_PredictActiveLr = LR_S4S_CZ75;
			}
			else if (StrEqual(item, "nsscout"))
			{
				s_PredictActiveLr = LR_NOSCOPE_SCOUT;
			}
			else if (StrEqual(item, "nsawp"))
			{
				s_PredictActiveLr = LR_NOSCOPE_AWP;
			}
			else if (StrEqual(item, "nsg3sg1"))
			{
				s_PredictActiveLr = LR_NOSCOPE_G3SG1;
			}
			else if (StrEqual(item, "nsscar20"))
			{
				s_PredictActiveLr = LR_NOSCOPE_SCAR20;
			}
			else if (StrEqual(item, "dbflashbang"))
			{
				s_PredictActiveLr = LR_DODGEBALL_FLASHBANG;
			}
			else if (StrEqual(item, "dbsnowball"))
			{
				s_PredictActiveLr = LR_DODGEBALL_SNOWBALL;
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int CallbackPlayerChoose(Menu menu, MenuAction action, int client, int option)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char ctTargetStringNum[3];
			menu.GetItem(option, ctTargetStringNum, sizeof(ctTargetStringNum));
			int ctPlayer = StringToInt(ctTargetStringNum);
			if (IsClientValid(client) && IsPlayerAlive(client) && IsClientValid(ctPlayer) && IsPlayerAlive(ctPlayer))
			{
				PreparePlayersForLr(client, ctPlayer, s_PredictActiveLr);
			}
			else
			{
				PrintToChat(client, "[Jailbreak Last Request] Cannot start Last Request");
				delete menu;
			}
		}
		case MenuAction_End:
			delete menu;
	}
	
	return 0;
}

public int MenuCallbackAskRebel(Menu menu, MenuAction action, int client, int option)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char ctTargetStringNum[3];
			menu.GetItem(option, ctTargetStringNum, sizeof(ctTargetStringNum));
			int ctPlayer = StringToInt(ctTargetStringNum);
			if (IsClientValid(client) && IsPlayerAlive(client) && IsClientValid(ctPlayer) && IsPlayerAlive(ctPlayer))
			{
				if (IsRebel(client))
				{
					Menu newMenu = new Menu(MenuCallbackAskRebel);
					newMenu.SetTitle("Do you want LastRequest with rebel %N ?", client);
				}
				else
					PreparePlayersForLr(client, ctPlayer, s_PredictActiveLr);
			}
			else
			{
				PrintToChat(client, "[Jailbreak Last Request] Cannot start Last Request");
				delete menu;
			}
		}
		case MenuAction_End:
			delete menu;
	}
	
	return 0;
}

void PreparePlayersForLr(int tPlayer, int ctPlayer, LrGame lrGame)
{
	s_LrPlayerT = tPlayer;
	s_LrPlayerCt = ctPlayer;
	s_ActiveLr = lrGame;
	s_ActiveLrGroup = GetLrGroupFromLrGame(lrGame);
	
	ServerCommand("sm_beacon #%i", GetClientUserId(tPlayer));
	ServerCommand("sm_beacon #%i", GetClientUserId(ctPlayer));
	
	char lrName[64];
	GetNameOfLr(lrGame, lrName, sizeof(lrName));
	PrintToChatAll("Player %N has selected lr game %s with player %N", tPlayer, lrName, ctPlayer);
	
	Disarm(tPlayer);
	Disarm(ctPlayer);
	
	CreateTimer(2.0, s_LrFunctions[s_ActiveLrGroup]);
}

void GetNameOfLr(LrGame lrGame, char[] buffer, int bufferLength)
{
	strcopy(buffer, bufferLength, s_LrNames[lrGame]);
}

LrGroup GetLrGroupFromLrGame(LrGame lrGame)
{
	switch (lrGame)
	{
		case LR_NO_LR:return LRG_NO_LR;
		case LR_1HP_KNIFE: return LRG_CLOSE;
		case LR_100HP_KNIFE: return LRG_CLOSE;
		case LR_1HP_FISTS: return LRG_CLOSE;
		case LR_100HP_FISTS: return LRG_CLOSE;
		case LR_CHICKEN_FIGHT: return LRG_CHICKEN_FIGHT;
		case LR_GUN_TOSS: return LRG_GUN_TOSS;
		case LR_NOSCOPE_AWP: return LRG_NOSCOPE;
		case LR_NOSCOPE_SCOUT: return LRG_NOSCOPE;
		case LR_NOSCOPE_SCAR20: return LRG_NOSCOPE;
		case LR_NOSCOPE_G3SG1: return LRG_NOSCOPE;
		case LR_DODGEBALL_FLASHBANG: return LRG_DODGEBALL;
		case LR_DODGEBALL_MEELEE: return LRG_DODGEBALL;
		case LR_DODGEBALL_SNOWBALL: return LRG_DODGEBALL;
		case LR_HOT_POTATO: return LRG_HOT_POTATO;
		case LR_S4S_DEAGLE: return LRG_S4S;
		case LR_S4S_REVOLVER: return LRG_S4S;
		case LR_S4S_GLOCK: return LRG_S4S;
		case LR_S4S_P2000: return LRG_S4S;
		case LR_S4S_USP: return LRG_S4S;
		case LR_S4S_P250: return LRG_S4S;
		case LR_S4S_DUALS: return LRG_S4S;
		case LR_S4S_FIVESEVEN: return LRG_S4S;
		case LR_S4S_TEC9: return LRG_S4S;
		case LR_S4S_CZ75: return LRG_S4S;
		case LR_REBEL: return LRG_REBEL;
	}
	
	return LRG_NO_LR;
}


// int IsPlayerInLr(int client);
public int native_IsPlayerInLr(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return (s_ActiveLr != LR_NO_LR && (client == s_LrPlayerT || client == s_LrPlayerCt));
}

// int GetPlayersInLr(int& tPlayer, int& ctPlayer);
public int native_GetPlayersInLr(Handle plugin, int numParams)
{
	SetNativeCellRef(1, s_LrPlayerT);
	SetNativeCellRef(2, s_LrPlayerCt);
	return 0;
}

// int GetPlayerInLrFromTeam(int team);
public int native_GetPlayerInLrFromTeam(Handle plugin, int numParams)
{
	int team = GetNativeCell(1);
	if (team == CS_TEAM_T)
		return s_LrPlayerT;
	else if (team == CS_TEAM_CT)
		return s_LrPlayerCt;
		
	return -1;
}

// int GetActiveLr();
public int native_GetActiveLr(Handle plugin, int numParams)
{
	return view_as<int>(s_ActiveLr);
}

// int GetActiveLrGroup();
public int native_GetActiveLrGroup(Handle plugin, int numParams)
{
	return view_as<int>(s_ActiveLrGroup);
}

// bool IsLrInProgress();
public int native_IsLrInProgress(Handle plugin, int numParams)
{
	return s_ActiveLr != LR_NO_LR;
}
