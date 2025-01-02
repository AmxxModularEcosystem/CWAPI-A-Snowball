#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <cwapi>

public stock const PluginName[] = "[CWAPI-A] Snowball";
public stock const PluginVersion[] = "1.0.0";
public stock const PluginAuthor[] = "ArKaNeMaN";
public stock const PluginURL[] = "https://github.com/AmxxModularEcosystem/CWAPI-A-Snowball";
public stock const PluginDescription[] = "[CustomWeaponsAPI-Ability] Snowball throwing.";

// TODO: Ассеты в сборке

#define SNOWBALL_MELT_TIME 3.0
new const SNOWBALL_CLASSNAME[] = "cwapi_a_snowball";
new const SNOWBALL_MODEL[] = "models/weapons/cwapi/Snowball/w_snowball.mdl";
new SNOWBALL_MODEL_INDEX;
new const SNOWBALL_STAIN_MODEL[] = "models/weapons/cwapi/Snowball/snowball_stain_byMayroN.mdl";
new SNOWBALL_STAIN_MODEL_INDEX;
new const SNOWBALL_GIBS_MODEL[] = "models/weapons/cwapi/Snowball/snowball_gibs_byMayroN.mdl";
new SNOWBALL_GIBS_MODEL_INDEX;
new const SNOWBALL_TRAIL_SPRITE[] = "sprites/smoke.spr";
new SNOWBALL_TRAIL_SPRITE_INDEX;
new const SNOWBALL_SOUND_HIT[] = "weapons/cwapi/Snowball/byMayroN/hit.wav";
new const SNOWBALL_SOUND_MISS[] = "weapons/cwapi/Snowball/byMayroN/miss.wav";

new const ABILITY_NAME[] = "Snowball";

public plugin_precache() {
    SNOWBALL_MODEL_INDEX = precache_model(SNOWBALL_MODEL);
    SNOWBALL_STAIN_MODEL_INDEX = precache_model(SNOWBALL_STAIN_MODEL);
    SNOWBALL_TRAIL_SPRITE_INDEX = precache_model(SNOWBALL_TRAIL_SPRITE);
    SNOWBALL_GIBS_MODEL_INDEX = precache_model(SNOWBALL_GIBS_MODEL);

    precache_sound(SNOWBALL_SOUND_HIT);
    precache_sound(SNOWBALL_SOUND_MISS);
}

public CWAPI_OnLoad() {
    register_plugin(PluginName, PluginVersion, PluginAuthor);
    
    new T_WeaponAbility:ability = CWAPI_Abilities_Register(ABILITY_NAME);
    CWAPI_Abilities_AddParams(ability,
        "Damage", "Float", true,
        "Speed", "Float", false,
        "Gravity", "Float", false,
        "WithTrail", "Boolean", false
    );

    CWAPI_Abilities_AddEventListener(ability, CWeapon_OnPlayerThrowGrenade, "@OnPlayerThrowGrenade");
}

@OnPlayerThrowGrenade(const T_CustomWeapon:weapon, const itemIndex, const playerIndex, Float:vecSrc[3], Float:vecThrow[3], &Float:time, const event, const Trie:abilityParams) {
    new Float:damage;
    TrieGetCell(abilityParams, "Damage", damage);

    new Float:speed = 1500.0;
    TrieGetCell(abilityParams, "Speed", speed);

    new Float:gravity = 0.5;
    TrieGetCell(abilityParams, "Gravity", gravity);

    new bool:withTrail = false;
    TrieGetCell(abilityParams, "WithTrail", withTrail);

    new snowballIndex = ThrowSnowball(playerIndex, weapon, damage, speed, gravity);

    if (withTrail) {
        message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
        write_byte(TE_BEAMFOLLOW);
        write_short(snowballIndex); // Entity index
        write_short(SNOWBALL_TRAIL_SPRITE_INDEX); // Sprite index
        write_byte(20); // Life time
        write_byte(3); // Width
        write_byte(115); // R
        write_byte(155); // G
        write_byte(208); // B
        write_byte(255); // Brightness
        message_end();
    }

    return CWAPI_STOP_MAIN;
}

// https://github.com/AmxxModularEcosystem/CWAPI-A-ThrowKnife/blob/master/amxmodx/scripting/CWAPI-A-ThrowKnife.sma

