#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Moonly Days"
#define PLUGIN_VERSION "2.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define MINE_MODEL "models/csgo_bumpmines/csgo_bumpmine.mdl"
#define MINE_SOUND_DETONATE "csgo_bumpmines/bumpmine_detonate.wav"
#define MINE_SOUND_LAND "csgo_bumpmines/bumpmine_land_01.wav"
#define MINE_SOUND_LAUNCH "csgo_bumpmines/bumpmine_launch_01.wav"
#define MINE_SOUND_PICKUP "csgo_bumpmines/bumpmine_pickup.wav"
#define MINE_SOUND_THROW "csgo_bumpmines/bumpmine_throw.wav"

bool p_HasMine[MAXPLAYERS + 1];
int p_Mine[MAXPLAYERS + 1];
bool g_isActivated[2049];
int p_Recharge[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[TF2] CS:GO Bumpmines",
	author = PLUGIN_AUTHOR,
	description = "CS:GO Impulse Mines from Danger Zone",
	version = PLUGIN_VERSION,
	url = "rcatf2.ru"
};

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/csgo_bumpmines/bumpmine_detonate.wav");
	AddFileToDownloadsTable("sound/csgo_bumpmines/bumpmine_land_01.wav");
	AddFileToDownloadsTable("sound/csgo_bumpmines/bumpmine_launch_01.wav");
	AddFileToDownloadsTable("sound/csgo_bumpmines/bumpmine_pickup.wav");
	AddFileToDownloadsTable("sound/csgo_bumpmines/bumpmine_throw.wav");
	
	AddFileToDownloadsTable("models/csgo_bumpmines/csgo_bumpmine.mdl");
	AddFileToDownloadsTable("models/csgo_bumpmines/csgo_bumpmine.phy");
	AddFileToDownloadsTable("models/csgo_bumpmines/csgo_bumpmine.vvd");
	AddFileToDownloadsTable("models/csgo_bumpmines/csgo_bumpmine.dx80.vtx");
	AddFileToDownloadsTable("models/csgo_bumpmines/csgo_bumpmine.dx90.vtx");
	AddFileToDownloadsTable("models/csgo_bumpmines/csgo_bumpmine.sw.vtx");
	
	AddFileToDownloadsTable("materials/models/csgo_bumpmines/bump_mine_color.vmt");
	AddFileToDownloadsTable("materials/models/csgo_bumpmines/bump_mine_color.vtf");
	AddFileToDownloadsTable("materials/models/csgo_bumpmines/bump_mine_exponent.vtf");
	AddFileToDownloadsTable("materials/models/csgo_bumpmines/bump_mine_glow.vmt");
	AddFileToDownloadsTable("materials/models/csgo_bumpmines/bump_mine_glow_01.vtf");
	AddFileToDownloadsTable("materials/models/csgo_bumpmines/bump_mine_glow_02.vtf");
	
	PrecacheModel(MINE_MODEL);
	PrecacheSound(MINE_SOUND_DETONATE);
	PrecacheSound(MINE_SOUND_LAND);
	PrecacheSound(MINE_SOUND_PICKUP);
	PrecacheSound(MINE_SOUND_LAUNCH);
	PrecacheSound(MINE_SOUND_THROW);
}

public void OnPluginStart()
{
    HookEvent("player_spawn", evPlayerSpawn);
    HookEvent("post_inventory_application", evPlayerSpawn);
    //HookEvent("player_death", evPlayerDeath);
    CreateTimer(0.5, Timer_HUDManager, _, TIMER_REPEAT);
    CreateTimer(1.0, Timer_ReCharge, _, TIMER_REPEAT);
}

public Action Timer_ReCharge(Handle timer, any data)
{
	for (new i = 1; i <= MaxClients;i++)
	{
		if(IsValidPlayer(i) && IsPlayerAlive(i)){
			if(!p_HasMine[i] && p_Recharge[i] > 0)
			{
				p_Recharge[i]--;
				if (p_Recharge[i] == 1)BMine_ResetPlayer(i);
			}
		}
	}
}
public Action Timer_HUDManager(Handle timer, any data)
{
	for (new i = 1; i <= MaxClients;i++)
	{
		if(IsValidPlayer(i)){
			if(IsPlayerAlive(i))
			{
				SetHudTextParams(0.8, 0.9, 0.5, 255, 255, 255, 255);
				if(p_HasMine[i])
				{
					ShowHudText(i, 1, "[֎]");
				}else if(p_Recharge[i] > 0){
					new String:buffer[10] = "[";
					int iSticks = 5-RoundToCeil(p_Recharge[i] / 6.0);
					for (new j = 1; j <= 5; j++){
						if (iSticks > j){
							Format(buffer, 10, "%s|", buffer);
						}else{
							Format(buffer, 10, "%s ", buffer);
						}
					}
					Format(buffer, 10, "%s]", buffer);
					ShowHudText(i, 1, buffer);
				}
			}
		}
	}
}

