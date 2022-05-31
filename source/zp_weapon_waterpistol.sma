/**
 * Weapon by xUnicorn (t3rkecorejz) 
 *
 * Thanks a lot:
 *
 * Chrescoe1 & batcoh (Phenix) — First base code
 * KORD_12.7 & 406 (Nightfury) — I'm taken some functions from this authors
 * D34, 404 & fl0wer — Some help
 * 
 * ┌[ Latest versions of API's ]
 * │
 * ├─┬─[ API: Dynamic Crosshair ]
 * │ └─ https://github.com/YoshiokaHaruki/AMXX-Dynamic-Crosshair/releases
 * │
 * ├─┬─[ API: Muzzle-Flash ]
 * │ └─ https://github.com/YoshiokaHaruki/AMXX-API-Muzzle-Flash/releases
 * │
 * └─┬─[ API: Smoke WallPuff ]
 *   └─ https://github.com/YoshiokaHaruki/AMXX-API-Smoke-WallPuff/releases
 */

public stock const PluginName[ ] =		"[ZP] Weapon: Lightning BIG-EYE";
public stock const PluginVersion[ ] =	"1.0";
public stock const PluginAuthor[ ] =	"Yoshioka Haruki";

/* ~ [ Includes ]~ */
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <zombieplague>
#include <xs>
#include <reapi>

#include <api_muzzleflash>
#include <api_smokewallpuff>
#include <api_dynamic_crosshair>

/* ~ [ Extra Item ] ~ */
#if defined _zombieplague_included
	new const ExtraItem_Name[ ] =		"Pistol: Iguana"; // Can comment this line
	const ExtraItem_Cost =				0;
#endif

/* ~ [ Weapon Settings ] ~ */
const WeaponHandSubmodel =				0; // Hand Submodel (0: Male / 1: Female)
const WeaponUnicalIndex =				31052022;
new const WeaponName[ ] =				"Iguana";
new const WeaponReference[ ] =			"weapon_p228";
new const WeaponListDir[ ] =			"x_re/weapon_waterpistol"; // Can comment this line
new const WeaponAnimation[ ] =			"onehanded";
new const WeaponNative[ ] =				"zp_give_user_waterpistol";
new const WeaponModelView[ ] =			"models/x_re/v_waterpistol.mdl";
new const WeaponModelPlayer[ ] =		"models/x_re/p_waterpistol.mdl";
new const WeaponModelWorld[ ] =			"models/x_re/w_waterpistol.mdl";
new const WeaponSounds[ ][ ] = {
	"weapons/water-1.wav"
};

const ModelWorldBody =					0;

const WeaponMaxClip =					40;
const WeaponDefaultAmmo =				120;
const WeaponMaxAmmo =					160;

#define UseCustomAmmoIndex				// Comment this line if u dont need custom ammo index
#if defined UseCustomAmmoIndex
	const WeaponAmmoIndex =				16;
	new const WeaponAmmoName[ ] =		"ammo_h2o";
#endif

const WeaponDamage =					31;
const WeaponShotPenetration =			1;
const Bullet: WeaponBulletType =		BULLET_PLAYER_9MM;
const Float: WeaponShotDistance =		4096.0;
const Float: WeaponRate =				0.0955;
const Float: WeaponAccuracy =			0.9;
const Float: WeaponRangeModifier =		0.8;

/* ~ [ Muzzle Flash ] ~ */
#if defined _api_muzzleflash_included
	new const MuzzleFlashSprite[ ] =	"sprites/x_re/muzzleflash11_fx.spr";
#endif

/* ~ [ Weapon Animations ] ~ */
enum {
	WeaponAnim_Idle = 0,
	WeaponAnim_Shoot1,
	WeaponAnim_Shoot2,
	WeaponAnim_ShootEmpty,
	WeaponAnim_Reload,
	WeaponAnim_Draw,
	WeaponAnim_Dummy
};

const Float: WeaponAnim_Idle_Time =		3.4;
const Float: WeaponAnim_Shoot_Time =	1.0;
const Float: WeaponAnim_Reload_Time =	2.2;
const Float: WeaponAnim_Draw_Time =		1.6;

/* ~ [ Params ] ~ */
enum eModelIndex {
	ModelIndex_Bubbles,
	ModelIndex_Gibs
};
new gl_iszModelIndex[ eModelIndex ];

#if defined _zombieplague_included && defined ExtraItem_Name
	new gl_iItemId;
#endif
#if defined _api_muzzleflash_included
	new MuzzleFlash: gl_iMuzzleId;
#endif
new gl_bitUserLeftHanded;
new HookChain: gl_HookChain_IsPenetrableEntity_Post;

/* ~ [ Macroses ] ~ */
#define Vector3(%0)						Float: %0[ 3 ]
#define IsCustomWeapon(%0,%1)			bool: ( get_entvar( %0, var_impulse ) == %1 )
#define GetWeaponClip(%0)				get_member( %0, m_Weapon_iClip )
#define SetWeaponClip(%0,%1)			set_member( %0, m_Weapon_iClip, %1 )
#define GetWeaponAmmoType(%0)			get_member( %0, m_Weapon_iPrimaryAmmoType )
#define GetWeaponAmmo(%0,%1)			get_member( %0, m_rgAmmo, %1 )
#define SetWeaponAmmo(%0,%1,%2)			set_member( %0, m_rgAmmo, %1, %2 )

