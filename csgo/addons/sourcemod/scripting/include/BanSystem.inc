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

native BanType IsBanned(const char[] auth, char[] error, int maxErrorLength);
