// base grab code taken from http://forums.alliedmods.net/showthread.php?t=157075

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define SOUND_GRAB_TF "ui/item_default_pickup.wav"      // grab
#define SOUND_TOSS_TF "ui/item_default_drop.wav"        // throw

#define THROW_FORCE 1000.0
#define GRAB_DISTANCE 150.0

#define PLUGIN_NAME     "Admin Grabber"
#define PLUGIN_AUTHOR   "Friagram"
#define PLUGIN_VERSION  "1.0.2"
#define PLUGIN_DESCRIP  "Allows Admins to Grab Stuff"
#define PLUGIN_CONTACT  "http://steamcommunity.com/groups/poniponiponi"

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIP,
	version = PLUGIN_VERSION,
	url = PLUGIN_CONTACT
};

int g_grabbed[MAXPLAYERS + 1];              // track client's grabbed object
float gDistance[MAXPLAYERS + 1];        // track distance of grabbed object
bool g_access[MAXPLAYERS + 1];
bool s_IsGrabbed[MAXPLAYERS + 1] = false;

//////////////////////////////////////////////////////////////////////
/////////////                    Setup                   /////////////
//////////////////////////////////////////////////////////////////////

public void OnPluginStart()
{
	CreateConVar("admingrab_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY);

	RegAdminCmd("sm_grab", Command_Grab_Toggle, ADMFLAG_SLAY, "Grab an Object");
	RegAdminCmd("sm_throw", Command_Throw, ADMFLAG_SLAY, "Throw an Object");

	HookEvent("player_death", OnPlayerSpawn);
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_team", OnPlayerSpawn);

	for (int client = 1; client <= MaxClients; ++client)
	{
		if(IsClientInGame(client))
		{
			if(CheckCommandAccess(client, "admin_grab", ADMFLAG_SLAY))
			{
				g_access[client] = true;
				SDKHook(client, SDKHook_PreThink, OnPreThink);
			}
		}
	}
}

public void OnMapStart()
{
	for (int client = 1; client <= MaxClients; ++client)
	{
		g_grabbed[client] = INVALID_ENT_REFERENCE;
	}

	PrecacheSound(SOUND_GRAB_TF, true);
	PrecacheSound(SOUND_TOSS_TF, true);
}

public void OnClientPostAdminCheck(int client)
{
	if (CheckCommandAccess(client, "admin_grab", ADMFLAG_SLAY))
	{
		g_access[client] = true;
		SDKHook(client, SDKHook_PreThink, OnPreThink);
	}
}

public void OnClientPutInServer(int client)
{
	g_access[client] = false;
	g_grabbed[client] = INVALID_ENT_REFERENCE;
}

//////////////////////////////////////////////////////////////////////
/////////////                  Commands                  /////////////
//////////////////////////////////////////////////////////////////////

/*public Action OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (0 < client <= MaxClients)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && s_IsGrabbed[client])
		{
			if (buttons & IN_FORWARD)
				SetEntityFlags(client, (buttons |= FL_FROZEN));
			else if (buttons & IN_BACK)
				SetEntityFlags(client, (buttons |= FL_FROZEN));
			else if (buttons & IN_MOVELEFT)
				SetEntityFlags(client, (buttons &= ~FL_FROZEN));
			else if (buttons & IN_MOVERIGHT)
				SetEntityFlags(client, (buttons &= ~FL_FROZEN));
		}
	}
	return Plugin_Continue; 
}*/

public Action Command_Grab_Toggle(int client, int argc)
{
	if(client && IsClientInGame(client))
	{
		int grabbed = EntRefToEntIndex(g_grabbed[client]);
		if (grabbed != INVALID_ENT_REFERENCE)
		{
			if (GetClientButtons(client) & IN_ATTACK2)
			{
				ThrowObject(client, grabbed, true);
			}
			else
			{
				ThrowObject(client, grabbed, false);
			}
		}
		else
		{
			GrabObject(client);
		}
	}

	return Plugin_Handled;
}

public Action Command_Throw(int client, int argc)
{
	if(client && IsClientInGame(client))
	{
		int grabbed = EntRefToEntIndex(g_grabbed[client]);
		if(grabbed != INVALID_ENT_REFERENCE)
		{
			ThrowObject(client, grabbed, true);
		}
	}

	return Plugin_Handled;
}

void GrabObject(int client)
{
	int grabbed = TraceToObject(client);		// -1 for no collision, 0 for world
	if (grabbed > 0)
	{
		if (grabbed > MaxClients)
		{
			char classname[13];
			GetEntityClassname(grabbed, classname, 13);

			if (StrEqual(classname, "prop_physics"))
			{
				int grabber = GetEntPropEnt(grabbed, Prop_Data, "m_hPhysicsAttacker");
				if(grabber > 0 && grabber <= MaxClients && IsClientInGame(grabber))
				{
					return;															// another client is grabbing this object
				}
				SetEntPropEnt(grabbed, Prop_Data, "m_hPhysicsAttacker", client);
				AcceptEntityInput(grabbed, "EnableMotion");
			}
		
			SetEntityMoveType(grabbed, MOVETYPE_VPHYSICS);
		}
		else
		{
			if (!CanAdminTarget(GetUserAdmin(client), GetUserAdmin(grabbed)))
			{
				return;															// can they grab players and admin immunity checks out?
			}
			
			if (s_IsGrabbed[client])
				return;

			SetEntityMoveType(grabbed, MOVETYPE_NOCLIP);
			s_IsGrabbed[grabbed] = true;
			
			PrintHintText(client,"Grabbing %N",grabbed);
			PrintHintText(grabbed,"%N is grabbing you!",client);
		}

		if (GetClientButtons(client) & IN_ATTACK2)				// Store and maintain distance
		{
			float VecPos_grabbed[3], VecPos_client[3];
			GetEntPropVector(grabbed, Prop_Send, "m_vecOrigin", VecPos_grabbed);
			GetClientEyePosition(client, VecPos_client);
			gDistance[client] = GetVectorDistance(VecPos_grabbed, VecPos_client);
		}
		else
		{
			gDistance[client] = GRAB_DISTANCE;				// Use prefab distance
		}

		TeleportEntity(grabbed, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));

		g_grabbed[client] = EntIndexToEntRef(grabbed);

		EmitSoundToClient(client, SOUND_GRAB_TF);
	}
}