ThrowSnowball(
    const playerIndex,
    const T_CustomWeapon:weaponIndex,
    const Float:damage = 45.0,
    const Float:velocity = 1500.0,
    const Float:gravity = 0.5
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

    set_entvar(snowballIndex, var_angles, playerViewAngle);

    new Float:startSnowballOrigin[3];
    xs_vec_add(playerOrigin, playerViewOfs, startSnowballOrigin)
    
    set_entvar(snowballIndex, var_origin, startSnowballOrigin);
    set_entvar(snowballIndex, var_movetype, MOVETYPE_TOSS);
    set_entvar(snowballIndex, var_solid, SOLID_TRIGGER);
    set_entvar(snowballIndex, var_gravity, gravity);
    set_entvar(snowballIndex, var_sequence, 0);
    set_entvar(snowballIndex, var_framerate, 1.0);

    set_entvar(snowballIndex, var_owner, playerIndex);
    set_entvar(snowballIndex, var_impulse, weaponIndex);
    set_entvar(snowballIndex, var_dmg, damage);
    SetEntSize(snowballIndex, Float:{-2.0, -2.0, -2.0}, Float:{2.0, 2.0, 2.0});
    set_entvar(snowballIndex, var_nextthink, get_gametime() + 0.1);

    SetTouch(snowballIndex, "@OnSnowballTouch");

    return snowballIndex;
}

DamageBySnowball(const victimIndex, const attackerIndex, const snowballIndex) {
    if (!is_user_alive(victimIndex)) {
        return;
    }

    new Float:snowballDamage = get_entvar(snowballIndex, var_dmg);
    new T_CustomWeapon:weaponIndex = get_entvar(snowballIndex, var_impulse);

    if (rg_is_player_can_takedamage(victimIndex, attackerIndex)) {
        CWAPI_Weapons_EmitDamage(weaponIndex, victimIndex, snowballIndex, attackerIndex, snowballDamage, DMG_FREEZE|DMG_NEVERGIB|DMG_PARALYZE);
    }
}

@OnSnowballTouch(const snowballIndex, const victimIndex) {
    new OwnerId = get_entvar(snowballIndex, var_owner);
    if (victimIndex == OwnerId) {
        return;
    }

    SetTouch(snowballIndex, "");
    SetThink(snowballIndex, "@OnSnowballThink");

    new Float:snowballOrigin[3];
    get_entvar(snowballIndex, var_origin, snowballOrigin);

    if (FClassnameIs(victimIndex, "player")) {
        rh_emit_sound2(snowballIndex, 0, CHAN_AUTO, SNOWBALL_SOUND_HIT, 1.0);
        rh_emit_sound2(snowballIndex, 0, CHAN_AUTO, SNOWBALL_SOUND_MISS, 0.5);

        DamageBySnowball(victimIndex, OwnerId, snowballIndex);

        set_entvar(snowballIndex, var_nextthink, get_gametime() + 0.01);
    } else {
        rh_emit_sound2(snowballIndex, 0, CHAN_AUTO, SNOWBALL_SOUND_MISS, 1.0);

        set_entvar(snowballIndex, var_solid, SOLID_NOT);
        set_entvar(snowballIndex, var_movetype, MOVETYPE_NONE);
        set_entvar(snowballIndex, var_nextthink, get_gametime() + SNOWBALL_MELT_TIME);
        set_entvar(snowballIndex, var_velocity, Float:{0.0, 0.0, 0.0});

        new Float:snowballDirection[3];
        get_entvar(snowballIndex, var_angles, snowballDirection);
        angle_vector(snowballDirection, ANGLEVECTOR_FORWARD, snowballDirection);
        xs_vec_normalize(snowballDirection, snowballDirection);
        xs_vec_mul_scalar(snowballDirection, 10.0, snowballDirection);

        new Float:traceToOrigin[3];
        xs_vec_add(snowballOrigin, snowballDirection, traceToOrigin);

        new traceResult;
        engfunc(EngFunc_TraceLine, snowballOrigin, traceToOrigin, IGNORE_MONSTERS, snowballIndex, traceResult);

        new Float:normalToSurface[3];
        get_tr2(traceResult, TR_vecPlaneNormal, normalToSurface);

        vector_to_angle(normalToSurface, normalToSurface);
        
        set_entvar(snowballIndex, var_modelindex, SNOWBALL_STAIN_MODEL_INDEX);
        set_entvar(snowballIndex, var_model, SNOWBALL_STAIN_MODEL);
        set_entvar(snowballIndex, var_angles, normalToSurface);
    }
    
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY, {0,0,0}, 0);
    {
        write_byte(TE_BREAKMODEL);
        write_coord_f(snowballOrigin[0]); // x
        write_coord_f(snowballOrigin[1]); // y
        write_coord_f(snowballOrigin[2]); // z
        write_coord_f(16.0); // size x
        write_coord_f(16.0); // size y
        write_coord_f(16.0); // size z
        write_coord(15); // velocity x
        write_coord(15); // velocity y
        write_coord(15); // velocity z
        write_byte(10); // random velocity
        write_short(SNOWBALL_GIBS_MODEL_INDEX); // model index that you want to break
        write_byte(random_num(5, 10)); // count
        write_byte(5); // life
        write_byte(BREAK_2); // flags
    }
    message_end();
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