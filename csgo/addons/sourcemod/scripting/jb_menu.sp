#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sdktools>
#include <sdkhooks>

#include <jb_models>
#include <jb_core>
#include <jb_vip>
#include <jb_jailbreak>
#include <jb_menu>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Jailbreak Shop Plugin",
	author = PLUGIN_AUTHOR,
	description = "Jailbreak Shop Plugin",
	version = PLUGIN_VERSION,
	url = ""
};

#define MAX_ITEM_HASH_NAME_LENGTH 32
#define MAX_ITEM_SHOP_NAME_LENGTH 64

#define TSHOP_ITEM_COUNT 21
#define CTSHOP_ITEM_COUNT 6

#define MESSAGE_INVISIBLE "You are invisible. %i seconds remaining"
#define MESSAGE_FASTWALK "You can now move faster. %i seconds remaining"
#define MESSAGE_BLIND "All guards are blind. %i seconds remaining"

#define PATH_TMODEL "models/player/custom_player/legacy/tm_phoenix_varianta.mdl"
#define PATH_CTMODEL "models/player/custom_player/legacy/ctm_sas_varianta.mdl"

#define POINTS_NEW_ROUND_NORMAL 10
#define POINTS_NEW_ROUND_VIP 12
#define POINTS_NEW_ROUND_EVIP 15
#define POINTS_KILL_T_NORMAL 15
#define POINTS_KILL_T_VIP 18
#define POINTS_KILL_T_EVIP 20
#define POINTS_MIN_WARDEN_NORMAL 3
#define POINTS_MIN_WARDEN_VIP 4
#define POINTS_MIN_WARDEN_EVIP 5

#define TIME_FOR_SHOP 120.0

static int s_Points[MAXPLAYERS + 1] = 0;
static ArrayList s_BoughtWeapons;
static ArrayList s_NormalItems;
static ArrayList s_VipItems;
static ArrayList s_EVipItems;
static Handle s_ShopTimer = INVALID_HANDLE;
static bool s_ShopEnabled = true;

enum ItemVip
{
	IV_ALL,
	IV_VIP,
	IV_EVIP
}

enum struct ShopItem
{
	char hashName[MAX_ITEM_HASH_NAME_LENGTH];
	char shopName[MAX_ITEM_SHOP_NAME_LENGTH];
	int price;
	ItemVip vipOnly;
	int length;
	bool allowed[MAXPLAYERS + 1];
	