ThrowObject(int client, int grabbed, bool throw_t)
{
	if (throw_t)
	{
		float vecView[3], vecFwd[3], vecPos[3], vecVel[3];

		GetClientEyeAngles(client, vecView);
		GetAngleVectors(vecView, vecFwd, NULL_VECTOR, NULL_VECTOR);
		GetClientEyePosition(client, vecPos);

		vecPos[0] += vecFwd[0] * THROW_FORCE;
		vecPos[1] += vecFwd[1] * THROW_FORCE;
		vecPos[2] += vecFwd[2] * THROW_FORCE;

		GetEntPropVector(grabbed, Prop_Send, "m_vecOrigin", vecFwd);

		SubtractVectors(vecPos, vecFwd, vecVel);
		ScaleVector(vecVel, 10.0);

		TeleportEntity(grabbed, NULL_VECTOR, NULL_VECTOR, vecVel);
	}
	
	SetEntityMoveType(grabbed, MOVETYPE_WALK);

	EmitSoundToClient(client, SOUND_TOSS_TF);
	
	if (grabbed < MaxClients)
	{
		s_IsGrabbed[grabbed] = false;
	}
	g_grabbed[client] = INVALID_ENT_REFERENCE;
	
	if(grabbed > MaxClients)
	{
		char classname[13];
		GetEntityClassname(grabbed, classname, 13);
		if(StrEqual(classname, "prop_physics"))
		{
			SetEntPropEnt(grabbed, Prop_Data, "m_hPhysicsAttacker", 0);
		}
	}
}

//////////////////////////////////////////////////////////////////////
/////////////                  Prethink                  /////////////
//////////////////////////////////////////////////////////////////////

public void OnPreThink(int client)
{
	int grabbed = EntRefToEntIndex(g_grabbed[client]);
	if (grabbed != INVALID_ENT_REFERENCE)
	{
		float vecView[3], vecFwd[3], vecPos[3], vecVel[3];

		GetClientEyeAngles(client, vecView);
		GetAngleVectors(vecView, vecFwd, NULL_VECTOR, NULL_VECTOR);
		GetClientEyePosition(client, vecPos);

		vecPos[0] += vecFwd[0] * gDistance[client];
		vecPos[1] += vecFwd[1] * gDistance[client];
		vecPos[2] += vecFwd[2] * gDistance[client];

		GetEntPropVector(grabbed, Prop_Send, "m_vecOrigin", vecFwd);

		SubtractVectors(vecPos, vecFwd, vecVel);
		ScaleVector(vecVel, 10.0);

		TeleportEntity(grabbed, NULL_VECTOR, NULL_VECTOR, vecVel);
	}
}

//////////////////////////////////////////////////////////////////////
/////////////                    Events                  /////////////
//////////////////////////////////////////////////////////////////////

public OnPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client)
	{
		if(g_access[client])
		{
			int grabbed = EntRefToEntIndex(g_grabbed[client]);
			if (grabbed != INVALID_ENT_REFERENCE && grabbed > MaxClients)
			{
				char classname[13];
				GetEntityClassname(grabbed, classname, 13);
				if (StrEqual(classname, "prop_physics"))
				{
					SetEntPropEnt(grabbed, Prop_Data, "m_hPhysicsAttacker", 0);
				}
			}
			g_grabbed[client] = INVALID_ENT_REFERENCE;				// Clear their grabs
		}

		for (int i = 1; i <= MaxClients; ++i)
		{
			if(EntRefToEntIndex(g_grabbed[i]) == client)
			{
				g_grabbed[i] = INVALID_ENT_REFERENCE;				// Clear grabs on them
			}
		}
	}

	return;
}

//////////////////////////////////////////////////////////////////////
/////////////                    Trace                   /////////////
//////////////////////////////////////////////////////////////////////

public TraceToObject(client)
{
	float vecClientEyePos[3], vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos);
	GetClientEyeAngles(client, vecClientEyeAng);

	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRayGrab, client);

	return TR_GetEntityIndex(INVALID_HANDLE);
}

public bool TraceRayGrab(entityhit, mask, any:self)
{
	if (entityhit > 0 && entityhit <= MaxClients)
	{
		if(IsPlayerAlive(entityhit) && entityhit != self)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{		
		char classname[13];
		if (GetEntityClassname(entityhit, classname, 13) && (StrEqual(classname, "prop_physics") || StrEqual(classname, "tf_ammo_pack") || !StrContains(classname, "tf_projectil")))
		{
			return true;
		}
	}

	return false;
}