#define BIT_ADD(%0,%1)					( %0 |= %1 )
#define BIT_SUB(%0,%1)					( %0 &= ~%1 )
#define BIT_VALID(%0,%1)				( %0 & %1 )

/* ~ [ AMX Mod X ] ~ */
public plugin_natives( ) register_native( WeaponNative, "native_give_user_weapon" );
public plugin_precache( ) 
{
	new iFile;

	/* -> Precache Models -> */
	engfunc( EngFunc_PrecacheModel, WeaponModelView );
	engfunc( EngFunc_PrecacheModel, WeaponModelPlayer );
	engfunc( EngFunc_PrecacheModel, WeaponModelWorld );

	#if defined _api_muzzleflash_included
		gl_iMuzzleId = zc_muzzle_init( );
		{
			zc_muzzle_set_property( gl_iMuzzleId, ZC_MUZZLE_SPRITE, MuzzleFlashSprite );
			zc_muzzle_set_property( gl_iMuzzleId, ZC_MUZZLE_SCALE, 0.12 );
			zc_muzzle_set_property( gl_iMuzzleId, ZC_MUZZLE_FRAMERATE_MLT, 0.3 );
		}
	#endif

	/* -> Precache Sounds -> */
	for ( iFile = 0; iFile < sizeof WeaponSounds; iFile++ )
		engfunc( EngFunc_PrecacheSound, WeaponSounds[ iFile ] );

	#if defined WeaponListDir
		/* -> Hook Weapon -> */
		register_clcmd( WeaponListDir, "ClientCommand__HookWeapon" );

		UTIL_PrecacheWeaponList( WeaponListDir );
	#endif

	/* -> Model Index -> */
	gl_iszModelIndex[ ModelIndex_Bubbles ] = engfunc( EngFunc_PrecacheModel, "sprites/bubble.spr" );
	gl_iszModelIndex[ ModelIndex_Gibs ] = engfunc( EngFunc_PrecacheModel, "sprites/x_re/blueflare2.spr" );
}

public plugin_init( ) 
{
	// https://cso.fandom.com/wiki/Lightning_BIG-EYE
	register_plugin( PluginName, PluginVersion, PluginAuthor );

	/* -> Fakemeta -> */
	register_forward( FM_UpdateClientData, "FM_Hook_UpdateClientData_Post", true );

	/* -> ReAPI -> */
	RegisterHookChain( RG_CWeaponBox_SetModel, "RG_CWeaponBox__SetModel_Pre", false );
	DisableHookChain( gl_HookChain_IsPenetrableEntity_Post = RegisterHookChain( RG_IsPenetrableEntity, "RG_IsPenetrableEntity_Post", true ) );

	/* -> HamSandwich -> */
	RegisterHam( Ham_Spawn, WeaponReference, "Ham_CBasePlayerWeapon__Spawn_Post", true );
	RegisterHam( Ham_Item_Deploy, WeaponReference, "Ham_CBasePlayerWeapon__Deploy_Post", true );
	RegisterHam( Ham_Item_Holster, WeaponReference, "Ham_CBasePlayerWeapon__Holster_Post", true );
	#if defined UseCustomAmmoIndex
		RegisterHam( Ham_Item_AddToPlayer, WeaponReference, "Ham_CBasePlayerWeapon__AddToPlayer_Pre", false );
	#endif
	RegisterHam( Ham_Item_AddToPlayer, WeaponReference, "Ham_CBasePlayerWeapon__AddToPlayer_Post", true );
	RegisterHam( Ham_Item_PostFrame, WeaponReference, "Ham_CBasePlayerWeapon__PostFrame_Pre", false );
	#if defined UseCustomAmmoIndex
		RegisterHam( Ham_Weapon_Reload, WeaponReference, "Ham_CBasePlayerWeapon__Reload_Pre", false );
	#endif
	RegisterHam( Ham_Weapon_Reload, WeaponReference, "Ham_CBasePlayerWeapon__Reload_Post", true );
	RegisterHam( Ham_Weapon_WeaponIdle, WeaponReference, "Ham_CBasePlayerWeapon__WeaponIdle_Pre", false );
	RegisterHam( Ham_Weapon_PrimaryAttack, WeaponReference, "Ham_CBasePlayerWeapon__PrimaryAttack_Pre", false );

	/* -> Register on Extra-Items -> */
	#if defined _zombieplague_included && defined ExtraItem_Name
		gl_iItemId = zp_register_extra_item( ExtraItem_Name, ExtraItem_Cost, ZP_TEAM_HUMAN );
	#endif
}

public bool: native_give_user_weapon( ) 
{
	enum { arg_player = 1 };

	static pPlayer; pPlayer = get_param( arg_player );
	if ( !is_user_alive( pPlayer ) )
		return false;

	static iDefaultAmmo;
	#if defined UseCustomAmmoIndex
		iDefaultAmmo = 0;
	#else
		iDefaultAmmo = WeaponDefaultAmmo;
	#endif

	return UTIL_GiveCustomWeapon( pPlayer, WeaponReference, WeaponUnicalIndex, iDefaultAmmo );
}