	void ResetAllowed()
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			this.allowed[i] = true;
		}
	}
	
	void Create(const char[] hashName_t, const char[] shopName_t, int price_t, ItemVip vipOnly_t, int length_t = 0)
	{
		this.ResetAllowed();
		
		strcopy(this.hashName, MAX_ITEM_HASH_NAME_LENGTH, hashName_t);
		strcopy(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, shopName_t);
		
		char buffer[10];
		
		if (this.length > 0.0)
		{
			FormatEx(buffer, sizeof(buffer), "%i", this.length);
			StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, " /");
			StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, buffer);
			StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, " seconds /");
		}
		
		IntToString(price_t, buffer, sizeof(buffer));
		StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, " [");
		StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, buffer);
		StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, "]");
		
		if (vipOnly_t == IV_VIP)
		{
			StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, " ( VIP )");
		}
		else if (vipOnly_t == IV_EVIP)
		{
			StrCat(this.shopName, MAX_ITEM_SHOP_NAME_LENGTH, " ( ExtraVIP )");
		}
		
		this.price = price_t;
		this.vipOnly = vipOnly_t;
		this.length = length_t;
	}
	
	bool CanUse(int client, bool notify = true)
	{
		if (s_Points[client] < this.price)
		{
			if (notify)
				NotifyPlayerHud(client, "Sorry, you don't have enough points for this item");
			return false;
		}
		if (this.vipOnly == IV_VIP && !IsClientVip(client))
		{
			if (notify)
				NotifyPlayerHud(client, "Sorry, you need to be VIP to get this item");
			return false;
		}
		if (this.vipOnly == IV_EVIP && !IsClientExtraVip(client))
		{
			if (notify)
				NotifyPlayerHud(client, "Sorry, you need to be ExtraVIP to get this item");
			return false;
		}
		if (!this.allowed[client])
			return false;
		
		return true;
	}
	
	void Use(int client, bool subPoints = true)
	{
		if (subPoints)
			s_Points[client] -= this.price;

		if (!strcmp(this.hashName, "hammer"))
		{
			int weapon = GivePlayerItem(client, "weapon_hammer");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Kladivo");
			NotifyTeamChat(client, "[URNA Shop] Player %N bought Hammer", client);
		}
		else if (!strcmp(this.hashName, "spanner"))
		{
			int weapon = GivePlayerItem(client, "weapon_spanner");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Kľúč");
			NotifyTeamChat(client, "[URNA Shop] Player %N bought Spanner", client);
		}
		else if (!strcmp(this.hashName, "axe"))
		{
			int weapon = GivePlayerItem(client, "weapon_axe");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Sekeru");
			NotifyTeamChat(client, "[URNA Shop] Player %N bought Axe", client);
		}
		else if (!strcmp(this.hashName, "knife"))
		{
			int weapon = GivePlayerItem(client, "weapon_knife");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Nôž");
			NotifyTeamChat(client, "[URNA Shop] Player %N bought Knife", client);
		}
		else if (!strcmp(this.hashName, "taser"))
		{
			int weapon = GivePlayerItem(client, "weapon_taser");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Taser - Zeus");
			NotifyTeamChat(client, "[URNA Shop] Player %N bought Taser - Zeus", client);
		}
		else if (!strcmp(this.hashName, "healthshot"))
		{
			int weapon = GivePlayerItem(client, "weapon_healthshot");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Adrenalín");
			NotifyTeamChat(client, "[URNA Shop] Player %N bought Healthshot", client);
		}
		else if (!strcmp(this.hashName, "kevlar"))
		{
			SetPlayerArmor(client, 100);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Vestu");
			NotifyTeamChat(client, "[URNA Shop] Player %N bought Kevlar", client);
		}
		else if (!strcmp(this.hashName, "helmet"))
		{
			SetPlayerHelmet(client, true);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Helmu");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Helmet", client);
		}
		else if (!strcmp(this.hashName, "kevlarhelmet"))
		{
			SetPlayerArmor(client, 100);
			SetPlayerHelmet(client, true);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Vestu + Helmu");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Kevlar + Helmet", client);
		}
		else if (!strcmp(this.hashName, "hegrenade"))
		{
			int weapon = GivePlayerItem(client, "weapon_hegrenade");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Granát");
			NotifyTeamChat(client, "[URNA Shop] Player %N got HE Grenade", client);
		}
		else if (!strcmp(this.hashName, "flashbang"))
		{
			int weapon = GivePlayerItem(client, "weapon_flashbang");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Flash");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Flashbang", client);
		}
		else if (!strcmp(this.hashName, "smoke"))
		{
			int weapon = GivePlayerItem(client, "weapon_smokegrenade");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Smoke");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Smoke", client);
		}
		else if (!strcmp(this.hashName, "molotov"))
		{
			int weapon = GivePlayerItem(client, "weapon_molotov");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Molotov");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Molotov", client);
		}
		else if (!strcmp(this.hashName, "tagrenade"))
		{
			int weapon = GivePlayerItem(client, "weapon_tagrenade");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Taktický Granát");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Tactical Awareness Grenade", client);
		}
		else if (!strcmp(this.hashName, "breachcharge"))
		{
			int weapon = GivePlayerItem(client, "weapon_breachcharge");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Výbušniny");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Breach charge", client);
		}
		else if (!strcmp(this.hashName, "shield"))
		{
			int weapon = GivePlayerItem(client, "weapon_shield");
			s_BoughtWeapons.Push(weapon);
			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Štít");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Shield", client);
		}
		else if (!strcmp(this.hashName, "heavy"))
		{
			int weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
			if (IsValidEntity(weapon))
			{
				RemovePlayerItem(client, weapon);
				RemoveEdict(weapon);
			}

			weapon = GivePlayerItem(client, "item_heavyassaultsuit");
			s_BoughtWeapons.Push(weapon);

			this.allowed[client] = false;
			
			NotifyPlayerHud(client, "Máš Ťažkoodeneckú Výzbroj");
			NotifyTeamChat(client, "[URNA Shop] Player %N got Heavy Assault Suit", client);
		}
		else if (!strcmp(this.hashName, "djump"))
		{
			EnableDoubleJump(client, true);
			
			NotifyPlayerHud(client, "Máš Double Jump");
			NotifyTeamChat(client, "[URNA Shop] Player %N now has Double Jump", client);
		}
		else if (!strcmp(this.hashName, "fastwalk"))
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.5);
			Handle kv = CreateKeyValues("data");
			KvSetNum(kv, "client", client);
			KvSetNum(kv, "time", this.length - 1);
			char message[256];
			Format(message, sizeof(message), MESSAGE_FASTWALK, this.length);
			NotifyPlayerHud(client, message);
			CreateTimer(1.0, TimerCallbackFastWalk, kv, TIMER_REPEAT);
			
			NotifyTeamChat(client, "[URNA Shop] Player %N can move faster now", client);
		}
		else if (!strcmp(this.hashName, "invisibility"))
		{
			SetPlayerInvisible(client);
			Handle kv = CreateKeyValues("data");
			KvSetNum(kv, "client", client);
			KvSetNum(kv, "time", this.length - 1);
			char message[256];
			Format(message, sizeof(message), MESSAGE_INVISIBLE, this.length);
			NotifyPlayerHud(client, message);
			CreateTimer(1.0, TimerCallbackInvisibility, kv, TIMER_REPEAT);
			
			NotifyTeamChat(client, "[URNA Shop] Player %N is now invisible", client);
		}
		else if (!strcmp(this.hashName, "changeskin"))
		{
			SetPlayerModel(client, 0);
			NotifyPlayerHud(client, "You look like GUARD now!");
			int weapon = GivePlayerItem(client, "weapon_m4a1_silencer");
			SetPlayerAmmo(client, weapon, 0);
			SetPlayerMagAmmo(weapon, 1);
			
			NotifyTeamChat(client, "[URNA Shop] Player %N looks like guard now", client);
		}
		else if (!strcmp(this.hashName, "blind"))
		{
			char message[256];
			Format(message, sizeof(message), MESSAGE_BLIND, this.length);
			NotifyPlayerHud(client, message);
			NotifyTeamChat(client, "[URNA Shop] All guards are blind!", client);
			for (int i = 1; i <= MaxClients; ++i)
				if (IsClientValid(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
					ServerCommand("sm_blind #%i 1000", GetClientUserId(i));
			
			Handle kv = CreateKeyValues("data");
			KvSetNum(kv, "client", client);
			KvSetNum(kv, "time", this.length - 1);
			CreateTimer(1.0, TimerCallbackBlind, kv, TIMER_REPEAT);
		}
		else if (!strcmp(this.hashName, "open"))
		{
			int maxBound = 0;
			if (IsClientVip(client))
				maxBound = 4;
			else if (IsClientExtraVip(client))
				maxBound = 2;
			
			if (GetRandomInt(1, maxBound) == 1)
			{
				OpenDoors();
				NotifyPlayerHud(client, "Podarilo sa ti otvoriť cely");
				NotifyTeamChat(client, "%N have successfully opened cells doors", client);
			}
			else
			{
				NotifyPlayerHud(client, "Tentokrát to nevyšlo :(");
			}
			
			this.allowed[client] = false;
		}
		else if (!strcmp(this.hashName, "fortune"))
		{
			int clients[1];
			clients[0] = client;
			EmitSound(clients, 1, "music/urna_jailbreak/wheelOfFortune.mp3", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.1);
			CreateTimer(5.0, TimerCallbackFortune, client);
		}
	}
}

