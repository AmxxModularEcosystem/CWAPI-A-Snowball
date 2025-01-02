#include <amxmodx>
#include <reapi>
#include <cwapi>

public stock const PluginName[] = "[CWAPI-A] Freeze";
public stock const PluginVersion[] = "1.0.0";
public stock const PluginAuthor[] = "ArKaNeMaN";
public stock const PluginURL[] = "https://github.com/AmxxModularEcosystem/CWAPI-A-Snowball";
public stock const PluginDescription[] = "[CustomWeaponsAPI-Ability] Freezing on damage.";

enum S_FreezeData {
    bool:FreezeData_Frozen,
    Float:FreezeData_Duration,
    Float:FreezeData_SpeedMultiplier,
}
new PlayersFreezeData[MAX_PLAYERS + 1][S_FreezeData];

new const ABILITY_NAME[] = "Freeze";

public CWAPI_OnLoad() {
    register_plugin(PluginName, PluginVersion, PluginAuthor);
    
    new T_WeaponAbility:ability = CWAPI_Abilities_Register(ABILITY_NAME);
    CWAPI_Abilities_AddParams(ability,
        "Duration", "Float", true,
        "SpeedMultiplier", "Float", false,
        "Chance", "Float", false
    );

    CWAPI_Abilities_AddEventListener(ability, CWeapon_OnDamage, "@OnDamage");

    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "@OnResetMaxSpeed", .post = true);

    if (plugin_flags() & AMX_FLAG_DEBUG > 0) {
        register_clcmd("cwapi_a_freeze_dbg_freeze_self", "@Dbg_ClCmd_FreezeSelf");
    }
}

@Dbg_ClCmd_FreezeSelf(const playerIndex) {
    FreezePlayer(playerIndex, 5.0, 0.5);
}

public client_putinserver(playerIndex) {
    UnfreezePlayer(playerIndex);
}

@OnResetMaxSpeed(const playerIndex) {
    if (!PlayersFreezeData[playerIndex][FreezeData_Frozen]) {
        return;
    }

    if (!is_user_alive(playerIndex)) {
        return;
    }

    new Float:speed = get_entvar(playerIndex, var_maxspeed);
    speed *= PlayersFreezeData[playerIndex][FreezeData_SpeedMultiplier];
    set_entvar(playerIndex, var_maxspeed, speed);
}

public client_disconnected(playerIndex) {
    UnfreezePlayer(playerIndex);
}

@OnDamage(const T_CustomWeapon:weapon, const itemIndex, const victimIndex, const inflictorIndex, const attackerIndex, &Float:damage, &damageBits, const Trie:abilityParams) {
    new Float:chance = 1.0;
    TrieGetCell(abilityParams, "Chance", chance);
    if (random_float(0.0, 1.0) > chance) {
        return;
    }

    new Float:duration;
    TrieGetCell(abilityParams, "Duration", duration);

    new Float:speedMultiplier;
    TrieGetCell(abilityParams, "SpeedMultiplier", speedMultiplier);

    FreezePlayer(victimIndex, duration, speedMultiplier);
}

FreezePlayer(const playerIndex, const Float:duration, const Float:speedMultiplier) {
    UnfreezePlayer(playerIndex);

    if (!is_user_alive(playerIndex)) {
        return;
    }

    PlayersFreezeData[playerIndex][FreezeData_Frozen] = true;
    PlayersFreezeData[playerIndex][FreezeData_Duration] = duration;
    PlayersFreezeData[playerIndex][FreezeData_SpeedMultiplier] = speedMultiplier;

    set_task(PlayersFreezeData[playerIndex][FreezeData_Duration], "@Task_Unfreeze", playerIndex);
    rg_reset_maxspeed(playerIndex);
    rg_set_user_rendering(playerIndex, kRenderFxGlowShell, 115, 155, 208, kRenderNormal, 50);
}

@Task_Unfreeze(const playerIndex) {
    UnfreezePlayer(playerIndex);
}

UnfreezePlayer(const playerIndex) {
    PlayersFreezeData[playerIndex][FreezeData_Frozen] = false;
    remove_task(playerIndex);
    rg_set_user_rendering(playerIndex);

    if (is_user_alive(playerIndex)) {
        rg_reset_maxspeed(playerIndex);
    }
}

stock rg_set_user_rendering(const Ent, const Fx = kRenderFxNone, const r = 0, const g = 0, const b = 0, const Render = kRenderNormal, const Amount = 0){
    if (is_nullent(Ent)) {
        return;
    }

    set_entvar(Ent, var_rendermode, Render);
    set_entvar(Ent, var_renderamt, float(Amount));
    static Float:Color[3];
    Color[0] = float(r);
    Color[1] = float(g);
    Color[2] = float(b);
    set_entvar(Ent, var_rendercolor, Color);
    set_entvar(Ent, var_renderfx, Fx);
}