public client_putinserver( pPlayer )
{
	if ( !is_user_bot( pPlayer ) )
		query_client_cvar( pPlayer, "cl_righthand", "CBasePlayer__CheckLeftHand" );
}

public client_disconnected( pPlayer ) BIT_SUB( gl_bitUserLeftHanded, BIT( pPlayer ) );

#if defined WeaponListDir
	public ClientCommand__HookWeapon( const pPlayer ) 
	{
		engclient_cmd( pPlayer, WeaponReference );
		return PLUGIN_HANDLED;
	}
#endif

/* ~ [ Zombie Plague ] ~ */
#if defined _zombieplague_included && defined ExtraItem_Name
	public zp_extra_item_selected( pPlayer, iItemId ) 
	{
		if ( iItemId != gl_iItemId ) 
			return PLUGIN_HANDLED;

		static iDefaultAmmo;
		#if defined UseCustomAmmoIndex
			iDefaultAmmo = 0;
		#else
			iDefaultAmmo = WeaponDefaultAmmo;
		#endif

		return UTIL_GiveCustomWeapon( pPlayer, WeaponReference, WeaponUnicalIndex, iDefaultAmmo ) ? PLUGIN_CONTINUE : ZP_PLUGIN_HANDLED;
	}
#endif

/* ~ [ Fakemeta ] ~ */
public FM_Hook_UpdateClientData_Post( const pPlayer, const iSendWeapons, const CD_Handle ) 
{
	static iSpecMode, pTarget;
	pTarget = ( iSpecMode = get_entvar( pPlayer, var_iuser1 ) ) ? get_entvar( pPlayer, var_iuser2 ) : pPlayer;

	if ( !is_user_connected( pTarget ) )
		return;

	static pActiveItem; pActiveItem = get_member( pTarget, m_pActiveItem );
	if ( is_nullent( pActiveItem ) || !IsCustomWeapon( pActiveItem, WeaponUnicalIndex ) )
		return;

	set_cd( CD_Handle, CD_flNextAttack, 2.0 );

	enum eSpecInfo {
		SPEC_MODE,
		SPEC_TARGET
	};
	static aSpecInfo[ MAX_PLAYERS + 1 ][ eSpecInfo ];

	if ( iSpecMode )
	{
		if ( aSpecInfo[ pPlayer ][ SPEC_MODE ] != iSpecMode )
		{
			aSpecInfo[ pPlayer ][ SPEC_MODE ] = iSpecMode;
			aSpecInfo[ pPlayer ][ SPEC_TARGET ] = 0;
		}

		if ( iSpecMode == OBS_IN_EYE && aSpecInfo[ pPlayer ][ SPEC_TARGET ] != pTarget )
			aSpecInfo[ pPlayer ][ SPEC_TARGET ] = pTarget;
	}

	static Float: flLastEventCheck; flLastEventCheck = get_member( pActiveItem, m_flLastEventCheck );
	if ( !flLastEventCheck )
	{
		set_cd( CD_Handle, CD_WeaponAnim, WeaponAnim_Dummy );
		return;
	}

	if ( flLastEventCheck <= get_gametime( ) )
	{
		UTIL_SendWeaponAnim( MSG_ONE, pTarget, pActiveItem, WeaponAnim_Draw );
		set_member( pActiveItem, m_flLastEventCheck, 0.0 );
	}
}

/* ~ [ ReAPI ] ~ */
public RG_CWeaponBox__SetModel_Pre( const pWeaponBox, const szModel[ ] ) 
{
	static pItem; pItem = UTIL_GetWeaponBoxItem( pWeaponBox );
	if ( pItem == NULLENT || !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HC_CONTINUE;

	SetHookChainArg( 2, ATYPE_STRING, WeaponModelWorld );
	set_entvar( pWeaponBox, var_body, ModelWorldBody );

	return HC_CONTINUE;
}

public RG_IsPenetrableEntity_Post( const Vector3( vecStart ), Vector3( vecEnd ), const pPlayer, const pHit )
{
	static iPointContents; iPointContents = engfunc( EngFunc_PointContents, vecEnd );
	if ( iPointContents == CONTENTS_SKY )
		return;

	if ( pHit && is_nullent( pHit ) || ( get_entvar( pHit, var_flags ) & FL_KILLME ) )
		return;

	CBasePlayerWeapon__DrawEffects( pPlayer, vecEnd );

	if ( !ExecuteHam( Ham_IsBSPModel, pHit ) )
		return;

	UTIL_GunshotDecalTrace( pHit, vecEnd );

	if ( iPointContents == CONTENTS_WATER )
		return;

	static Vector3( vecPlaneNormal ); global_get( glb_trace_plane_normal, vecPlaneNormal );

	#if defined _api_smokewallpuff_included
		zc_smoke_wallpuff_draw( vecEnd, vecPlaneNormal );
	#endif

	xs_vec_mul_scalar( vecPlaneNormal, random_float( 25.0, 30.0 ), vecPlaneNormal );
	message_begin_f( MSG_PAS, SVC_TEMPENTITY, vecEnd );
	UTIL_TE_STREAK_SPLASH( vecEnd, vecPlaneNormal, 4, random_num( 10, 20 ), 3, 64 );
}
 
/* ~ [ HamSandwich ] ~ */
public Ham_CBasePlayerWeapon__Spawn_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	SetWeaponClip( pItem, WeaponMaxClip );
	set_member( pItem, m_Weapon_iDefaultAmmo, WeaponDefaultAmmo );
	set_member( pItem, m_Weapon_bHasSecondaryAttack, false );

	#if defined UseCustomAmmoIndex
		set_member( pItem, m_Weapon_iPrimaryAmmoType, WeaponAmmoIndex );
		rg_set_iteminfo( pItem, ItemInfo_pszAmmo1, WeaponAmmoName );
	#endif

	#if defined WeaponListDir
		rg_set_iteminfo( pItem, ItemInfo_pszName, WeaponListDir );
	#endif

	rg_set_iteminfo( pItem, ItemInfo_iMaxClip, WeaponMaxClip );
	rg_set_iteminfo( pItem, ItemInfo_iMaxAmmo1, WeaponMaxAmmo );

	set_entvar( pItem, var_netname, WeaponName );
}