static Menu s_MenuMainT = null;
static Menu s_MenuMainCt = null;

static ShopItem s_ShopItemT[TSHOP_ITEM_COUNT];
static ShopItem s_ShopItemCt[CTSHOP_ITEM_COUNT];

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int err_max)
{
	CreateNative("OnWardenMinute", __OnWardenMinute);
	CreateNative("AddPointsForFrag", __AddPointsForFrag);

	RegPluginLibrary("jb_menu.inc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("jb_menu.phrases");
	
	HookEvent("player_death", OnPlayerDeathPost, EventHookMode_Post);
	HookEvent("round_start", OnRoundStart, EventHookMode_Post);
	HookEvent("round_end", OnRoundEnd, EventHookMode_Post);
	
	RegConsoleCmd("sm_menu", CMDMenu, "Menu for guards/prisoners");
	RegConsoleCmd("sm_shop", CMDShop, "Shop for guards/prisoners");
	RegAdminCmd("sm_setpoints", CMDSetPoints, ADMFLAG_CHEATS, "Set player points");
	// TODO: sm_getpoints
	
	s_ShopItemT[0].Create("spanner", "Wrench", 10, IV_ALL);
	s_ShopItemT[1].Create("hammer", "Hammer", 12, IV_ALL);
	s_ShopItemT[2].Create("axe", "Axe", 15, IV_ALL);
	s_ShopItemT[3].Create("knife", "Knife", 20, IV_ALL);
	s_ShopItemT[4].Create("taser", "Taser", 50, IV_VIP);
	s_ShopItemT[5].Create("healthshot", "Healthshot", 30, IV_ALL);
	s_ShopItemT[6].Create("hegrenade", "Grenade", 15, IV_ALL);
	s_ShopItemT[7].Create("flashbang", "Flashbang", 12, IV_ALL);
	s_ShopItemT[8].Create("smoke", "Smoke", 12, IV_ALL);
	s_ShopItemT[9].Create("molotov", "Molotov", 10, IV_ALL);
	s_ShopItemT[10].Create("tagrenade", "TacticalAwarnessGrenade", 12, IV_ALL);
	s_ShopItemT[11].Create("kevlar", "Kevlar", 20, IV_ALL);
	s_ShopItemT[12].Create("kevlarhelmet", "Kevlar+Helmet", 40, IV_ALL);
	s_ShopItemT[13].Create("breachcharge", "Breachcharge", 100, IV_EVIP);
	s_ShopItemT[14].Create("djump", "DoubleJump", 50, IV_ALL);
	s_ShopItemT[15].Create("fastwalk", "FastWalk", 60, IV_ALL, 5);
	s_ShopItemT[16].Create("invisibility", "Invisibility", 80, IV_ALL, 5);
	s_ShopItemT[17].Create("changeskin", "GuardSuit", 100, IV_ALL);
	s_ShopItemT[18].Create("blind", "BlindGuards", 120, IV_VIP, 10);
	s_ShopItemT[19].Create("open", "OpenCellDoors", 70, IV_VIP);
	s_ShopItemT[20].Create("fortune", "WheelofFortune", 60, IV_ALL);
	
	s_NormalItems = new ArrayList();
	s_VipItems = new ArrayList();
	s_EVipItems = new ArrayList();
	for (int i = 0; i < TSHOP_ITEM_COUNT; ++i)
	{
		if (s_ShopItemT[i].vipOnly == IV_ALL)
			s_NormalItems.Push(i);
		else if (s_ShopItemT[i].vipOnly == IV_VIP)
			s_VipItems.Push(i);
		else if (s_ShopItemT[i].vipOnly == IV_EVIP)
			s_EVipItems.Push(i);
	}
	
	s_MenuMainT = CreateMainMenuT();
	s_MenuMainCt = CreateMainMenuCt();
	
	s_ShopItemCt[0].Create("helmet", "Helmet", 20, IV_ALL);
	s_ShopItemCt[1].Create("tagrenade", "TacticalAwarnessGrenade", 20, IV_ALL);
	s_ShopItemCt[2].Create("healthshot", "Healthshot", 30, IV_ALL);
	s_ShopItemCt[3].Create("djump", "DoubleJump", 30, IV_ALL);
	s_ShopItemCt[4].Create("shield", "Shield", 50, IV_VIP);
	s_ShopItemCt[5].Create("heavy", "HeavyAssaultSuit", 70, IV_EVIP);
	
	s_BoughtWeapons = new ArrayList();
	
	for (int i = 1; i <= MaxClients; ++i)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

void RemoveBoughtWeapons()
{
	for (int i = 0; i < s_BoughtWeapons.Length; ++i)
	{
		int weapon = s_BoughtWeapons.Get(i);
		if (!IsValidEntity(weapon))
			continue;

		int owner = GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity");
		if (IsClientValid(owner) && IsPlayerAlive(owner))
		{
			RemovePlayerItem(owner, weapon);
		}
		
		RemoveEdict(weapon);
	}
	
	s_BoughtWeapons.Clear();
}

public void OnMapStart()
{
	PrecacheModel(PATH_TMODEL);
	PrecacheModel(PATH_CTMODEL);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_SpawnPost, OnPlayerSpawnPost);

	s_Points[client] = 0;

	RedrawPointsHud(client);
}

public Action OnPlayerDeathPost(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (victim == attacker || attacker == 0 || !IsClientValid(victim) || !IsClientValid(attacker))
		return Plugin_Continue;
	
	// Add point for frag
	if (GetClientTeam(attacker) == CS_TEAM_T)
	{
		int plusPoints = POINTS_KILL_T_NORMAL;
		if (IsClientExtraVip(attacker))
			plusPoints = POINTS_KILL_T_EVIP;
		else if (IsClientVip(attacker))
			plusPoints = POINTS_KILL_T_VIP;
		
		s_Points[attacker] += plusPoints;
		// NotifyPlayerPoints(attacker, "You got %i points for killing %N", plusPoints, victim);
	}
	
	RedrawPointsHud(attacker);
	return Plugin_Continue;
}

public Action OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	s_ShopTimer = CreateTimer(TIME_FOR_SHOP, TimerCallbackForShop);
	
	for (int i = 0; i < TSHOP_ITEM_COUNT; ++i)
	{
		s_ShopItemT[i].ResetAllowed();
	}
	for (int i = 0; i < CTSHOP_ITEM_COUNT; ++i)
	{
		s_ShopItemCt[i].ResetAllowed();
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		// Disable features from previous round
		EnableDoubleJump(i, false);
		// Add points
		if (IsClientValid(i))
		{
			int plusPoints = POINTS_NEW_ROUND_NORMAL;
			if (IsClientExtraVip(i))
				plusPoints = POINTS_NEW_ROUND_EVIP;
			else if (IsClientVip(i))
				plusPoints = POINTS_NEW_ROUND_VIP;
			
			s_Points[i] += plusPoints;
			// NotifyPlayerPoints(i, "You got %i points for new round!", plusPoints);
			RedrawPointsHud(i);
		}
	}
	
	s_BoughtWeapons.Clear();
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (s_ShopTimer != INVALID_HANDLE)
		KillTimer(s_ShopTimer);
	s_ShopEnabled = true;
}

