#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Basic Info Triggers",
	author = "Martin Belko",
	description = "Adds thetime and others.",
	version = "0.01",
	url = ""
};

ConVar g_Cvar_TriggerShow;
ConVar g_Cvar_TimeleftInterval;
ConVar g_Cvar_FriendlyFire;

Handle g_Timer_TimeShow = null;

ConVar g_Cvar_WinLimit;
ConVar g_Cvar_FragLimit;
ConVar g_Cvar_MaxRounds;

#define TIMELEFT_ALL_ALWAYS		0		/* Print to all players */
#define TIMELEFT_ALL_MAYBE		1		/* Print to all players if sm_trigger_show allows */
#define TIMELEFT_ONE			2		/* Print to a single player */

int g_TotalRounds;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basetriggers.phrases");
	
	g_Cvar_TriggerShow = CreateConVar("sm_trigger_show", "0", "Display triggers message to all players? (0 off, 1 on, def. 0)", 0, true, 0.0, true, 1.0);	
	g_Cvar_TimeleftInterval = CreateConVar("sm_timeleft_interval", "0.0", "Display timeleft every x seconds. Default 0.", 0, true, 0.0, true, 1800.0);
	g_Cvar_FriendlyFire = FindConVar("mp_friendlyfire");
	
	RegConsoleCmd("motd", Command_Motd);
	RegConsoleCmd("ff", Command_FriendlyFire);
	
	g_Cvar_TimeleftInterval.AddChangeHook(ConVarChange_TimeleftInterval);

	char folder[64];   	 
	GetGameFolderName(folder, sizeof(folder));

	if (strcmp(folder, "insurgency") == 0)
	{
		HookEvent("game_newmap", Event_GameStart);
	}
	else
	{
		HookEvent("game_start", Event_GameStart);
	}
	
	if (strcmp(folder, "nucleardawn") == 0)
	{
		HookEvent("round_win", Event_RoundEnd);
	}
	else
	{
		HookEvent("round_end", Event_RoundEnd);
	}
	
	HookEventEx("teamplay_win_panel", Event_TeamPlayWinPanel);
	HookEventEx("teamplay_restart_round", Event_TFRestartRound);
	HookEventEx("arena_win_panel", Event_TeamPlayWinPanel);
	
	g_Cvar_WinLimit = FindConVar("mp_winlimit");
	g_Cvar_FragLimit = FindConVar("mp_fraglimit");
	g_Cvar_MaxRounds = FindConVar("mp_maxrounds");
}

public void OnMapStart()
{
	g_TotalRounds = 0;	
}

/* Round count tracking */
public void Event_TFRestartRound(Event event, const char[] name, bool dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;	
}

public void Event_GameStart(Event event, const char[] name, bool dontBroadcast)
{
	/* Game got restarted - reset our round count tracking */
	g_TotalRounds = 0;	
}

public void Event_TeamPlayWinPanel(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("round_complete") == 1 || StrEqual(name, "arena_win_panel"))
	{
		g_TotalRounds++;
	}
}
/* You ask, why don't you just use team_score event? And I answer... Because CSS doesn't. */
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_TotalRounds++;
}

public void ConVarChange_TimeleftInterval(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float newval = StringToFloat(newValue);
	
	if (newval < 1.0)
	{
		if (g_Timer_TimeShow != null)
		{
			KillTimer(g_Timer_TimeShow);		
		}
		
		return;
	}
	
	if (g_Timer_TimeShow != null)
	{
		KillTimer(g_Timer_TimeShow);
		g_Timer_TimeShow = CreateTimer(newval, Timer_DisplayTimeleft, _, TIMER_REPEAT);
	}
	else
		g_Timer_TimeShow = CreateTimer(newval, Timer_DisplayTimeleft, _, TIMER_REPEAT);
}

public Action Timer_DisplayTimeleft(Handle timer)
{
	ShowTimeLeft(0, TIMELEFT_ALL_ALWAYS);	
}

public Action Command_Motd(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	if (!IsClientInGame(client))
		return Plugin_Handled;
	
	ShowMOTDPanel(client, "Message Of The Day", "motd", MOTDPANEL_TYPE_INDEX);

	return Plugin_Handled;
}

public Action Command_FriendlyFire(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] %t", "Command is in-game only");
		return Plugin_Handled;
	}

	if (!IsClientInGame(client))
		return Plugin_Handled;
	
	ShowFriendlyFire(client);

	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (IsChatTrigger())
	{
	}
	else if (strcmp(sArgs, "thetime", false) == 0)
	{
		char ctime[64];
		FormatTime(ctime, 64, NULL_STRING);
		
		if (g_Cvar_TriggerShow.IntValue)
		{
			PrintToChatAll("[SM] %t", "Thetime", ctime);
		}
		else
		{
			PrintToChat(client,"[SM] %t", "Thetime", ctime);
		}
	}
	else if (strcmp(sArgs, "ff", false) == 0)
	{
		ShowFriendlyFire(client);
	}
	else if (strcmp(sArgs, "motd", false) == 0)
	{
		ShowMOTDPanel(client, "Message Of The Day", "motd", MOTDPANEL_TYPE_INDEX);
	}
}