public Ham_CBasePlayerWeapon__Deploy_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	static pPlayer; pPlayer = get_member( pItem, m_pPlayer );

	set_entvar( pPlayer, var_viewmodel, WeaponModelView );
	set_entvar( pPlayer, var_weaponmodel, WeaponModelPlayer );
	set_entvar( pItem, var_body, WeaponHandSubmodel );

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, WeaponAnim_Dummy );

	set_member( pItem, m_flLastEventCheck, get_gametime( ) + 0.1 );
	set_member( pItem, m_Weapon_flAccuracy, WeaponAccuracy );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Draw_Time + 0.1 );
	set_member( pPlayer, m_flNextAttack, WeaponAnim_Draw_Time );
	set_member( pPlayer, m_szAnimExtention, WeaponAnimation );
}

public Ham_CBasePlayerWeapon__Holster_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	static pPlayer; pPlayer = get_member( pItem, m_pPlayer );

	if ( is_user_connected( pPlayer ) && !is_user_bot( pPlayer ) )
		query_client_cvar( pPlayer, "cl_righthand", "CBasePlayer__CheckLeftHand" );

	#if defined _api_muzzleflash_included
		zc_muzzle_destroy( pPlayer, gl_iMuzzleId );
	#endif
	
	set_member( pItem, m_Weapon_iGlock18ShotsFired, 0 );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, 1.0 );
	set_member( pPlayer, m_flNextAttack, 1.0 );
}

#if defined UseCustomAmmoIndex
	public Ham_CBasePlayerWeapon__AddToPlayer_Pre( const pItem, const pPlayer ) 
	{
		if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
			return HAM_IGNORED;

		if ( get_entvar( pItem, var_owner ) == -1 )
		{
			static iAmmoType; iAmmoType = GetWeaponAmmoType( pItem );
			static iAmmo; iAmmo = GetWeaponAmmo( pPlayer, iAmmoType );

			SetWeaponAmmo( pPlayer, WeaponDefaultAmmo, iAmmoType );
			UTIL_AmmoPickup( MSG_ONE, pPlayer, iAmmoType, min( WeaponDefaultAmmo, WeaponDefaultAmmo - iAmmo ) );
		}

		// This is for save ammo in 'weaponbox' entity
		else
		{
			static iDefaultAmmo;
			if ( ( iDefaultAmmo = get_member( pItem, m_Weapon_iDefaultAmmo ) ) )
			{
				static iAmmoType; iAmmoType = GetWeaponAmmoType( pItem );

				SetWeaponAmmo( pPlayer, iDefaultAmmo, iAmmoType );
				UTIL_AmmoPickup( MSG_ONE, pPlayer, iAmmoType, iDefaultAmmo );
			}
		}

		return HAM_IGNORED;
	}
#endif

public Ham_CBasePlayerWeapon__AddToPlayer_Post( const pItem, const pPlayer )
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	UTIL_WeaponList( MSG_ONE, pPlayer, pItem );
}

public Ham_CBasePlayerWeapon__PostFrame_Pre( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	static pPlayer; pPlayer = get_member( pItem, m_pPlayer );

	// Burst fire
	static iGlock18ShotsFired;
	if ( ( iGlock18ShotsFired = get_member( pItem, m_Weapon_iGlock18ShotsFired ) ) )
	{
		static iClip; iClip = GetWeaponClip( pItem );
		if ( iClip )
		{
			if ( ++iGlock18ShotsFired >= 5 )
				iGlock18ShotsFired = 0;

			CBasePlayerWeapon__Fire( pPlayer, pItem, iClip, WeaponRate + Float: ( ( !iGlock18ShotsFired ) ? 0.2 : 0.0 ) );
			set_member( pPlayer, m_flNextAttack, WeaponRate );
		}
		else iGlock18ShotsFired = 0;

		set_member( pItem, m_Weapon_iGlock18ShotsFired, iGlock18ShotsFired );
	}

	#if defined _api_dynamic_crosshair_included
		UTIL_ResetCrosshair( pPlayer, pItem );
	#endif

	return HAM_IGNORED;
}