public Action OnPlayerSpawnPost(int client)
{
	int team = GetClientTeam(client);
	ShowMenuToPlayer(client, team);
	RedrawPointsHud(client);
}

public Action CMDMenu(int client, int args)
{
	if (!IsClientValid(client))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[URNA Menu] Sorry, you can use this command only when you are alive");
		return Plugin_Handled;
	}
	
	ShowMenuToPlayer(client, GetClientTeam(client));
	return Plugin_Handled;
}

public Action CMDShop(int client, int args)
{
	if (!IsClientValid(client))
		return Plugin_Handled;
		
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[URNA Menu] Sorry, you can use this command only when you are alive");
		return Plugin_Handled;
	}
	
	if (!s_ShopEnabled)
	{
		ReplyToCommand(client, "[URNA SHOP] Shop has been disabled after 2 minutes");
		return Plugin_Handled;
	}
	
	if (GetClientTeam(client) == CS_TEAM_T)
	{
		Menu menu = CreateMenuShopT(client);
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else if (GetClientTeam(client) == CS_TEAM_CT)
	{
		Menu menu = CreateMenuShopCt(client);
		menu.Display(client, MENU_TIME_FOREVER);
	}
	
	return Plugin_Handled;
}

public Action CMDSetPoints(int client, int argc)
{
	if (argc != 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setpoints <target> <number of points>");
		return Plugin_Handled;
	}
	
	char buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	int targetList[MAXPLAYERS];
	char targetName[MAX_NAME_LENGTH];
	bool tn_is_ml;
	int targetCount = ProcessTargetString(buffer, client, targetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, MAX_NAME_LENGTH, tn_is_ml);
	if (targetCount <= 0)
	{
		ReplyToCommand(client, "[SM] No matching clients were found");
		return Plugin_Handled;
	}
	
	GetCmdArg(2, buffer, sizeof(buffer));
	int points = StringToInt(buffer, 10);
	if (points < 0)
		points = 0;
	
	for (int i = 0; i < targetCount; ++i)
	{
		s_Points[targetList[i]] = points;
		RedrawPointsHud(targetList[i]);
	}
	
	return Plugin_Handled;
}