public Action OnPlayerRunCmd(client, &buttons, &impulse, float vel[3], float angles[3], &weapon)
{
	if(buttons & IN_RELOAD)
	{
		if(p_HasMine[client])
		{
			BMine_Deploy(client);
		}
	}
}
public Action evPlayerSpawn(Handle hEvent, const String:szName[], bool bDontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if (client < 1)return Plugin_Continue;
    BMine_ResetPlayer(client);
    return Plugin_Continue;
}

public void BMine_ResetPlayer(int client)
{
	if (p_HasMine[client])return;
	p_Recharge[client] = 0;
	p_HasMine[client] = true;
	SetHudTextParams(0.8, 0.8, 3.0, 255, 255, 255, 255);
	ShowHudText(client,2, "֎ Bump Mine Equipped\nHit [Reload Key] to use");
}

public void BMine_Launch(int iMine, int iClient)
{
	EmitSoundToAll(MINE_SOUND_LAUNCH, iMine);
	AcceptEntityInput(iMine, "Kill");
	p_Mine[iClient] = 0;
	float flVel[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", flVel);
	ScaleVector(flVel, 3.0);
	float flPushVel[3] =  { 0.0, 0.0, 800.0 };
	AddVectors(flVel, flPushVel, flVel);
	TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, flVel);
}

public void BMine_Activate(int mine, float flHitPos[3])
{
	AcceptEntityInput(mine, "DisableMotion");
	float flAng[3];
	GetEntPropVector(mine, Prop_Send, "m_angRotation",flAng);
	SetEntProp(mine, Prop_Send, "m_nBody", (1 << 0));
	flAng[0] = 0.0;
	flAng[2] = 0.0;
	TeleportEntity(mine, flHitPos, flAng, NULL_VECTOR);
	EmitSoundToAll(MINE_SOUND_LAND, mine);
	CreateTimer(0.5, Timer_BMineFinalActivation,mine);
}

public Action Timer_BMineFinalActivation(Handle timer, any mine)
{
	g_isActivated[mine] = true;
}

public void BMine_Deploy(int client)
{
	p_HasMine[client] = false;
	if (IsValidMine(p_Mine[client]))AcceptEntityInput(p_Mine[client], "Kill");
	int iEnt = CreateEntityByName("prop_physics");
	if (IsValidEdict(iEnt))
	{
		SetEntityModel(iEnt, MINE_MODEL);
		float flPos[3], flAng[3], flVec[3];
		GetClientEyePosition(client, flPos);
		GetClientEyeAngles(client, flAng);
		flPos[2] -= 10.0;
		GetAngleVectors(flAng, flVec, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(flVec, 250.0);
		float flPlyVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", flPlyVel);
		AddVectors(flVec, flPlyVel, flVec);
		DispatchKeyValue(iEnt, "targetname", "tf_bumpmine");
		DispatchSpawn(iEnt);
		ActivateEntity(iEnt);
		SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 1);
		SDKHook(iEnt, SDKHook_Touch, OnMineTouch);
		TeleportEntity(iEnt, flPos, flAng, flVec);
		p_Mine[client] = iEnt;
		g_isActivated[iEnt] = false;
		CreateTimer(0.5, Timer_BMineCheckIfGrounded, iEnt, TIMER_REPEAT);
		ClientCommand(client,"playgamesound %s", MINE_SOUND_THROW);
		p_Recharge[client] = 30;
		//SetHudTextParams(0.8, 0.75, 3.0, 255, 255, 255, 255);
		//ShowHudText(client,-1, "֎ Bomb Deployed");
	}
}

public bool IsValidMine(int entity)
{
	if (!IsValidEdict(entity))return false;
	if (entity > 0)
	{
		char tName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", tName, 16);
		if (StrContains(tName, "tf_bumpmine") != -1)
		{
			return true;
		}
	}
	return false;
}

public void OnMineTouch(iMine,iToucher)
{
	if(g_isActivated[iMine] && IsValidPlayer(iToucher))
	{
		BMine_Launch(iMine, iToucher);
	}
}

public Action Timer_BMineCheckIfGrounded(Handle timer, any entity)
{
	if (!IsValidMine(entity))CloseHandle(timer);
	BMine_CheckIsGrounded(entity, timer);
}

public float BMine_CheckIsGrounded(int entity, Handle timer)
{
	float flPos[3], flHitPos[3];
	float flAng[3] = { 90.0, 0.0, 0.0 };
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", flPos);
	Handle trace = TR_TraceRayFilterEx(flPos, flAng, CONTENTS_SOLID|CONTENTS_MOVEABLE, RayType_Infinite, TraceEntityFilterAlways, entity); 
	if(TR_DidHit(trace)) { 
		TR_GetEndPosition(flHitPos, trace); 
		if(flPos[2] - flHitPos[2]<10.0)	{
			BMine_Activate(entity, flHitPos);
			KillTimer(timer);
		}
	} 
	CloseHandle(trace);
}
public bool TraceEntityFilterAlways(entity, contentsMask, any:data)
{
	return !IsValidEdict(data);
}

public IsValidPlayer(int client)
{
	return (0 < client <= MaxClients) && IsClientInGame(client);
}