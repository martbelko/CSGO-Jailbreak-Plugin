#if defined JB_SIMON_INC
 #endinput
#endif
#define JB_SIMON_INC

#define SG_NO_GAME 0
#define SG_HIDE_AND_SEEK 1

enum JBTeam
{
	JBT_TEAM_NONE = 0,
	JBT_TEAM_A,
	JBT_TEAM_B
}

native int GetSimon();
native bool IsSimon(int client);

native int GetActiveSimonGame();

native JBTeam GetPlayerJBTeam(int client);