void ShowMenuToPlayer(int client, int team)
{
	if (team == CS_TEAM_T)
	{
		s_MenuMainT.Display(client, MENU_TIME_FOREVER);
	}
	else if (team == CS_TEAM_CT)
	{
		s_MenuMainCt.Display(client, MENU_TIME_FOREVER);
	}
}

Menu CreateMainMenuT()
{
	Menu menu = new Menu(MenuCallbackMainT, MENU_ACTIONS_ALL);
	menu.SetTitle("Prisoner MENU (!menu)");
	menu.AddItem("shop", "Game Shop");
	menu.AddItem("model", "Choose Model\n-------------------");
	menu.AddItem("rules", "Rules");
	
	return menu;
}

Menu CreateMainMenuCt()
{
	Menu menu = new Menu(MenuCallbackMainCt, MENU_ACTIONS_ALL);
	menu.SetTitle("Guard MENU (!menu)");
	menu.AddItem("weapons", "Choose Weapons");
	menu.AddItem("shop", "Game Shop");
	menu.AddItem("model", "Choose Model\n-------------------");
	menu.AddItem("rules", "Rules");
	
	return menu;
}

Menu CreateMenuShopT(int client)
{
	Menu menu = new Menu(MenuCallbackShop, MENU_ACTIONS_ALL);
	menu.SetTitle("Prisoner Shop (!shop)");
	for (int i = 0; i < TSHOP_ITEM_COUNT; ++i)
	{
		char buffer[3];
		IntToString(i, buffer, sizeof(buffer));
		menu.AddItem(buffer, s_ShopItemT[i].shopName);
	}
	
	return menu;
}

