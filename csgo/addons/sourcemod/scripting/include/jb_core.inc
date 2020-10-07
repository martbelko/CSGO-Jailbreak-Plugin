#if defined JB_CORE_INC
 #endinput
#endif
#define JB_CORE_INC

#include <cstrike>
#include <valist>

#define IsClientValid(%1) (0 < %1 && %1 <= MaxClients && IsClientInGame(%1))

#define IsOwner(%1)    GetAdminFlag(GetUserAdmin(%1), Admin_Root)
#define IsAdmin(%1)    GetAdminFlag(GetUserAdmin(%1), Admin_Generic)

native void AddSkin(const char[] path);

native void Disarm(int client, bool removeArmor = true);
native void DisarmIn(float time, int client, bool removeArmor = true);
native void DropPlayerWeapons(int client);
native int GivePlayerItemIn(float time, int client, const char[] weaponName);
native bool HasWeapon(int client, const char[] weaponName);
native float GetEntitiesDistance(int entity1, int entity2);

native void SetPlayerArmor(int client, int armor);
native void SetPlayerHelmet(int client, bool helmet);
native void GivePlayerAmmoEx(int client, int weapon, int amount, bool supressSound = true);
native void SetPlayerAmmo(int client, int weapon, int amount);
native void SetPlayerMagAmmo(int weapon, int amount);
native void SetPlayerHeavySuit(int client, bool enable);

native void SetNoScope(int weapon);

native int GetRandomPlayer(int team, bool aliveOnly = true);
native int GetNumberOfPlayers(int team = CS_TEAM_NONE, bool aliveOnly = true);

native void AddPlayersToMenuSelection(Menu menu, int team = CS_TEAM_NONE, bool aliveOnly = true, int ignorePlayer = -1);

native int ChickenFightCheck(int client1, int client2);

native bool IsPlayerInvisible(int client);

native void OpenDoors();
native void CloseDoors();
native void SetPlayerInvisible(int client);
native void SetPlayerVisible(int client);

native void DisplayRules(int client);

native bool IsVisibleTo(int client, int entity);

native void EnableDoubleJump(int client, bool enable);

native void EmitSoundToAny(int client, const char[] path);
native void EmitSoundToAllAny(const char[] path);

public void PrintToChatTeam(int team, bool allowAdmins, const char[] format, any ...)
{
	char message[256];
	VFormat(message, sizeof(message), format, 4);
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientValid(i) && !IsFakeClient(i) && (GetClientTeam(i) == team || (allowAdmins && IsAdmin(i))))
			PrintToChat(i, message);
	}
}