void ShowTimeLeft(int client, int who)
{
	bool lastround = false;
	bool written = false;
	bool notimelimit = false;
	
	char finalOutput[1024];
	
	if (who == TIMELEFT_ALL_ALWAYS
		|| (who == TIMELEFT_ALL_MAYBE && g_Cvar_TriggerShow.IntValue))
	{
		client = 0;	
	}
	
	int timeleft;
	if (GetMapTimeLeft(timeleft))
	{
		int mins, secs;
		int timelimit;
		
		if (timeleft > 0)
		{
			mins = timeleft / 60;
			secs = timeleft % 60;
			written = true;
			FormatEx(finalOutput, sizeof(finalOutput), "%T %d:%02d", "Timeleft", client, mins, secs);
		}
		else if (GetMapTimeLimit(timelimit) && timelimit == 0)
		{
			notimelimit = true;
		}
		else
		{
			/* 0 timeleft so this must be the last round */
			lastround=true;
		}
	}
	
	if (!lastround)
	{
		if (g_Cvar_WinLimit)
		{
			int winlimit = g_Cvar_WinLimit.IntValue;
			
			if (winlimit > 0)
			{
				if (written)
				{
					int len = strlen(finalOutput);
					if (len < sizeof(finalOutput))
					{
						if (winlimit > 1)
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "WinLimitAppendPlural" ,client, winlimit);
						}
						else
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "WinLimitAppend" ,client);
						}
					}
				}
				else
				{
					if (winlimit > 1)
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "WinLimitPlural", client, winlimit);
					}
					else
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "WinLimit", client);
					}
					
					written = true;
				}
			}
		}
		
		if (g_Cvar_FragLimit)
		{
			int fraglimit = g_Cvar_FragLimit.IntValue;
			
			if (fraglimit > 0)
			{
				if (written)
				{
					int len = strlen(finalOutput);
					if (len < sizeof(finalOutput))
					{
						if (fraglimit > 1)
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "FragLimitAppendPlural", client, fraglimit);
						}
						else
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "FragLimitAppend", client);
						}
					}	
				}
				else
				{
					if (fraglimit > 1)
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "FragLimitPlural", client, fraglimit);
					}
					else
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "FragLimit", client);
					}
					
					written = true;
				}			
			}
		}
		
		if (g_Cvar_MaxRounds)
		{
			int maxrounds = g_Cvar_MaxRounds.IntValue;
			
			if (maxrounds > 0)
			{
				int remaining = maxrounds - g_TotalRounds;
				
				if (written)
				{
					int len = strlen(finalOutput);
					if (len < sizeof(finalOutput))
					{
						if (remaining > 1)
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "MaxRoundsAppendPlural", client, remaining);
						}
						else
						{
							FormatEx(finalOutput[len], sizeof(finalOutput)-len, "%T", "MaxRoundsAppend", client);
						}
					}
				}
				else
				{
					if (remaining > 1)
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "MaxRoundsPlural", client, remaining);
					}
					else
					{
						FormatEx(finalOutput, sizeof(finalOutput), "%T", "MaxRounds", client);
					}
					
					written = true;
				}			
			}		
		}
	}
	
	if (lastround)
	{
		FormatEx(finalOutput, sizeof(finalOutput), "%T", "LastRound", client);
	}
	else if (notimelimit && !written)
	{
		FormatEx(finalOutput, sizeof(finalOutput), "%T", "NoTimelimit", client);
	}

	if (who == TIMELEFT_ALL_ALWAYS
		|| (who == TIMELEFT_ALL_MAYBE && g_Cvar_TriggerShow.IntValue))
	{
		PrintToChatAll("[SM] %s", finalOutput);
	}
	else if (client != 0 && IsClientInGame(client))
	{
		PrintToChat(client, "[SM] %s", finalOutput);
	}
	
	if (client == 0)
	{
		PrintToServer("[SM] %s", finalOutput);
	}
}

void ShowFriendlyFire(int client)
{
	if (g_Cvar_FriendlyFire)
	{
		char phrase[24];
		if (g_Cvar_FriendlyFire.BoolValue)
		{
			strcopy(phrase, sizeof(phrase), "Friendly Fire On");
		}
		else
		{
			strcopy(phrase, sizeof(phrase), "Friendly Fire Off");
		}
	
		if (g_Cvar_TriggerShow.IntValue)
		{
			PrintToChatAll("[SM] %t", phrase);
		}
		else
		{
			PrintToChat(client,"[SM] %t", phrase);
		}
	}
}
