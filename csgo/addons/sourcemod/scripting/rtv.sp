#pragma semicolon 1

#define RELEASE

#define PLUGIN_AUTHOR "martbelko"
#define PLUGIN_VERSION "0.01"

#include <sdktools>
#include <sourcemod>
#include <clientprefs>
#include <smlib/strings>

#include <jb_core>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "RTV Plugin",
	author = PLUGIN_AUTHOR,
	description = "RTV Plugin",
	version = PLUGIN_VERSION,
	url = ""
};

#define MAX_LINE_LEN 64
#define MIN_MAP_DELAY 3 // How many other maps should be player before the same map can be selected again
#define s_NeededVotesPercentage 0.6
#define s_InitialDelay 120.0 // Seconds
#define s_RunOffPercentage 0.5
#define s_MaxMapTime 45 // How many minutes can map be played before an automatic RTV
#define s_ExtendTime 15 // Minutes

enum RTVStatus
{
	RTV_NOT_ALLOWED = 0,
	RTV_ALLOWED,
	RTV_IN_VOTE,
	RTV_VOTE_FINISHED,
	RTV_IN_CHANGE
}

enum struct Map
{
	char name[PLATFORM_MAX_PATH];
	
	void Create(const char[] name_t)
	{
		strcopy(this.name, PLATFORM_MAX_PATH, name_t);
	}
}

static int s_Voters = 0;				// Total voters connected. Doesn't include fake clients.
static int s_Votes = 0;				    // Total number of "say rtv" votes
static int s_VotesNeeded = 0;			// Necessary votes before map vote begins. (voters * percent_needed)
static bool s_Voted[MAXPLAYERS + 1] = {false, ...};
static RTVStatus s_RTVStatus = RTV_NOT_ALLOWED; // Current status of RTV

static ArrayList s_Maps; // All maps in maps.ini
static int s_LatestMapsIndices[MIN_MAP_DELAY] = {-1, ...}; // Latest maps that were played

static char s_MapFilepath[256]; // BuildPath output

static int s_NextMapIndex = -1; // Next map index in 's_Maps' chosen by RTV

static Menu s_RTVMenu = null; // Menu for RTV

static int s_TimeMapStart = 0; // Time (in seconds), when the current map started

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("rockthevote.phrases");
	
	RegConsoleCmd("sm_rtv", CMDRTV, "Rock The Vote");
	RegConsoleCmd("sm_rockthevote", CMDRTV, "Rock The Vote");
	RegConsoleCmd("sm_testrtv", CMDTestRtv);
	
	RegConsoleCmd("sm_nextmap", CMDNextMap, "NextMap");
	RegConsoleCmd("nextmap", CMDNextMap, "NextMap");
	
	RegConsoleCmd("sm_timeleft", CMDTimeLeft, "Time Left");
	RegConsoleCmd("timeleft", CMDTimeLeft, "Time Left");
	
	RegAdminCmd("sm_fakecmd", CMDFakeCmd, ADMFLAG_GENERIC); // TODO: Temporary, move to another file
	
	HookEvent("round_start", OnRoundStartPost, EventHookMode_Post);
	
	s_Maps = new ArrayList(sizeof(Map));
	
	BuildPath(Path_SM, s_MapFilepath, sizeof(s_MapFilepath), "configs/maps.ini");
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i))
			OnClientConnected(i);
}

public Action CMDFakeCmd(int client, int argc)
{
	if (argc != 2)
	{
		ReplyToCommand(client, "Error");
		return Plugin_Handled;
	}
	
	char victimStr[MAX_NAME_LENGTH];
	GetCmdArg(1, victimStr, sizeof(victimStr));
	char command[128];
	GetCmdArg(2, command, sizeof(command));
	
	int targetList[MAXPLAYERS];
	char targetName[MAX_NAME_LENGTH];
	bool tn_is_ml;
	int targetCount = ProcessTargetString(victimStr, client, targetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, MAX_NAME_LENGTH, tn_is_ml);
	if (targetCount <= 0)
	{
		ReplyToCommand(client, "[URNA] No matching clients were found");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < targetCount; ++i)
	{
		FakeClientCommand(targetList[i], "%s", command);
	}
	
	return Plugin_Handled;
}