Menu CreateMenuShopCt(int client)
{
	Menu menu = new Menu(MenuCallbackShop, MENU_ACTIONS_ALL);
	menu.SetTitle("Guard Shop (!shop)");
	for (int i = 0; i < CTSHOP_ITEM_COUNT; ++i)
	{
		char buffer[3];
		IntToString(i, buffer, sizeof(buffer));
		menu.AddItem(buffer, s_ShopItemCt[i].shopName);
	}
	
	return menu;
}

public int MenuCallbackMainT(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			char itemName[32];
			int style;
			menu.GetItem(param2, itemName, sizeof(itemName), style);
			if (StrEqual(itemName, "shop"))
				if (!s_ShopEnabled)
					return ITEMDRAW_DISABLED;
			
			return style;
		}
		case MenuAction_Select:
		{
			if (!IsClientValid(param1) || GetClientTeam(param1) != CS_TEAM_T)
				return 0;
			
			int team = GetClientTeam(param1);
			char itemName[32];
			menu.GetItem(param2, itemName, sizeof(itemName));
			if (StrEqual(itemName, "shop"))
			{
				if (team == CS_TEAM_T)
				{
					Menu newMenu = CreateMenuShopT(param1);
					newMenu.Display(param1, MENU_TIME_FOREVER);
				}
			}
			else if (StrEqual(itemName, "rules"))
			{
				char rules[256];
				GetRules(param1, rules, sizeof(rules));
				PrintToChat(param1, rules);
			}
			else if (StrEqual(itemName, "model"))
			{
				DisplayModelsMenu(param1);
			}
		}
	}
	
	return 0;
}

public int MenuCallbackMainCt(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			char itemName[32];
			int style;
			menu.GetItem(param2, itemName, sizeof(itemName), style);
			if (StrEqual(itemName, "shop"))
				if (!s_ShopEnabled)
					return ITEMDRAW_DISABLED;
			
			return style;
		}
		case MenuAction_Select:
		{
			int team = GetClientTeam(param1);
			char itemName[32];
			menu.GetItem(param2, itemName, sizeof(itemName));
			if (StrEqual(itemName, "shop"))
			{
				if (team == CS_TEAM_CT)
				{
					Menu newMenu = CreateMenuShopCt(param1);
					newMenu.Display(param1, MENU_TIME_FOREVER);
				}
			}
			else if (StrEqual(itemName, "rules"))
			{
				char rules[256];
				GetRules(param1, rules, sizeof(rules));
				PrintToChat(param1, rules);
			}
			else if (StrEqual(itemName, "model"))
			{
				DisplayModelsMenu(param1);
			}
		}
	}
	
	return 0;
}

