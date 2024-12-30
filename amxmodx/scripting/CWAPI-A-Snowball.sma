#include <amxmodx>
#include <reapi>
#include <hamsandwich>
#include <xs>
#include <cwapi>

public stock const PluginName[] = "[CWAPI-A] Snowball";
public stock const PluginVersion[] = "dev";
public stock const PluginAuthor[] = "ArKaNeMaN";
public stock const PluginURL[] = "https://github.com/AmxxModularEcosystem/CWAPI-A-Snowball";
public stock const PluginDescription[] = "[CustomWeaponsAPI-Ability] Snowball throwing.";

// TODO: Ассеты в сборке

// TODO: cfg? (cvars/params)
#define KNIFE_STUCKED_TIME 3.0
new const SNOWBALL_CLASSNAME[] = "cwapi_a_snowball";
new const SNOWBALL_MODEL[] = "models/weapons/cwapi/Snowball/w_snowball.mdl"; // TODO: from cwpn attrs?
new SNOWBALL_MODEL_INDEX;
new const SNOWBALL_SOUND_HIT[] = "weapons/cwapi/Snowball/byMayroN/hit.wav";
new const SNOWBALL_SOUND_MISS[] = "weapons/cwapi/Snowball/byMayroN/miss.wav";

new const ABILITY_NAME[] = "Snowball";

public plugin_precache() {
    SNOWBALL_MODEL_INDEX = precache_model(SNOWBALL_MODEL);

    precache_sound(SNOWBALL_SOUND_HIT);
    precache_sound(SNOWBALL_SOUND_MISS);
}

public CWAPI_OnLoad() {
    register_plugin(PluginName, PluginVersion, PluginAuthor);
    
    new T_WeaponAbility:ability = CWAPI_Abilities_Register(ABILITY_NAME);
    CWAPI_Abilities_AddParams(ability,
        "Damage", "Float", true,
        "Speed", "Float", false,
        "Gravity", "Float", false
    );
    CWAPI_Abilities_AddParams(ability,
        "MeltTime", "Float", false,
        "FreezeChance", "Float", false
    );

    CWAPI_Abilities_AddEventListener(ability, CWeapon_OnPlayerThrowGrenade, "@OnPlayerThrowGrenade");
}

@OnPlayerThrowGrenade(const T_CustomWeapon:weapon, const itemIndex, const playerIndex, Float:vecSrc[3], Float:vecThrow[3], &Float:time, const event, const Trie:abilityParams) {
    new Float:damage;
    TrieGetCell(abilityParams, "Damage", damage);

    // TODO
    new Float:meltTime = 3.0;
    TrieGetCell(abilityParams, "MeltTime", meltTime);

    new Float:speed = 1500.0;
    TrieGetCell(abilityParams, "Speed", speed);

    new Float:gravity = 0.5;
    TrieGetCell(abilityParams, "Gravity", gravity);

    new Float:freezeChance = 0.0;
    TrieGetCell(abilityParams, "FreezeChance", freezeChance);

    ThrowSnowball(playerIndex, damage, speed, gravity, freezeChance);
    return CWAPI_STOP_MAIN;
}

DamageBySnowball(const victimIndex, const attackerIndex, const snowballIndex) {
    if (!is_user_alive(victimIndex)) {
        return;
    }

    new Float:snowballDamage = get_entvar(snowballIndex, var_dmg);

    if (rg_is_player_can_takedamage(victimIndex, attackerIndex)) {
        ExecuteHamB(Ham_TakeDamage, victimIndex, snowballIndex, attackerIndex, snowballDamage, DMG_FREEZE|DMG_NEVERGIB|DMG_PARALYZE);
    }
}

// https://github.com/AmxxModularEcosystem/CWAPI-A-ThrowKnife/blob/master/amxmodx/scripting/CWAPI-A-ThrowKnife.sma

