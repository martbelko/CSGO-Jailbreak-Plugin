#if defined BANSYSTEM_INC
 #endinput
#endif
#define BANSYSTEM_INC

enum BanType
{
	BT_NONE = 0,
	BT_NORMAL,
	BT_CT
}

native BanType IsBanned(int client, char[] error, int maxErrorLength);