public int MenuCallbackShop(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DisplayItem:
		{
			char display[64];
			int style;
			menu.GetItem(param2, "", 0, style, display, sizeof(display));
			char buffers[10][64];
			int n = ExplodeString(display, " ", buffers, 10, 64);

			/*char buffer[255];
			Format(buffer, sizeof(buffer), "%T", buffers[0], param1);
			for (int i = 1; i < n; ++i)
			{
				StrCat(buffer, sizeof(buffer), " ");
				StrCat(buffer, sizeof(buffer), buffers[i]);
			}*/
			
			return RedrawMenuItem(display);
		}
		case MenuAction_DrawItem:
	    {
			int style;
			char info[3];
			menu.GetItem(param2, info, sizeof(info), style);
			int index = StringToInt(info, 10);
			if (GetClientTeam(param1) == CS_TEAM_T)
			{
				if (!s_ShopItemT[index].CanUse(param1, false))
				{
					return ITEMDRAW_DISABLED;
				}
				else
				{
					return style;
				}
			}
			else if (GetClientTeam(param1) == CS_TEAM_CT)
			{
				if (!s_ShopItemCt[index].CanUse(param1, false))
				{
					return ITEMDRAW_DISABLED;
				}
				else
				{
					return style;
				}
			}
	    }
		case MenuAction_Select:
		{
			char itemName[3];
			menu.GetItem(param2, itemName, sizeof(itemName));
			int index = StringToInt(itemName, 10);
			if (GetClientTeam(param1) == CS_TEAM_T)
			{
				if (!s_ShopItemT[index].CanUse(param1))
				{
					return 0;
				}
				s_ShopItemT[index].Use(param1);
			}
			else if (GetClientTeam(param1) == CS_TEAM_CT)
			{
				if (!s_ShopItemCt[index].CanUse(param1))
				{
					return 0;
				}
				s_ShopItemCt[index].Use(param1);
			}
			
			/*if (StrEqual(itemName, "hammer"))
			{
				GivePlayerItem(param1, "weapon_hammer");
				NotifyPlayerHud(param1, "You got Hammer");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "spanner"))
			{
				GivePlayerItem(param1, "weapon_spanner");
				NotifyPlayerHud(param1, "You got Wrench");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "axe"))
			{
				GivePlayerItem(param1, "weapon_axe");
				NotifyPlayerHud(param1, "You got Axe");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "knife"))
			{
				GivePlayerItem(param1, "weapon_knife");
				NotifyPlayerHud(param1, "You got Knife");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "taser"))
			{
				GivePlayerItem(param1, "weapon_taser");
				NotifyPlayerHud(param1, "You got Zeus");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "healthshot"))
			{
				GivePlayerItem(param1, "weapon_healthshot");
				NotifyPlayerHud(param1, "You got Healthshot");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "hegrenade"))
			{
				GivePlayerItem(param1, "weapon_hegrenade");
				NotifyPlayerHud(param1, "You got HE Grenade");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "flashbang"))
			{
				GivePlayerItem(param1, "weapon_flashbang");
				NotifyPlayerHud(param1, "You got Flashbang");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "smoke"))
			{
				GivePlayerItem(param1, "weapon_smokegrenade");
				NotifyPlayerHud(param1, "You got Smoke");
				NotifyPrisonerChat(param1, "Player %N got Hammer", param1);
			}
			else if (StrEqual(itemName, "molotov"))
			{
				GivePlayerItem(param1, "weapon_molotov");
				NotifyPlayerHud(param1, "You got Molotov");
				NotifyPrisonerChat(param1, "Player %N got Molotov", param1);
			}
			else if (StrEqual(itemName, "breachcharge"))
			{
				GivePlayerItem(param1, "weapon_breachcharge");
				NotifyPlayerHud(param1, "You got Breach Charge");
				NotifyPrisonerChat(param1, "Player %N got Breach Charge", param1);
			}*/
			
			RedrawPointsHud(param1);
		}
		case MenuAction_End:
			delete menu;
	}
	
	return 0;
}

public Action TimerCallbackForShop(Handle timer, any data)
{
	s_ShopEnabled = false;
	s_ShopTimer = INVALID_HANDLE;
}

public Action TimerCallbackFastWalk(Handle timer, Handle kv)
{
	int client = KvGetNum(kv, "client");
	int time = KvGetNum(kv, "time");
	if (time == 0)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
		NotifyPlayerHud(client, "You can no longer move fast!");
		CloseHandle(kv);
		KillTimer(timer);
	}
	else
	{
		char message[255];
		Format(message, sizeof(message), MESSAGE_FASTWALK, time);
		NotifyPlayerHud(client, message);
		KvSetNum(kv, "time", time - 1);
	}
}

public Action TimerCallbackInvisibility(Handle timer, Handle kv)
{
	int client = KvGetNum(kv, "client");
	int time = KvGetNum(kv, "time");
	if (time == 0)
	{
		SetPlayerVisible(client);
		NotifyPlayerHud(client, "You are visible now!");
		CloseHandle(kv);
		KillTimer(timer);
	}
	else
	{
		char message[255];
		Format(message, sizeof(message), MESSAGE_INVISIBLE, time);
		NotifyPlayerHud(client, message);
		KvSetNum(kv, "time", time - 1);
	}
}