public void OnClientConnected(int client)
{
	if (!IsFakeClient(client) && !IsClientSourceTV(client))
	{
		++s_Voters;
		s_VotesNeeded = RoundToCeil(float(s_Voters) * s_NeededVotesPercentage);
	}
}

public void OnClientDisconnect(int client)
{
	if (s_RTVStatus == RTV_VOTE_FINISHED || s_RTVStatus == RTV_IN_CHANGE)
		return;
	
	if (s_Voted[client])
	{
		--s_Votes;
		s_Voted[client] = false;
	}
	
	if (!IsFakeClient(client) && !IsClientSourceTV(client))
	{
		--s_Voters;
		s_VotesNeeded = RoundToCeil(float(s_Voters) * s_NeededVotesPercentage);
	}
	
	if (s_Votes && s_Voters && s_Votes >= s_VotesNeeded && s_RTVStatus == RTV_ALLOWED) 
	{
		StartRTV(true);
	}
}

ArrayList LoadMapsFile(const char[] path)
{
	// TODO: Add check if file exists, if not set fail state
	ArrayList result = new ArrayList(sizeof(Map));
	Handle file = OpenFile(path, "r");
	char line[MAX_LINE_LEN];
	while (ReadFileLine(file, line, sizeof(line)))
	{
		String_Trim(line, line, sizeof(line));
		if (strlen(line) == 0)
			continue;
		if (String_StartsWith(line, "//"))
			continue;
		
		Map map;
		map.Create(line);
		result.PushArray(map);
	}

	CloseHandle(file);
	return result;
}

public void OnMapStart()
{
	CreateTimer(s_InitialDelay, TimerCallbackEnableRTV, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(s_MaxMapTime * 60.0, TimerCallbackAutomaticRTV, true, TIMER_FLAG_NO_MAPCHANGE);
	s_TimeMapStart = GetTime();
	
	ArrayList maps = LoadMapsFile(s_MapFilepath);
	
	// Find out if the file was changed
	if (s_Maps.Length != maps.Length)
	{
		s_Maps.Clear();
		s_Maps = maps;
	}
	else
	{
		for (int i = 0; i < maps.Length; ++i)
		{
			Map map1, map2;
			maps.GetArray(i, map1);
			s_Maps.GetArray(i, map2);
			if (!StrEqual(map1.name, map2.name))
			{
				s_Maps.Clear();
				s_Maps = maps;
			}
		}
	}
	
	char curMap[PLATFORM_MAX_PATH];
	GetCurrentMap(curMap, sizeof(curMap));
	for (int i = 0; i < s_Maps.Length; ++i)
	{
		Map map;
		s_Maps.GetArray(i, map);
		if (StrEqual(map.name, curMap))
		{
			if (s_NextMapIndex != i)
			{
				InsertLastMapIndex(i);
				break;
			}
		}
	}
	
	s_NextMapIndex = -1;
}

void InsertLastMapIndex(int index)
{
	for (int i = 0; i < MIN_MAP_DELAY - 1; ++i)
		s_LatestMapsIndices[i + 1] = s_LatestMapsIndices[i];
		
	s_LatestMapsIndices[0] = index;
}

public void OnMapEnd()
{
	InsertLastMapIndex(s_NextMapIndex);
}

public Action OnRoundStartPost(Handle event, const char[] name, bool dontBroadcast)
{
	if (s_NextMapIndex >= 0)
	{
		Map map;
		s_Maps.GetArray(s_NextMapIndex, map);
		ServerCommand("changelevel %s", map.name);
	}
}

public Action CMDRTV(int client, int argc)
{
	AttemptRTV(client);
	return Plugin_Handled;
}

public Action CMDTestRtv(int client, int argc)
{
	ReplyToCommand(client, "%i, %i", s_Voters, s_VotesNeeded);
	return Plugin_Handled;
}

public Action CMDNextMap(int client, int argc)
{
	ShowNextMap(client);
	return Plugin_Handled;
}

public Action CMDTimeLeft(int client, int argc)
{
	ShowTimeLeft(client);
	return Plugin_Handled;
}

void ShowTimeLeft(int client)
{
	int timeLeft = GetTime() - s_TimeMapStart;
	ReplyToCommand(client, "%i", timeLeft);
}

void ShowNextMap(int client)
{
	if (s_RTVStatus == RTV_NOT_ALLOWED)
	{
		ReplyToCommand(client, "[URNA RTV] Hlasovanie o ďalšiu mapu ešte neprebehlo. Napíš rtv pre spustenie hlasovania o ďalšiu mapu");
		return;
	}
		
	if (s_RTVStatus == RTV_IN_VOTE)
	{
		ReplyToCommand(client, "[URNA RTV] Práve sa hlasuje");
		return;
	}
	
	if (s_NextMapIndex != -1)
	{
		Map map;
		s_Maps.GetArray(s_NextMapIndex, map);
		ReplyToCommand(client, "[URNA RTV] Ďalšia mapa bude %s", map.name);
	}
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!IsClientValid(client) || IsChatTrigger())
		return;
	
	if (StrEqual(sArgs, "rtv", false) || StrEqual(sArgs, "rockthevote", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
		AttemptRTV(client);
		SetCmdReplySource(old);
	}
	else if (StrEqual(sArgs, "nextmap", false))
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);
		ShowNextMap(client);
		SetCmdReplySource(old);
	}
}