#if defined UseCustomAmmoIndex
	public Ham_CBasePlayerWeapon__Reload_Pre( const pItem )
	{
		if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
			return HAM_IGNORED;

		set_member( pItem, m_Weapon_fInReload, true );
		return HAM_SUPERCEDE;
	}
#endif

public Ham_CBasePlayerWeapon__Reload_Post( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return;

	static pPlayer; pPlayer = get_member( pItem, m_pPlayer );
	if ( !GetWeaponAmmo( pPlayer, GetWeaponAmmoType( pItem ) ) )
		return;

	if ( GetWeaponClip( pItem ) >= rg_get_iteminfo( pItem, ItemInfo_iMaxClip ) )
		return;

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, WeaponAnim_Reload );
	#if defined UseCustomAmmoIndex
		rg_set_animation( pPlayer, PLAYER_RELOAD );
	#endif

	set_member( pPlayer, m_flNextAttack, WeaponAnim_Reload_Time );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Reload_Time );
}

public Ham_CBasePlayerWeapon__WeaponIdle_Pre( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) || get_member( pItem, m_Weapon_flTimeWeaponIdle ) > 0.0 )
		return HAM_IGNORED;

	static pPlayer; pPlayer = get_member( pItem, m_pPlayer );

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, WeaponAnim_Idle );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Idle_Time );

	return HAM_SUPERCEDE;
}

public Ham_CBasePlayerWeapon__PrimaryAttack_Pre( const pItem ) 
{
	if ( !IsCustomWeapon( pItem, WeaponUnicalIndex ) )
		return HAM_IGNORED;

	if ( get_member( pItem, m_Weapon_iGlock18ShotsFired ) )
		return HAM_SUPERCEDE;

	static iClip; iClip = GetWeaponClip( pItem );
	if ( !iClip )
	{
		ExecuteHam( Ham_Weapon_PlayEmptySound, pItem );
		set_member( pItem, m_Weapon_flNextPrimaryAttack, 0.2 );

		return HAM_SUPERCEDE;
	}

	static pPlayer; pPlayer = get_member( pItem, m_pPlayer );

	CBasePlayerWeapon__Fire( pPlayer, pItem, iClip, WeaponRate );

	set_member( pPlayer, m_flNextAttack, WeaponRate );
	set_member( pItem, m_Weapon_iGlock18ShotsFired, 1 );

	return HAM_SUPERCEDE;
}

/* ~ [ Other ] ~ */
public CBasePlayer__CheckLeftHand( const pPlayer, const szCvar[ ], const szValue[ ] )
{
	( equal( szValue, "0" ) ) ? BIT_ADD( gl_bitUserLeftHanded, BIT( pPlayer ) ) : BIT_SUB( gl_bitUserLeftHanded, BIT( pPlayer ) );
}

public CBasePlayerWeapon__Fire( const pPlayer, const pItem, iClip, const Float: flNextAttack )
{
	static Float: flGameTime; flGameTime = get_gametime( );
	static Float: flLastFire; flLastFire = get_member( pItem, m_Weapon_flLastFire );
	static Float: flAccuracy; flAccuracy = get_member( pItem, m_Weapon_flAccuracy );
	static Float: flSpread; flSpread = UTIL_GetSpreadByAction( pPlayer, Float: { 1.5, 0.225, 0.075, 0.15 }, 0.0 );
	flSpread *= ( 1.0 - flAccuracy );

	if ( flLastFire != 0.0 )
	{
		flAccuracy -= ( 0.325 - ( flGameTime - flLastFire ) ) * 0.3;
		flAccuracy = floatclamp( flAccuracy, 0.6, 0.9 );
	}

	static Vector3( vecSrc ); UTIL_GetEyePosition( pPlayer, vecSrc );
	static Vector3( vecAiming ); UTIL_GetVectorAiming( pPlayer, vecAiming );

	EnableHookChain( gl_HookChain_IsPenetrableEntity_Post );
	rg_fire_bullets3( pItem, pPlayer, vecSrc, vecAiming, flSpread, WeaponShotDistance, WeaponShotPenetration, WeaponBulletType, WeaponDamage, WeaponRangeModifier, true, get_member( pPlayer, random_seed ) );
	DisableHookChain( gl_HookChain_IsPenetrableEntity_Post );

	#if defined _api_muzzleflash_included
		zc_muzzle_draw( pPlayer, gl_iMuzzleId );
	#endif

	#if defined _api_dynamic_crosshair_included
		UTIL_IncreaseCrosshair( pPlayer, pItem );
	#endif

	UTIL_SendWeaponAnim( MSG_ONE, pPlayer, pItem, random_num( WeaponAnim_Shoot1, WeaponAnim_Shoot2 ) );
	rg_set_animation( pPlayer, PLAYER_ATTACK1 );
	rh_emit_sound2( pPlayer, 0, CHAN_WEAPON, WeaponSounds[ 0 ] );

	static Vector3( vecPunchAngle ); get_entvar( pPlayer, var_punchangle, vecPunchAngle );
	vecPunchAngle[ 0 ] -= 2.0;
	set_entvar( pPlayer, var_punchangle, vecPunchAngle );

	SetWeaponClip( pItem, --iClip );
	set_member( pItem, m_Weapon_flAccuracy, flAccuracy );
	set_member( pItem, m_Weapon_flLastFire, flGameTime );
	set_member( pItem, m_Weapon_flTimeWeaponIdle, WeaponAnim_Shoot_Time );
	set_member( pItem, m_Weapon_flNextPrimaryAttack, flNextAttack );
	set_member( pItem, m_Weapon_flNextSecondaryAttack, flNextAttack );
}

