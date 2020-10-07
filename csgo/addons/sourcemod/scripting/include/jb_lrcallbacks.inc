#if defined JB_LRCALLBACKS_INC
 #endinput
#endif
#define JB_LRCALLBACKS_INC

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#include <jb_core>
#include <jb_lastrequest>


public Action StartLrNoLr(Handle timer, any arg)
{
	
}

public Action StartLrClose(Handle timer, any arg)
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

public Action StartLrNoscope(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	LrGame activeLr = GetActiveLr();
	
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

public Action StartLrDodgeball(Handle timer, any arg)
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
	
	SetEntityHealth(tPlayer, 1);
	SetEntityHealth(ctPlayer, 1);
}

public Action StartLrShot4Shot(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	LrGame activeLr = GetActiveLr();
	
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
	
	SetPlayerAmmo(tPlayer, weaponT, 0);
	SetPlayerMagAmmo(weaponT, 1);
	SetPlayerAmmo(ctPlayer, weaponCt, 0);
	SetPlayerMagAmmo(weaponCt, 0);
	
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
}


public Action StartLrGunToss(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
	
	int tDeagle = GivePlayerItem(tPlayer, "weapon_deagle");
	int ctDeagle = GivePlayerItem(ctPlayer, "weapon_deagle");
	SetPlayerAmmo(tPlayer, tDeagle, 0);
	SetPlayerAmmo(ctPlayer, ctDeagle, 0);
	SetPlayerMagAmmo(tDeagle, 0);
	SetPlayerMagAmmo(ctDeagle, 0);
	SetEntityRenderColor(tDeagle, 255, 255, 255);
	SetEntityRenderMode(tDeagle, RENDER_NORMAL);
}

public Action StartLrHotPotato(Handle timer, any arg)
{
	// TODO
}

public Action StartLrChickenFight(Handle timer, any arg)
{
	int tPlayer, ctPlayer;
	GetPlayersInLr(tPlayer, ctPlayer);
	SetEntityHealth(tPlayer, 100);
	SetEntityHealth(ctPlayer, 100);
	
	CreateTimer(0.1, TimerLrChickenFightCheck, _, TIMER_REPEAT);
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
			
			SlapPlayer(loser, 100, false);
			
			Handle event = CreateEvent("player_death");
			SetEventInt(event, "userid", GetClientUserId(loser));
			SetEventInt(event, "attacker", GetClientUserId(winner));
			SetEventString(event, "weapon", "");
			FireEvent(event, false);

			KillTimer(timer);
		}
	}
	else
		KillTimer(timer);
}