public Action TimerCallbackBlind(Handle timer, Handle kv)
{
	int client = KvGetNum(kv, "client");
	int time = KvGetNum(kv, "time");
	if (time == 0)
	{
		for (int i = 1; i <= MaxClients; ++i)
			if (IsClientValid(i) && IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_CT)
				ServerCommand("sm_blind #%i 0", GetClientUserId(i));
				
		NotifyPlayerHud(client, "Guards can see now!");
		CloseHandle(kv);
		KillTimer(timer);
	}
	else
	{
		char message[255];
		Format(message, sizeof(message), MESSAGE_BLIND, time);
		NotifyPlayerHud(client, message);
		KvSetNum(kv, "time", time - 1);
	}
}

public Action TimerCallbackFortune(Handle timer, int client)
{
	if (IsClientValid(client) && IsPlayerAlive(client))
	{
		int maxBound = s_NormalItems.Length - 1;
		if (IsClientVip(client))
			maxBound += s_VipItems.Length;
		if (IsClientExtraVip(client))
			maxBound += s_EVipItems.Length;
		
		int random = GetRandomInt(0, maxBound);
		int itemIndex = 0;
		if (random < s_NormalItems.Length)
		{
			itemIndex = s_NormalItems.Get(random);
		}
		else if (random < s_NormalItems.Length + s_VipItems.Length)
		{
			itemIndex = s_VipItems.Get(random - s_NormalItems.Length);
		}
		else
		{
			itemIndex = s_EVipItems.Get(random - s_NormalItems.Length - s_VipItems.Length);
		}
		
		s_ShopItemT[itemIndex].Use(client, false);
	}
}

void RedrawPointsHud(int client)
{
	SetHudTextParams(-1.0, 0.92, 9999.0, 255, 255, 255, 255, 0);
	ShowHudText(client, 1, "Points: %d", s_Points[client]);
}

void NotifyPlayerHud(int client, const char[] format, any ...)
{
	char message[256];
	VFormat(message, sizeof(message), format, 3);
	SetHudTextParams(-1.0, 0.4, 5.0, 255, 255, 255, 255, 0, 1.0);
	ShowHudText(client, 2, message);
}

/*void NotifyPlayerPoints(int client, const char[] format, any ...)
{
	char message[256];
	VFormat(message, sizeof(message), format, 3);
	SetHudTextParams(-1.0, 0.6, 5.0, 255, 255, 255, 255, 0, 1.0);
	ShowHudText(client, 3, message);
}*/

void NotifyTeamChat(int client, const char[] format, any ...)
{
	int team = GetClientTeam(client);
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientValid(i) && GetClientTeam(i) == team && i != client && !IsFakeClient(client))
		{
			char message[256];
			VFormat(message, sizeof(message), format, 3);
			PrintToChat(i, message);
		}
	}
}

// bool OnWardenMinute(int client);
public int __OnWardenMinute(Handle plugin, int argc)
{
	int client = GetNativeCell(1);
	if (IsClientValid(client))
	{
		int plusPoints = POINTS_MIN_WARDEN_NORMAL;
		if (IsClientExtraVip(client))
			plusPoints = POINTS_MIN_WARDEN_EVIP;
		else if (IsClientVip(client))
			plusPoints = POINTS_MIN_WARDEN_VIP;
		
		s_Points[client] += plusPoints;
		// NotifyPlayerPoints(client, "You got %i points for being warden for 1 minute", plusPoints);
		RedrawPointsHud(client);
	}
}

// void AddPoints(int victim, int attacker);
public int __AddPointsForFrag(Handle plugin, int argc)
{
	int victim = GetNativeCell(1);
	int attacker = GetNativeCell(2);
	if (IsClientValid(victim) && IsClientValid(attacker) && GetClientTeam(attacker) == CS_TEAM_T && GetClientTeam(victim) == CS_TEAM_CT)
	{
		int plusPoints = POINTS_KILL_T_NORMAL;
		if (IsClientExtraVip(attacker))
			plusPoints = POINTS_KILL_T_EVIP;
		else if (IsClientVip(attacker))
			plusPoints = POINTS_KILL_T_VIP;
		
		s_Points[attacker] += plusPoints;
		// NotifyPlayerPoints(attacker, "You got %i points for killing %N", plusPoints, victim);
		RedrawPointsHud(attacker);
	}
}