ThrowSnowball(
    const playerIndex,
    const Float:damage = 45.0,
    const Float:velocity = 1500.0,
    const Float:gravity = 0.5,
    const Float:freezeChance = 0.0 // TODO
) {
    new Float:playerOrigin[3];
    get_entvar(playerIndex, var_origin, playerOrigin);
    
    new Float:playerViewOfs[3];
    get_entvar(playerIndex, var_view_ofs, playerViewOfs);

    new Float:playerViewAngle[3];
    get_entvar(playerIndex, var_v_angle, playerViewAngle);
    
    new snowballIndex = rg_create_entity("info_target");
    set_entvar(snowballIndex, var_classname, SNOWBALL_CLASSNAME);
    set_entvar(snowballIndex, var_modelindex, SNOWBALL_MODEL_INDEX);
    set_entvar(snowballIndex, var_model, SNOWBALL_MODEL);

    new Float:snowballVelocity[3];
    angle_vector(playerViewAngle, ANGLEVECTOR_FORWARD, snowballVelocity);
    xs_vec_mul_scalar(snowballVelocity, velocity, snowballVelocity);
    set_entvar(snowballIndex, var_velocity, snowballVelocity);

    new Float:startSnowballOrigin[3];
    xs_vec_add(playerOrigin, playerViewOfs, startSnowballOrigin)
    
    set_entvar(snowballIndex, var_origin, startSnowballOrigin);
    set_entvar(snowballIndex, var_movetype, MOVETYPE_TOSS);
    set_entvar(snowballIndex, var_solid, SOLID_TRIGGER);
    set_entvar(snowballIndex, var_gravity, gravity);
    set_entvar(snowballIndex, var_sequence, 0);
    set_entvar(snowballIndex, var_framerate, 1.0);

    set_entvar(snowballIndex, var_owner, playerIndex);
    set_entvar(snowballIndex, var_dmg, damage);
    SetEntSize(snowballIndex, Float:{-2.0, -2.0, -2.0}, Float:{2.0, 2.0, 2.0});
    set_entvar(snowballIndex, var_nextthink, get_gametime() + 0.1);

    SetTouch(snowballIndex, "@OnSnowballTouch");
}

@OnSnowballTouch(const snowballIndex, const victimIndex) {
    new OwnerId = get_entvar(snowballIndex, var_owner);
    if (victimIndex == OwnerId) {
        return;
    }

    SetTouch(snowballIndex, "");
    SetThink(snowballIndex, "@OnSnowballThink");

    if (!FClassnameIs(victimIndex, "player")) {
        rh_emit_sound2(snowballIndex, 0, CHAN_AUTO, SNOWBALL_SOUND_MISS, 1.0);

        set_entvar(snowballIndex, var_solid, SOLID_NOT);
        set_entvar(snowballIndex, var_movetype, MOVETYPE_NONE);
        set_entvar(snowballIndex, var_nextthink, get_gametime() + KNIFE_STUCKED_TIME);
        set_entvar(snowballIndex, var_velocity, Float:{0.0, 0.0, 0.0});
        set_entvar(snowballIndex, var_avelocity, Float:{0.0, 0.0, 0.0});
        // TODO: менять body на вмазанный снежок
    } else {
        rh_emit_sound2(snowballIndex, 0, CHAN_AUTO, SNOWBALL_SOUND_HIT, 1.0);

        DamageBySnowball(victimIndex, OwnerId, snowballIndex);

        set_entvar(snowballIndex, var_nextthink, get_gametime() + 0.01);
    }
}

@OnSnowballThink(const EntId) {
    set_entvar(EntId, var_flags, FL_KILLME);
}

SetEntSize(const EntId, const Float:Mins[3], const Float:Maxs[3]) {
    set_entvar(EntId, var_mins, Mins);
    set_entvar(EntId, var_maxs, Maxs);

    new Float:Size[3];
    xs_vec_add(Mins, Maxs, Size);
    set_entvar(EntId, var_size, Size);
}