public CBasePlayerWeapon__DrawEffects( const pPlayer, const Vector3( vecEnd ) )
{
	static pActiveItem;
	if ( ( pActiveItem = get_member( pPlayer, m_pActiveItem ) ) && !IsCustomWeapon( pActiveItem, WeaponUnicalIndex ) )
		return;

	static Vector3( vecSrc );
	UTIL_GetWeaponPosition( pPlayer, 25.0, 5.0 * ( BIT_VALID( gl_bitUserLeftHanded, BIT( pPlayer ) ) ? -1.0 : 1.0 ), -7.5, vecSrc );

	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	UTIL_TE_BUBBLETRAIL( vecSrc, vecEnd, 64, gl_iszModelIndex[ ModelIndex_Bubbles ], 32, 16 );

	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	UTIL_TE_SPRITETRAIL( vecEnd, vecSrc, gl_iszModelIndex[ ModelIndex_Gibs ], clamp( floatround( xs_vec_distance_2d( vecSrc, vecEnd ) / 64.0 ), 4, 20 ), 1, 1, 16, 24 );
}

/* ~ [ Stocks ] ~ */

/* -> Give Custom Item <- */
stock bool: UTIL_GiveCustomWeapon( const pPlayer, const szWeaponReference[ ], const iWeaponUId, const iDefaultAmmo, &pItem = NULLENT )
{
	pItem = rg_give_custom_item( pPlayer, szWeaponReference, GT_DROP_AND_REPLACE, iWeaponUId );
	if ( is_nullent( pItem ) )
		return false;

	if ( iDefaultAmmo )
	{
		new iAmmoType = GetWeaponAmmoType( pItem );
		if ( GetWeaponAmmo( pPlayer, iAmmoType ) > iDefaultAmmo )
			SetWeaponAmmo( pPlayer, iDefaultAmmo, iAmmoType );
	}

	return true;
}

/* -> Weapon Animation <- */
stock UTIL_SendWeaponAnim( const iDest, const pReceiver, const pItem, const iAnim ) 
{
	static iBody; iBody = get_entvar( pItem, var_body );
	set_entvar( pReceiver, var_weaponanim, iAnim );

	message_begin( iDest, SVC_WEAPONANIM, .player = pReceiver );
	write_byte( iAnim );
	write_byte( iBody );
	message_end( );

	if ( get_entvar( pReceiver, var_iuser1 ) )
		return;

	static i, iCount, pSpectator, aSpectators[ MAX_PLAYERS ];
	get_players( aSpectators, iCount, "bch" );

	for ( i = 0; i < iCount; i++ )
	{
		pSpectator = aSpectators[ i ];

		if ( get_entvar( pSpectator, var_iuser1 ) != OBS_IN_EYE )
			continue;

		if ( get_entvar( pSpectator, var_iuser2 ) != pReceiver )
			continue;

		set_entvar( pSpectator, var_weaponanim, iAnim );

		message_begin( iDest, SVC_WEAPONANIM, .player = pSpectator );
		write_byte( iAnim );
		write_byte( iBody );
		message_end( );
	}
}

/* -> Get Vector Aiming <- */
stock UTIL_GetVectorAiming( const pPlayer, Vector3( vecAiming ) ) 
{
	static Vector3( vecViewAngle ); get_entvar( pPlayer, var_v_angle, vecViewAngle );
	static Vector3( vecPunchangle ); get_entvar( pPlayer, var_punchangle, vecPunchangle );

	xs_vec_add( vecViewAngle, vecPunchangle, vecViewAngle );
	angle_vector( vecViewAngle, ANGLEVECTOR_FORWARD, vecAiming );
}

/* -> Get player eye position <- */
stock UTIL_GetEyePosition( const pPlayer, Vector3( vecEyeLevel ) )
{
	static Vector3( vecOrigin ); get_entvar( pPlayer, var_origin, vecOrigin );
	static Vector3( vecViewOfs ); get_entvar( pPlayer, var_view_ofs, vecViewOfs );

	xs_vec_add( vecOrigin, vecViewOfs, vecEyeLevel );
}