void AttemptRTV(int client)
{
	if (s_RTVStatus == RTV_NOT_ALLOWED)
	{
		ReplyToCommand(client, "[URNA RTV] %t", "RTV Not Allowed");
		return;
	}
		
	if (s_RTVStatus == RTV_IN_VOTE)
	{
		ReplyToCommand(client, "[URNA RTV] %t", "RTV Started");
		return;
	}
	
	if (s_RTVStatus == RTV_VOTE_FINISHED)
	{
		ReplyToCommand(client, "[URNA RTV] RTV Vote finished");
		return;
	}
	
	if (s_RTVStatus == RTV_IN_CHANGE)
	{
		ReplyToCommand(client, "[URNA RTV] Changing map");
		return;
	}
	
	if (s_Voted[client])
	{
		ReplyToCommand(client, "[URNA RTV] %t", "Already Voted", s_Votes, s_VotesNeeded);
		return;
	}
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	
	s_Votes++;
	s_Voted[client] = true;
	
	PrintToChatAll("[URNA RTV] %t", "RTV Requested", name, s_Votes, s_VotesNeeded);
	
	if (s_Votes >= s_VotesNeeded)
		StartRTV(true);
}

bool IsMapIndexAvailable(int index)
{
	for (int i = 0; i < MIN_MAP_DELAY; ++i)
	{
		if (index == s_LatestMapsIndices[i])
			return false;
	}
	
	return true;
}

ArrayList GetAvailableMapsIndices()
{
	ArrayList mapsIndices = new ArrayList();
	for (int i = 0; i < s_Maps.Length; ++i)
	{
		if (IsMapIndexAvailable(i))
			mapsIndices.Push(i);
	}
	
	return mapsIndices;
}

void Shuffle(ArrayList arr)
{
	int lastIndex = arr.Length - 1;
	while (lastIndex > 0)
	{
		int randIndex = GetRandomInt(0, lastIndex);
		int temp = arr.Get(lastIndex);
		arr.Set(lastIndex, arr.Get(randIndex));
		arr.Set(randIndex, temp);
		--lastIndex;
	}
}

