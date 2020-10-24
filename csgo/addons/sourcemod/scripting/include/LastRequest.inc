#if defined LASTREQUEST_INC
	#endinput
#endif
#define LASTREQUEST_INC

native bool IsPlayerInLr(int client);
native int GetPlayersInLr(int& tPlayer, int& ctPlayer);
native int GetPlayerInLrFromTeam(int team);
native LrGame GetActiveLr();
native LrGroup GetActiveLrGroup();
native bool IsLrInProgress();