/* -> Get Weapon Position <- */
stock UTIL_GetWeaponPosition( const pPlayer, const Float: flForward, const Float: flRight, const Float: flUp, Vector3( vecStart ) ) 
{
	static Vector3( vecOrigin ); UTIL_GetEyePosition( pPlayer, vecOrigin );

	static Vector3( vecViewAngle ); get_entvar( pPlayer, var_v_angle, vecViewAngle );
	static Vector3( vecForward ), Vector3( vecRight ), Vector3( vecUp );
	engfunc( EngFunc_AngleVectors, vecViewAngle, vecForward, vecRight, vecUp );

	xs_vec_add_scaled( vecOrigin, vecForward, flForward, vecOrigin );
	xs_vec_add_scaled( vecOrigin, vecRight, flRight, vecOrigin );
	xs_vec_add_scaled( vecOrigin, vecUp, flUp, vecOrigin );
	xs_vec_copy( vecOrigin, vecStart );
}

/* -> Get weapon Spread by Action <- */
stock Float: UTIL_GetSpreadByAction( const pPlayer, const Float: flSpreadInActions[ 4 ], const Float: flMoveSpeed = 140.0 )
{
	enum {
		Act_OnAir = 0,
		Act_OnMove,
		Act_Ducking,
		Act_None
	};

	static bitsFlags; bitsFlags = get_entvar( pPlayer, var_flags );
	static Vector3( vecVelocity ); get_entvar( pPlayer, var_velocity, vecVelocity );

	if ( ~bitsFlags & FL_ONGROUND )
		return Float: flSpreadInActions[ Act_OnAir ];
	else if ( xs_vec_len_2d( vecVelocity ) > flMoveSpeed )
		return Float: flSpreadInActions[ Act_OnMove ];
	else if ( bitsFlags & FL_DUCKING )
		return Float: flSpreadInActions[ Act_Ducking ];
	else return Float: flSpreadInActions[ Act_None ];
}

/* -> Get Weapon Box Item <- */
stock UTIL_GetWeaponBoxItem( const pWeaponBox )
{
	for ( new iSlot, pItem; iSlot < MAX_ITEM_TYPES; iSlot++ )
	{
		if ( !is_nullent( ( pItem = get_member( pWeaponBox, m_WeaponBox_rgpPlayerItems, iSlot ) ) ) )
			return pItem;
	}
	return NULLENT;
}

/* -> Automaticly precache WeaponList <- */
stock UTIL_PrecacheWeaponList( const szWeaponList[ ] )
{
	new szBuffer[ 128 ], pFile;

	format( szBuffer, charsmax( szBuffer ), "sprites/%s.txt", szWeaponList );
	engfunc( EngFunc_PrecacheGeneric, szBuffer );

	if ( !( pFile = fopen( szBuffer, "rb" ) ) )
		return;

	new szSprName[ MAX_RESOURCE_PATH_LENGTH ], iPos;

	while ( !feof( pFile ) ) 
	{
		fgets( pFile, szBuffer, charsmax( szBuffer ) );
		trim( szBuffer );

		if ( !strlen( szBuffer ) ) 
			continue;

		if ( ( iPos = containi( szBuffer, "640" ) ) == -1 )
			continue;
				
		format( szBuffer, charsmax( szBuffer ), "%s", szBuffer[ iPos + 3 ] );		
		trim( szBuffer );

		strtok( szBuffer, szSprName, charsmax( szSprName ), szBuffer, charsmax( szBuffer ), ' ', 1 );
		trim( szSprName );

		engfunc( EngFunc_PrecacheGeneric, fmt( "sprites/%s.spr", szSprName ) );
	}

	fclose( pFile );
}

/* -> Gunshot Decal Trace <- */
stock UTIL_GunshotDecalTrace( const pEntity, const Vector3( vecOrigin ) )
{	
	new iDecalId = UTIL_DamageDecal( pEntity );
	if ( iDecalId == -1 )
		return;

	message_begin_f( MSG_PAS, SVC_TEMPENTITY, vecOrigin );
	UTIL_TE_GUNSHOTDECAL( vecOrigin, pEntity, iDecalId );
}

stock UTIL_DamageDecal( const pEntity )
{
	new iRenderMode = get_entvar( pEntity, var_rendermode );
	if ( iRenderMode == kRenderTransAlpha )
		return -1;

	static iGlassDecalId; if ( !iGlassDecalId ) iGlassDecalId = engfunc( EngFunc_DecalIndex, "{bproof1" );
	if ( iRenderMode != kRenderNormal )
		return iGlassDecalId;

	static iShotDecalId; if ( !iShotDecalId ) iShotDecalId = engfunc( EngFunc_DecalIndex, "{shot1" );
	return ( iShotDecalId - random_num( 0, 4 ) );
}

