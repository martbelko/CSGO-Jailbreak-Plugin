#if defined JB_LASTREQUEST_INC
 #endinput
#endif
#define JB_LASTREQUEST_INC

enum LrGroup
{
	LRG_NO_LR = 0,
	LRG_CLOSE,
	LRG_NOSCOPE,
	LRG_DODGEBALL,
	LRG_S4S,
	LRG_CHICKEN_FIGHT,
	LRG_GUN_TOSS,
	LRG_HOT_POTATO,
	LRG_REBEL
}

enum LrGame
{
	LR_NO_LR = 0,
	LR_1HP_KNIFE,
	LR_100HP_KNIFE,
	LR_1HP_FISTS,
	LR_100HP_FISTS,
	LR_CHICKEN_FIGHT,
	LR_GUN_TOSS,
	LR_NOSCOPE_SCOUT,
	LR_NOSCOPE_AWP,
	LR_NOSCOPE_G3SG1,
	LR_NOSCOPE_SCAR20,
	LR_DODGEBALL_MEELEE,
	LR_DODGEBALL_FLASHBANG,
	LR_DODGEBALL_SNOWBALL,
	LR_HOT_POTATO,
	LR_S4S_DEAGLE,
	LR_S4S_REVOLVER,
	LR_S4S_GLOCK,
	LR_S4S_USP,
	LR_S4S_P2000,
	LR_S4S_P250,
	LR_S4S_DUALS,
	LR_S4S_TEC9,
	LR_S4S_FIVESEVEN,
	LR_S4S_CZ75,
	LR_REBEL
}

#include <jb_core>
#include <sdktools>

native bool IsPlayerInLr(int client);
native int GetPlayersInLr(int& tPlayer, int& ctPlayer);
native int GetPlayerInLrFromTeam(int team);
native LrGame GetActiveLr();
native LrGroup GetActiveLrGroup();
native bool IsLrInProgress();