void StartRTV(bool allowExtend)
{
	if (s_RTVStatus == RTV_IN_CHANGE)
		return;

	s_RTVStatus = RTV_IN_VOTE;
	if (IsVoteInProgress())
	{
		CreateTimer(5.0, TimerCallbackTryRTV, allowExtend, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}
	
	s_RTVMenu = CreateMenu(MenuCallbackRTV, MENU_ACTIONS_ALL);
	s_RTVMenu.SetTitle("Hlasovanie za nasledujúcu mapu");
	ArrayList availableMaps = GetAvailableMapsIndices();
	Shuffle(availableMaps);
	
	int mapCount = availableMaps.Length > 5 ? 5 : availableMaps.Length;
	for (int i = 0; i < mapCount; ++i)
	{
		int index = availableMaps.Get(i);
		Map map;
		s_Maps.GetArray(index, map);
		char indexStr[5];
		IntToString(index, indexStr, sizeof(indexStr));
		s_RTVMenu.AddItem(indexStr, map.name);
	}
	
	if (allowExtend)
		s_RTVMenu.AddItem("extend", "Predĺžiť túto mapu");

	s_RTVMenu.VoteResultCallback = MenuCallbackRTVResult;
	s_RTVMenu.ExitButton = false;
	s_RTVMenu.DisplayVoteToAll(20);
}

public void MenuCallbackRTVResult(Menu menu, int numVotes, int numClients, const int[][] clientInfo, int numItems, const int[][] itemInfo)
{
	float winVotes = float(itemInfo[0][VOTEINFO_ITEM_VOTES]);
	float requiredVotes = numVotes * s_RunOffPercentage;
	
	if (winVotes < requiredVotes)
	{
		s_RTVMenu = CreateMenu(MenuCallbackRTV, MENU_ACTIONS_ALL);
		s_RTVMenu.SetTitle("Rozstrel");
		s_RTVMenu.VoteResultCallback = MenuCallbackRTVResult;

		char mapIndexStr[10];
		char info1[PLATFORM_MAX_PATH];
		char info2[PLATFORM_MAX_PATH];
		
		menu.GetItem(itemInfo[0][VOTEINFO_ITEM_INDEX], mapIndexStr, sizeof(mapIndexStr), _, info1, sizeof(info1));
		s_RTVMenu.AddItem(mapIndexStr, info1);
		menu.GetItem(itemInfo[1][VOTEINFO_ITEM_INDEX], mapIndexStr, sizeof(mapIndexStr), _, info2, sizeof(info2));
		s_RTVMenu.AddItem(mapIndexStr, info2);
		
		s_RTVMenu.ExitButton = false;
		s_RTVMenu.DisplayVoteToAll(20);
		
		/* Notify */
		float map1percent = float(itemInfo[0][VOTEINFO_ITEM_VOTES]) / float(numVotes) * 100;
		float map2percent = float(itemInfo[1][VOTEINFO_ITEM_VOTES]) / float(numVotes) * 100;
		
		PrintToChatAll("[URNA] Začínam rozstrel", s_RunOffPercentage * 100.0, info1, map1percent, info2, map2percent);
		LogMessage("Voting for next map was indecisive, beginning runoff vote");
	}
	else
	{
		int winner = 0;
		if (numItems > 1 && (itemInfo[0][VOTEINFO_ITEM_VOTES] == itemInfo[1][VOTEINFO_ITEM_VOTES]))
			winner = GetRandomInt(0, 1);
	
		char indexStr[10];
		menu.GetItem(itemInfo[winner][VOTEINFO_ITEM_INDEX], indexStr, sizeof(indexStr));
		if (StrEqual(indexStr, "extend"))
		{
			PrintToChatAll("[URNA] This map will be extended");
			CreateTimer(s_ExtendTime * 60.0, TimerCallbackExtendRTV, false, TIMER_FLAG_NO_MAPCHANGE);
			s_RTVStatus = RTV_VOTE_FINISHED;
			return;
		}
		
		int index = StringToInt(indexStr, 10);
		Map map;
		s_Maps.GetArray(index, map);
		int winVotesInt = RoundToFloor(winVotes);
		PrintToChatAll("[URNA] The next map will be %s (dostala %i [%i %%] z %i)", map.name, winVotesInt, RoundToFloor(winVotes / float(numVotes) * 100), numVotes);
		s_NextMapIndex = index;
	}
}

public int MenuCallbackRTV(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
    {
        delete menu;
    }
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		PrintToChatAll("[URNA] %t", "No Votes Cast");
		s_RTVStatus = RTV_ALLOWED;
	}
}

public Action TimerCallbackTryRTV(Handle timer, bool allowExtend)
{
	StartRTV(allowExtend);
}

public Action TimerCallbackEnableRTV(Handle timer, int unused)
{
	s_RTVStatus = RTV_ALLOWED;
	PrintToChatAll(" \x06 [URNA RTV] RTV je odteraz dostupné");
	return Plugin_Handled;
}

public Action TimerCallbackAutomaticRTV(Handle timer, bool allowExtend)
{
	if (s_RTVStatus == RTV_ALLOWED)
		StartRTV(allowExtend);
}

public Action TimerCallbackExtendRTV(Handle timer, bool allowExtend)
{
	StartRTV(allowExtend);
}