#if !defined _api_dynamic_crosshair_included
	/* -> Weapon List <- */
	stock UTIL_WeaponList( const iDest, const pReceiver, const pItem, szWeaponName[ MAX_NAME_LENGTH ] = "", const iPrimaryAmmoType = -2, iMaxPrimaryAmmo = -2, iSecondaryAmmoType = -2, iMaxSecondaryAmmo = -2, iSlot = -2, iPosition = -2, iWeaponId = -2, iFlags = -2 ) 
	{
		if ( szWeaponName[ 0 ] == EOS )
			rg_get_iteminfo( pItem, ItemInfo_pszName, szWeaponName, charsmax( szWeaponName ) )

		static iMsgId_Weaponlist; if ( !iMsgId_Weaponlist ) iMsgId_Weaponlist = get_user_msgid( "WeaponList" );

		message_begin( iDest, iMsgId_Weaponlist, .player = pReceiver );
		write_string( szWeaponName );
		write_byte( ( iPrimaryAmmoType <= -2 ) ? GetWeaponAmmoType( pItem ) : iPrimaryAmmoType );
		write_byte( ( iMaxPrimaryAmmo <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo1 ) : iMaxPrimaryAmmo );
		write_byte( ( iSecondaryAmmoType <= -2 ) ? get_member( pItem, m_Weapon_iSecondaryAmmoType ) : iSecondaryAmmoType );
		write_byte( ( iMaxSecondaryAmmo <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo2 ) : iMaxSecondaryAmmo );
		write_byte( ( iSlot <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iSlot ) : iSlot );
		write_byte( ( iPosition <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iPosition ) : iPosition );
		write_byte( ( iWeaponId <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iId ) : iWeaponId );
		write_byte( ( iFlags <= -2 ) ? rg_get_iteminfo( pItem, ItemInfo_iFlags ) : iFlags );
		message_end( );
	}

	/* -> Cur Weapon <- */
	stock UTIL_CurWeapon( const iDest, const pReceiver, const bool: bIsActive, const iWeaponId, const iClipAmmo )
	{
		static iMsgId_CurWeapon; if ( !iMsgId_CurWeapon ) iMsgId_CurWeapon = get_user_msgid( "CurWeapon" );

		message_begin( iDest, iMsgId_CurWeapon, .player = pReceiver );
		write_byte( bIsActive );
		write_byte( iWeaponId );
		write_byte( iClipAmmo );
		message_end( );
	}
#endif

/* -> AmmoPickup <- */
stock UTIL_AmmoPickup( const iDest, const pReceiver, const iAmmoType, const iAmount )
{
	static iMsgId_AmmoPickup; if ( !iMsgId_AmmoPickup ) iMsgId_AmmoPickup = get_user_msgid( "AmmoPickup" );

	message_begin( iDest, iMsgId_AmmoPickup, .player = pReceiver );
	write_byte( iAmmoType );
	write_byte( iAmount );
	message_end( );
}

/* -> TE_GUNSHOTDECAL <- */
stock UTIL_TE_GUNSHOTDECAL( const Vector3( vecOrigin ), const pEntity, const iDecalId )
{
	write_byte( TE_GUNSHOTDECAL );
	write_coord_f( vecOrigin[ 0 ] );
	write_coord_f( vecOrigin[ 1 ] );
	write_coord_f( vecOrigin[ 2 ] );
	write_short( pEntity );
	write_byte( iDecalId );
	message_end( );
}

/* -> TE_STREAK_SPLASH <- */
stock UTIL_TE_STREAK_SPLASH( const Vector3( vecOrigin ), const Vector3( vecDirection ), const iColor, const iCount, const iSpeed, const iNoise )
{
	write_byte( TE_STREAK_SPLASH );
	write_coord_f( vecOrigin[ 0 ] );
	write_coord_f( vecOrigin[ 1 ] );
	write_coord_f( vecOrigin[ 2 ] );
	write_coord_f( vecDirection[ 0 ] );
	write_coord_f( vecDirection[ 1 ] );
	write_coord_f( vecDirection[ 2 ] );
	write_byte( iColor );
	write_short( iCount );
	write_short( iSpeed );
	write_short( iNoise );
	message_end( );
}

/* -> TE_BUBBLETRAIL <- */
stock UTIL_TE_BUBBLETRAIL( const Vector3( vecStart ), const Vector3( vecEnd ), const iHeigth, const iszModelIndex, const iCount, const iSpeed )
{
	write_byte( TE_BUBBLETRAIL );
	write_coord_f( vecStart[ 0 ] ); // Start Pos X
	write_coord_f( vecStart[ 1 ] ); // Start Pos Y
	write_coord_f( vecStart[ 2 ] ); // Start Pos Z
	write_coord_f( vecEnd[ 0 ] ); // End Pos X
	write_coord_f( vecEnd[ 1 ] ); // End Pos Y
	write_coord_f( vecEnd[ 2 ] ); // End Pos Z
	write_coord( iHeigth ); // Heigth
	write_short( iszModelIndex ); // Model Index
	write_byte( iCount ); // Count
	write_coord( iSpeed ); // Speed
	message_end( );
}

/* -> TE_SPRITETRAIL <- */
stock UTIL_TE_SPRITETRAIL( const Vector3( vecStart ), const Vector3( vecEnd ), const iszModelIndex, const iCount, const iLife, const iScale, const iSpeedNoise, const iSpeed )
{
	write_byte( TE_SPRITETRAIL );
	write_coord_f( vecStart[ 0 ] );
	write_coord_f( vecStart[ 1 ] );
	write_coord_f( vecStart[ 2 ] );
	write_coord_f( vecEnd[ 0 ] );
	write_coord_f( vecEnd[ 1 ] );
	write_coord_f( vecEnd[ 2 ] );
	write_short( iszModelIndex );
	write_byte( iCount );
	write_byte( iLife );
	write_byte( iScale );
	write_byte( iSpeedNoise );
	write_byte( iSpeed );
	message_end( );
}
