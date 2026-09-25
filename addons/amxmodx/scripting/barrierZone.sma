/*
*
*	Barrier Zone by RedSMURF
*
*
*	Description:
*
*	Cvars:
*		None
*
*	Commands:
*       say /barrierzone        "Opens the Barrier Zone menu."
*       say_team /barrierzone   "Opens the Barrier Zone menu."
*       barrierzone_reload      "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MIN_BOUNCE_VEL              40.0
#define MAX_ENT                     32
#define ADMIN_ACCESS                ADMIN_RCON
#define BARRIER_KEY                 997755
#define BARRIER_ARRAY_ITEM          pev_iuser1
#define BARRIER_OWNER               pev_iuser1
#define BARRIER_TRIGGER_FACTOR      1.125
#define PDATA_NEXT_ATTACK           83
#define XO_CBASEPLAYER              5
#define XO_CBASEPLAYERWEAPON        4
#define SOUND_NAV                   "buttons/blip1.wav"
#define SOUND_REMOVE                "buttons/button10.wav"
#define SOUND_ALERT                 "buttons/bell1.wav"

new const PLUGIN_VERSION[]       = "1.0"
new const Float:DELAY_ON_CONNECT = 1.0
new const Float:DELAY_ON_LOAD       = 1.0
new const ERROR_FILE[]           = "BarrierZone_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS
}

enum
{
    DTYPE_INT,
    DTYPE_FLOAT,
    DTYPE_FLAGS,
    DTYPE_ARRAY_STRING,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_MODEL_ID
}

enum
{
    FLAG_ACTIVE_DELAY       = (1 << 0),
    FLAG_ACTIVE_DURATION    = (1 << 1),

    FLAG_GHOST              = (1 << 2),
    FLAG_SELECT             = (1 << 3),
    FLAG_ACTIVE             = (1 << 4),
    FLAG_PENDING            = (1 << 5)
}

enum
{
    TARGET_GHOST,
    TARGET_SELECT,
    TARGET_HIDE,
    TARGET_CLEAR
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_FLAGS,
    Float:SETTING_DEFAULT_SPAWN_CHANCE,
    Float:SETTING_DEFAULT_ACTIVE_DELAY[2],
    Float:SETTING_DEFAULT_ACTIVE_DURATION[2],
    Float:SETTING_DEFAULT_ACTIVE_COOLDOWN[2],
    bool:SETTING_BARRIER_LOAD,
    Float:SETTING_BARRIER_CHECK,
    Float:SETTING_BARRIER_TASK,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    SETTING_GHOST_ALPHA,
    bool:SETTING_BARRIER_BLOCK_DAMAGE,
    bool:SETTING_BARRIER_BOUNCE_PROJECTILES,

    Float:SETTING_SIZE_BASE,
    Float:SETTING_SIZE_HEIGHT[2],
    Float:SETTING_SIZE_WIDTH[2],
    Float:SETTING_SIZE_DEPTH[2],

    SETTING_BEAM,
    SETTING_BEAM_WIDTH,
    SETTING_BEAM_ALPHA
}

enum _:BARRIER
{
    BARRIER_ID,
    BARRIER_FLAGS,
    BARRIER_TRIGGER,

    Float:BARRIER_SCALE[3],
    Float:BARRIER_ORIGIN[3],
    Float:BARRIER_CORNERS[24],
    Float:BARRIER_MINS[3],
    Float:BARRIER_MAXS[3],

    Float:BARRIER_NEXT_ENABLE,
    Float:BARRIER_NEXT_DISABLE
}

enum _:PLAYER_DATA
{
    PDATA_BARRIER_GHOST,
    PDATA_BARRIER_MENU,
    bool:PDATA_BARRIER_ACTION,
    bool:PDATA_BARRIER_ZONE,
    bool:PDATA_SCALE_UP,
    PDATA_SCALE_FACTOR,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,

    PDATA_MENU_TYPE,
    bool:PDATA_MENU_TRACE
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT
}

enum
{
    MENU_ROOT,
    MENU_EDIT,
    MENU_REMOVE,
    MENU_STATUS,
    MENU_SCALE
}

enum
{
    ROOT_CREATE,
    ROOT_EDIT,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    EDIT_STATUS
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SCALE_HEIGHT,
    SCALE_WIDTH,
    SCALE_DEPTH,

    SCALE_FACTOR = 4,
    SCALE_MODE,
    SCALE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerEdit",
    "menuHandlerRemove",
    "menuHandlerStatus",
    "menuHandlerScale"
}

new const g_iColorActive[] = { 0, 255, 0 }
new const g_iColorInactive[] = { 255, 0, 0 }
new Float:g_fScaleFactor[] = { 5.0, 10.0, 20.0, 30.0, 45.0, 60.0 }
new const g_szBlockClasses[][] = { "weaponbox", "grenade", "info_target" }
new g_szCN[] = "barrierzone"

new Array:g_aBarrier,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead, g_iActivePlayers,
    g_iFwdTraceLine, HamHook:g_iFwdTouch, HamHook:g_iFwdPreThink, HamHook:g_iFwdKilled,
    g_iBarrier,
    g_iMaxPlayers

public plugin_init()
{
    register_plugin("Barrier Zone", PLUGIN_VERSION, "RedSMURF")
    register_cvar("RedSMURF_BarrierZone", PLUGIN_VERSION, ADMIN_ACCESS)

    register_clcmd("say /barrierzone",      "cmdMenu", ADMIN_ACCESS, "-- Opens the Barrier Zone menu.")
    register_clcmd("say_team /barrierzone", "cmdMenu", ADMIN_ACCESS, "-- Opens the Barrier Zone menu.")
    register_concmd("barrierzone_reload",   "cmdReload", ADMIN_ACCESS, "-- Reload the configuration file")

    register_dictionary("BarrierZone.txt")

    g_iFwdTouch = RegisterHam(Ham_Touch, "info_target", "fwdTouch")
    g_iFwdTraceLine = register_forward(FM_TraceLine, "fwdTraceLine", 1)
    g_iFwdPreThink = RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    g_iFwdKilled = RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    register_logevent("eventRoundStart", 2, "1=Round_Start")
    DisableForward()
    DisableBarrier()

    barrierInit()
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aBarrier = ArrayCreate(BARRIER)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aBarrier)
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    barrierSound(id, SOUND_MENU_NAV)
    barrierMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public eventRoundStart()
{
    if ( !g_iBarrier )
        return PLUGIN_HANDLED

    new eBarrier[BARRIER]
    for ( new i = 0; i < g_iBarrier; i ++ )
    {
        ArrayGetArray(g_aBarrier, i, eBarrier)
        if ( !(eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE) )
            continue

        barrierReset(eBarrier)
        barrierSetState(eBarrier)
        if ( g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
        {
            eBarrier[BARRIER_FLAGS] |= FLAG_ACTIVE

            barrierSetDelay(eBarrier)
            barrierSetState(eBarrier)
        }

        ArraySetArray(g_aBarrier, i, eBarrier)
    }

    return PLUGIN_HANDLED
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        for ( new id = 1; id <= g_iMaxPlayers; id ++ )
            if ( is_user_connected(id))
                UpdateData(id)
    }

    new g_szFileName[MAX_RESOURCE_PATH_LENGTH]
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/BarrierZone.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        iSection = SECTION_NONE, iLine, iPos

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax( szData ), "[", "")
                    replace(szData, charsmax( szData ), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                        continue
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        iPos = contain(szValue, "#")
                        if ( iPos != -1 )
                            szValue[iPos] = EOS

                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_BARRIER_LOAD") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BARRIER_LOAD], charsmax(g_eSettings[SETTING_BARRIER_LOAD]))
                        else if ( equali(szKey, "SETTING_BARRIER_CHECK") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_BARRIER_CHECK], charsmax(g_eSettings[SETTING_BARRIER_CHECK]))
                        else if ( equali(szKey, "SETTING_BARRIER_TASK") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_BARRIER_TASK], charsmax(g_eSettings[SETTING_BARRIER_TASK]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_BARRIER_BLOCK_DAMAGE") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BARRIER_BLOCK_DAMAGE], charsmax(g_eSettings[SETTING_BARRIER_BLOCK_DAMAGE]))
                        else if ( equali(szKey, "SETTING_BARRIER_BOUNCE_PROJECTILES") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BARRIER_BOUNCE_PROJECTILES], charsmax(g_eSettings[SETTING_BARRIER_BOUNCE_PROJECTILES]))
                        else if ( equali(szKey, "SETTING_SIZE_BASE") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_SIZE_BASE], charsmax(g_eSettings[SETTING_SIZE_BASE]))
                        else if ( equali(szKey, "SETTING_SIZE_HEIGHT") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_SIZE_HEIGHT], charsmax(g_eSettings[SETTING_SIZE_HEIGHT]))
                        else if ( equali(szKey, "SETTING_SIZE_WIDTH") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_SIZE_WIDTH], charsmax(g_eSettings[SETTING_SIZE_WIDTH]))
                        else if ( equali(szKey, "SETTING_SIZE_DEPTH") )
                            parseSetting(DTYPE_FLOAT, szValue, charsmax(szValue), g_eSettings[SETTING_SIZE_DEPTH], charsmax(g_eSettings[SETTING_SIZE_DEPTH]))
                        else if ( equali(szKey, "SETTING_BEAM") )
                            parseSetting(DTYPE_STRING_MODEL_ID, szValue, charsmax(szValue), g_eSettings[SETTING_BEAM], charsmax(g_eSettings[SETTING_BEAM]))
                        else if ( equali(szKey, "SETTING_BEAM_WIDTH") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BEAM_WIDTH], charsmax(g_eSettings[SETTING_BEAM_WIDTH]))
                        else if ( equali(szKey, "SETTING_BEAM_ALPHA") )
                            parseSetting(DTYPE_INT, szValue, charsmax(szValue), g_eSettings[SETTING_BEAM_ALPHA], charsmax(g_eSettings[SETTING_BEAM_ALPHA]))
                    }
                }
            }
        }
    }

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public client_disconnected(id)
{
    new eBarrier[BARRIER], iItem
    if ( g_ePlayerData[id][PDATA_BARRIER_GHOST]
    && (iItem = barrierGet(eBarrier, g_ePlayerData[id][PDATA_BARRIER_GHOST])) != -1 )
    {
        barrierKill(eBarrier)
        barrierRemove(iItem)
    }

    DisableAction(id)
    g_ePlayerData[id][PDATA_BARRIER_GHOST]  = 0
    g_ePlayerData[id][PDATA_BARRIER_MENU]   = 0
}

public UpdateData(id)
{
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public barrierInit()
{
    if ( g_eSettings[SETTING_BARRIER_LOAD] )
        set_task(DELAY_ON_LOAD, "loadData")
}

stock barrierTerminate()
{
    new eBarrier[BARRIER]
    for ( new i = 0; i < g_iBarrier; i ++ )
    {
        ArrayGetArray(g_aBarrier, i, eBarrier)
        eBarrier[BARRIER_FLAGS] &= ~(FLAG_GHOST | FLAG_SELECT)
        if ( !(eBarrier[BARRIER_FLAGS] & FLAG_PENDING) )
            continue

        eBarrier[BARRIER_FLAGS] |= FLAG_ACTIVE
        eBarrier[BARRIER_FLAGS] &= ~FLAG_PENDING
        ArraySetArray(g_aBarrier, i, eBarrier)
    }
}

stock barrierMenu(id, iType)
{
    if ( !is_user_connected(id) )
        return PLUGIN_HANDLED

    new szData[256], iMenu
    formatex(szData, charsmax(szData), "%L", id, "BARRIER_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])
    switch( iType )
    {
        case MENU_ROOT:         { menuRoot(id, iMenu); }
        case MENU_EDIT:         { menuEdit(id, iMenu);          format(szData, charsmax(szData), "%s^n%L", szData, id, "BARRIER_ROOT_EDIT"); }
        case MENU_REMOVE:       { menuRemove(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BARRIER_ROOT_REMOVE"); }
        case MENU_STATUS:       { menuStatus(id, iMenu);        format(szData, charsmax(szData), "%s^n%L", szData, id, "BARRIER_ROOT_STATUS"); }
        case MENU_SCALE:        { menuScale(id, iMenu);         format(szData, charsmax(szData), "%s^n%L", szData, id, "BARRIER_ROOT_SCALE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "BARRIER_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_ROOT_EDIT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_ROOT_NOCLIP", id, get_user_noclip(id) ? "BARRIER_ON" : "BARRIER_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_ROOT_GODMODE", id, get_user_godmode(id) ? "BARRIER_ON" : "BARRIER_OFF")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iBarrier >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_LIMIT", MAX_ENT)

                barrierSound(id, SOUND_MENU_REMOVE)
                barrierMenu(id, MENU_ROOT)
            }
            else
            {
                barrierCreate(id)

                barrierSound(id, SOUND_MENU_NAV)
                barrierMenu(id, MENU_SCALE)
            }
        }
        case ROOT_EDIT:
        {
            if ( !g_iBarrier )
            {
                client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_NO_BARRIER")

                barrierSound(id, SOUND_MENU_REMOVE)
                barrierMenu(id, MENU_ROOT)
            }
            else
            {
                barrierSound(id, SOUND_MENU_NAV)
                barrierMenu(id, MENU_EDIT)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iBarrier )
            {
                client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_NO_BARRIER")

                barrierSound(id, SOUND_MENU_REMOVE)
                barrierMenu(id, MENU_ROOT)
            }
            else
            {
                barrierSound(id, SOUND_MENU_REMOVE)
                barrierMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            barrierNoClip(id)
        }
        case ROOT_GODMODE:
        {
            barrierGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuEdit(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_EDIT_STATUS")
    menu_additem(iMenu, szItem)
}

public menuHandlerEdit(id, menu, item)
{
    switch( item )
    {
        case EDIT_STATUS:
        {
            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_ROOT)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], eBarrier[BARRIER]
    menuNav(id, iMenu)
    ArrayGetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_REMOVE_CURRENT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    barrierSelect(eBarrier, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_REMOVE
    ArraySetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)
}

public menuHandlerRemove(id, menu, item)
{
    new eBarrier[BARRIER]
    ArrayGetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        barrierSelect(eBarrier, eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE ? TARGET_CLEAR : TARGET_GHOST)
        ArraySetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)
    }

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BARRIER_MENU] >= g_iBarrier - 1 )
                g_ePlayerData[id][PDATA_BARRIER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BARRIER_MENU] ++

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BARRIER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BARRIER_MENU] = g_iBarrier - 1
            else
                g_ePlayerData[id][PDATA_BARRIER_MENU] --

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            eBarrier[BARRIER_FLAGS] &= ~FLAG_ACTIVE
            barrierSetState(eBarrier)
            barrierKill(eBarrier)
            barrierRemove(g_ePlayerData[id][PDATA_BARRIER_MENU])

            client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_REMOVE_CURRENT")
            g_ePlayerData[id][PDATA_BARRIER_MENU] = 0

            barrierSound(id, g_iBarrier > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            barrierMenu(id, g_iBarrier > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iBarrier )
            {
                ArrayGetArray(g_aBarrier, 0, eBarrier)
                eBarrier[BARRIER_FLAGS] &= ~FLAG_ACTIVE

                barrierSetState(eBarrier)
                barrierKill(eBarrier)
                barrierRemove(0)
            }

            client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_BARRIER_MENU] = 0

            barrierSound(id, SOUND_MENU_ALERT)
            barrierMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                barrierSound(id, SOUND_MENU_NAV)
                barrierMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_BARRIER_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_BARRIER_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], eBarrier[BARRIER]
    menuNav(id, iMenu)
    ArrayGetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_STATUS_CURRENT", id, eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE ? "BARRIER_ENABLED" : "BARRIER_DISABLED")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    barrierSelect(eBarrier, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_STATUS
    ArraySetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)
}

public menuHandlerStatus(id, menu, item)
{
    new eBarrier[BARRIER]
    ArrayGetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        barrierSelect(eBarrier, eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE ? TARGET_CLEAR : TARGET_GHOST)
        ArraySetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)
    }

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_BARRIER_MENU] >= g_iBarrier - 1 )
                g_ePlayerData[id][PDATA_BARRIER_MENU] = 0
            else
                g_ePlayerData[id][PDATA_BARRIER_MENU] ++

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_BARRIER_MENU] <= 0 )
                g_ePlayerData[id][PDATA_BARRIER_MENU] = g_iBarrier - 1
            else
                g_ePlayerData[id][PDATA_BARRIER_MENU] --

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            eBarrier[BARRIER_FLAGS] ^= FLAG_ACTIVE
            barrierSetState(eBarrier)

            client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_STATUS_CURRENT",
            id, eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE ? "BARRIER_CHAT_ENABLED" : "BARRIER_CHAT_DISABLED")
            ArraySetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iBarrier; i ++ )
            {
                ArrayGetArray(g_aBarrier, i, eBarrier)
                eBarrier[BARRIER_FLAGS] |= FLAG_ACTIVE
                barrierSetState(eBarrier)

                ArraySetArray(g_aBarrier, i, eBarrier)
            }

            client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_STATUS_ALL_ENABLED")
            barrierSound(id, SOUND_MENU_ALERT)
            barrierMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iBarrier; i ++ )
            {
                ArrayGetArray(g_aBarrier, i, eBarrier)
                eBarrier[BARRIER_FLAGS] &= ~FLAG_ACTIVE
                barrierSetState(eBarrier)

                ArraySetArray(g_aBarrier, i, eBarrier)
            }

            client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_STATUS_ALL_DISABLED")
            barrierSound(id, SOUND_MENU_ALERT)
            barrierMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                barrierSound(id, SOUND_MENU_NAV)
                barrierMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_BARRIER_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_BARRIER_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuScale(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_SCALE_HEIGHT", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BARRIER_ADD" : "BARRIER_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_SCALE_WIDTH", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BARRIER_ADD" : "BARRIER_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_SCALE_DEPTH", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BARRIER_ADD" : "BARRIER_REMOVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_SCALE_FACTOR", g_ePlayerData[id][PDATA_SCALE_UP] ? "\y" : "\r", g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_SCALE_MODE", id, g_ePlayerData[id][PDATA_SCALE_UP] ? "BARRIER_INCREASE" : "BARRIER_DECREASE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "BARRIER_SCALE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerScale(id, menu, item)
{
    new eBarrier[BARRIER], iItem
    if ( (iItem = barrierGet(eBarrier, g_ePlayerData[id][PDATA_BARRIER_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case SCALE_HEIGHT:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBarrier[BARRIER_SCALE][2] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBarrier[BARRIER_SCALE][2] > g_eSettings[SETTING_SIZE_HEIGHT][1])
                    eBarrier[BARRIER_SCALE][2] = g_eSettings[SETTING_SIZE_HEIGHT][1]
            }
            else
            {
                eBarrier[BARRIER_SCALE][2] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBarrier[BARRIER_SCALE][2] < g_eSettings[SETTING_SIZE_HEIGHT][0])
                    eBarrier[BARRIER_SCALE][2] = g_eSettings[SETTING_SIZE_HEIGHT][0]
            }

            ArraySetArray(g_aBarrier, iItem, eBarrier)
            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_SCALE)
        }
        case SCALE_WIDTH:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBarrier[BARRIER_SCALE][0] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBarrier[BARRIER_SCALE][0] > g_eSettings[SETTING_SIZE_WIDTH][1])
                    eBarrier[BARRIER_SCALE][0] = g_eSettings[SETTING_SIZE_WIDTH][1]
            }
            else
            {
                eBarrier[BARRIER_SCALE][0] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBarrier[BARRIER_SCALE][0] < g_eSettings[SETTING_SIZE_WIDTH][0])
                    eBarrier[BARRIER_SCALE][0] = g_eSettings[SETTING_SIZE_WIDTH][0]
            }

            ArraySetArray(g_aBarrier, iItem, eBarrier)
            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_SCALE)
        }
        case SCALE_DEPTH:
        {
            if ( g_ePlayerData[id][PDATA_SCALE_UP] )
            {
                eBarrier[BARRIER_SCALE][1] += g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBarrier[BARRIER_SCALE][1] > g_eSettings[SETTING_SIZE_DEPTH][1])
                    eBarrier[BARRIER_SCALE][1] = g_eSettings[SETTING_SIZE_DEPTH][1]
            }
            else
            {
                eBarrier[BARRIER_SCALE][1] -= g_fScaleFactor[g_ePlayerData[id][PDATA_SCALE_FACTOR]]
                if (eBarrier[BARRIER_SCALE][1] < g_eSettings[SETTING_SIZE_DEPTH][0])
                    eBarrier[BARRIER_SCALE][1] = g_eSettings[SETTING_SIZE_DEPTH][0]
            }

            ArraySetArray(g_aBarrier, iItem, eBarrier)
            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_SCALE)
        }
        case SCALE_FACTOR:
        {
            g_ePlayerData[id][PDATA_SCALE_FACTOR] += 1
            if ( g_ePlayerData[id][PDATA_SCALE_FACTOR] >= sizeof(g_fScaleFactor) )
                g_ePlayerData[id][PDATA_SCALE_FACTOR] = 0

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_SCALE)
        }
        case SCALE_MODE:
        {
            g_ePlayerData[id][PDATA_SCALE_UP] = !g_ePlayerData[id][PDATA_SCALE_UP]

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_SCALE)
        }
        case SCALE_PLACE:
        {
            barrierTrace(eBarrier, id)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BARRIER_GHOST] = 0

            eBarrier[BARRIER_FLAGS] |= FLAG_ACTIVE
            barrierSetSeq(eBarrier[BARRIER_ID])
            barrierSetSize(eBarrier)
            barrierSetDelay(eBarrier)
            barrierSetState(eBarrier)
            ArraySetArray(g_aBarrier, iItem, eBarrier)

            client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_CREATE_NEW")
            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            barrierKill(eBarrier)
            barrierRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BARRIER_GHOST] = 0

            barrierSound(id, SOUND_MENU_NAV)
            barrierMenu(id, MENU_ROOT)
        }
        default:
        {
            barrierKill(eBarrier)
            barrierRemove(iItem)
            DisableAction(id)
            set_pdata_float(id, PDATA_NEXT_ATTACK, 0.0, XO_CBASEPLAYER, XO_CBASEPLAYER)
            g_ePlayerData[id][PDATA_BARRIER_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public barrierTask()
{
    new eBarrier[BARRIER], Float:fCurrentTime, bool:bModified
    fCurrentTime = get_gametime()
    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id) )
            continue

        if ( !g_ePlayerData[id][PDATA_BARRIER_GHOST] )
        {
            if ( g_ePlayerData[id][PDATA_BARRIER_ACTION] )
                barrierCheck(id)
        }
        else if ( barrierGet(eBarrier, g_ePlayerData[id][PDATA_BARRIER_GHOST]) != -1 )
        {
            barrierTrace(eBarrier, id)
        }
    }

    for ( new i = 0; i < g_iBarrier; i ++ )
    {
        ArrayGetArray(g_aBarrier, i, eBarrier)

        if ( eBarrier[BARRIER_FLAGS] & FLAG_SELECT )
            barrierBeam(eBarrier)

        if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE )
        {
            if ( eBarrier[BARRIER_NEXT_DISABLE] > 0.0
            && fCurrentTime >= eBarrier[BARRIER_NEXT_DISABLE] )
            {
                eBarrier[BARRIER_FLAGS] &= ~FLAG_ACTIVE
                eBarrier[BARRIER_FLAGS] |= FLAG_PENDING
                eBarrier[BARRIER_NEXT_DISABLE] = 0.0
                eBarrier[BARRIER_NEXT_ENABLE] = fCurrentTime + random_float(g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0], g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1])

                barrierSetState(eBarrier)
                bModified = true
            }
        }
        else
        {
            if ( eBarrier[BARRIER_NEXT_ENABLE] > 0.0
            && fCurrentTime >= eBarrier[BARRIER_NEXT_ENABLE] )
            {
                eBarrier[BARRIER_FLAGS] |= FLAG_ACTIVE
                eBarrier[BARRIER_FLAGS] &= ~FLAG_PENDING
                eBarrier[BARRIER_NEXT_ENABLE] = 0.0
                if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE_DURATION )
                    eBarrier[BARRIER_NEXT_DISABLE] = fCurrentTime + random_float(g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0], g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1])

                barrierSetState(eBarrier)
                bModified = true
            }
        }

        if ( bModified )
            ArraySetArray(g_aBarrier, i, eBarrier)
    }
}

public barrierCreate(id)
{
    new iEnt = cs_create_entity("info_target")
    if ( !pev_valid(iEnt) )
        return

    new eBarrier[BARRIER]
    eBarrier[BARRIER_ID] = iEnt
    eBarrier[BARRIER_SCALE][0] = eBarrier[BARRIER_SCALE][1] = eBarrier[BARRIER_SCALE][2] = g_eSettings[SETTING_SIZE_BASE]
    if ( id )
    {
        EnableAction(id)
        g_ePlayerData[id][PDATA_BARRIER_GHOST] = iEnt
        g_ePlayerData[id][PDATA_BARRIER_ACTION] = true
        g_ePlayerData[id][PDATA_SCALE_UP] = true
        g_ePlayerData[id][PDATA_SCALE_FACTOR] = 0
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
    }

    barrierSelect(eBarrier, TARGET_GHOST)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_impulse, BARRIER_KEY)
    set_pev(iEnt, BARRIER_ARRAY_ITEM, g_iBarrier)
    dllfunc(DLLFunc_Spawn, iEnt)
    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_DEFAULT_MODEL])

    ArrayPushArray(g_aBarrier, eBarrier)
    if ( ++ g_iBarrier == 1 )
    {
        EnableBarrier()
        set_task(g_eSettings[SETTING_BARRIER_TASK], "barrierTask", BARRIER_KEY, .flags = "b")
    }
}

stock barrierCreateTrigger(eBarrier[BARRIER])
{
    new iEnt = cs_create_entity("info_target")
    if (!pev_valid(iEnt))
        return

    new szCN[32]
    format(szCN, charsmax(szCN), "%s_trigger", g_szCN)
    eBarrier[BARRIER_TRIGGER] = iEnt
    set_pev(iEnt, BARRIER_OWNER, eBarrier[BARRIER_ID])
    set_pev(iEnt, pev_classname, szCN)
    dllfunc(DLLFunc_Spawn, iEnt)

    new Float:fMins[3], Float:fMaxs[3]
    xs_vec_copy(eBarrier[BARRIER_MINS], fMins)
    xs_vec_copy(eBarrier[BARRIER_MAXS], fMaxs)
    fMins[2] *= BARRIER_TRIGGER_FACTOR
    fMaxs[2] *= BARRIER_TRIGGER_FACTOR

    set_pev(iEnt, pev_origin, eBarrier[BARRIER_ORIGIN])
    set_pev(iEnt, pev_solid, SOLID_TRIGGER)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
    engfunc(EngFunc_SetSize, iEnt, fMins, fMaxs)
}

stock barrierRemove(iItem)
{
    new eBarrier[BARRIER]
    ArrayDeleteItem(g_aBarrier, iItem)

    if ( -- g_iBarrier == 0 )
    {
        DisableBarrier()
        remove_task(BARRIER_KEY)
    }

    for ( new i = iItem; i < g_iBarrier; i ++ )
    {
        ArrayGetArray(g_aBarrier, i, eBarrier)
        set_pev(eBarrier[BARRIER_ID], BARRIER_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eBarrier[BARRIER],
        szFile[128], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BarrierZone.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iBarrier; i ++ )
    {
        ArrayGetArray(g_aBarrier, i, eBarrier)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "flags = %d^n", eBarrier[BARRIER_FLAGS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "scale = %.2f %.2f %.2f^n",
        eBarrier[BARRIER_SCALE][0], eBarrier[BARRIER_SCALE][1], eBarrier[BARRIER_SCALE][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eBarrier[BARRIER_ORIGIN][0], eBarrier[BARRIER_ORIGIN][1], eBarrier[BARRIER_ORIGIN][2])
        fputs(iFile, szData)

        for ( new j = 0; j < 8; j ++ )
        {
            formatex(szData, charsmax(szData), "corner_%d = %.2f %.2f %.2f^n",
            j + 1, eBarrier[BARRIER_CORNERS][j * 3], eBarrier[BARRIER_CORNERS][(j * 3) + 1], eBarrier[BARRIER_CORNERS][(j * 3) + 2])
            fputs(iFile, szData)
        }
    }

    client_print_color(id, id, "%L %L", id, "BARRIER_CHAT_TAG", id, "BARRIER_CHAT_SAVE", szFile)
    fclose(iFile)

    barrierSound(id, SOUND_MENU_NAV)
    barrierMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        iFlags, Float:fScale[3], Float:fOrigin[3], Float:fCorners[24],
        iCorner, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_BarrierZone.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return PLUGIN_HANDLED

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                loadDataBarrier(iFlags, fOrigin, fScale, fCorners, iCount)

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "scale") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fScale[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fScale[1] = str_to_float(szKey)
                fScale[2] = str_to_float(szValue)
            }
            else if ( contain(szKey, "corner") != -1 )
            {
                iCorner = str_to_num(szKey[7])

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fCorners[(iCorner - 1) * 3] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fCorners[(iCorner - 1) * 3 + 1] = str_to_float(szKey)
                fCorners[(iCorner - 1) * 3 + 2] = str_to_float(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataBarrier(iFlags, fOrigin, fScale, fCorners, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataBarrier(iFlags, Float:fOrigin[3], Float:fScale[3], Float:fCorners[24], iCount)
{
    new eBarrier[BARRIER]
    barrierCreate(0)
    ArrayGetArray(g_aBarrier, iCount, eBarrier)

    eBarrier[BARRIER_FLAGS] = iFlags
    xs_vec_copy(fScale, eBarrier[BARRIER_SCALE])
    xs_vec_copy(fOrigin, eBarrier[BARRIER_ORIGIN])
    for ( new i = 0; i < 24; i ++ )
        eBarrier[BARRIER_CORNERS][i] = fCorners[i]

    barrierSetSeq(eBarrier[BARRIER_ID])
    barrierSetBox(eBarrier)
    barrierSetSize(eBarrier)
    barrierSetDelay(eBarrier)
    barrierSetState(eBarrier)
    ArraySetArray(g_aBarrier, iCount, eBarrier)
}

public barrierNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    barrierSound(id, SOUND_MENU_NAV)
    barrierMenu(id, MENU_ROOT)
}

public barrierGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    barrierSound(id, SOUND_MENU_NAV)
    barrierMenu(id, MENU_ROOT)
}

public fwdTouch(iEnt, iOther)
{
    new eBarrier[BARRIER]
    if ( !g_eSettings[SETTING_BARRIER_BLOCK_DAMAGE]
    || isBarrier(iOther)
    || barrierGet(eBarrier, pev(iEnt, BARRIER_OWNER)) == -1
    || !(eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE) )
        return HAM_IGNORED

    new szCN[32]
    pev(iOther, pev_classname, szCN, charsmax(szCN))
    for (new i = 0; i < sizeof g_szBlockClasses; i ++ )
    {
        if ( !equal(szCN, g_szBlockClasses[i]) )
            continue

        new Float:fVelocity[3], Float:fOrigin[3], Float:flDelta[3], Float:flFrac[3]
        pev(iOther, pev_origin, fOrigin)
        pev(iOther, pev_velocity, fVelocity)
        for ( new j = 0; j < 3; j ++ )
        {
            new Float:flHalf   = (eBarrier[BARRIER_MAXS][j] - eBarrier[BARRIER_MINS][j]) * 0.5
            new Float:flCenter = eBarrier[BARRIER_ORIGIN][j] + (eBarrier[BARRIER_MINS][j] + eBarrier[BARRIER_MAXS][j]) * 0.5

            flDelta[j] = fOrigin[j] - flCenter
            flFrac[j]  = (flHalf > 0.0) ? (floatabs(flDelta[j]) / flHalf) : 0.0
        }

        new axis = 0
        if ( flFrac[1] > flFrac[axis] ) axis = 1
        if ( flFrac[2] > flFrac[axis] ) axis = 2
        if ( (flDelta[axis] > 0.0 && fVelocity[axis] >= 0.0)
        || (flDelta[axis] < 0.0 && fVelocity[axis] <= 0.0) )
            break

        fVelocity[axis] *= -1.0
        set_pev(iOther, pev_velocity, fVelocity)
        break
    }

    return HAM_IGNORED
}

public fwdTraceLine(Float:fStart[3], Float:fEnd[3], iConditions, id, iTrace)
{
    if ( !g_eSettings[SETTING_BARRIER_BOUNCE_PROJECTILES]
    || !is_user_alive(id) )
        return FMRES_IGNORED

    new eBarrier[BARRIER], iBest = -1
    new Float:fBestFraction = 1.0
    new Float:fDelta[3]
    xs_vec_sub(fEnd, fStart, fDelta)

    for (new i = 0; i < g_iBarrier; i++)
    {
        ArrayGetArray(g_aBarrier, i, eBarrier)
        if (!(eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE))
            continue

        new Float:fMins[3], Float:fMaxs[3]
        xs_vec_add(eBarrier[BARRIER_ORIGIN], eBarrier[BARRIER_MINS], fMins)
        xs_vec_add(eBarrier[BARRIER_ORIGIN], eBarrier[BARRIER_MAXS], fMaxs)

        new Float:fEnter = 0.0, Float:fExit = 1.0
        new bool:bMiss = false
        for ( new j = 0; j < 3 && !bMiss; j ++ )
        {
            if ( floatabs(fDelta[j]) < 0.0001 )
            {
                bMiss = (fStart[j] < fMins[j] || fStart[j] > fMaxs[j])
                continue
            }

            new Float:t1 = (fMins[j] - fStart[j]) / fDelta[j]
            new Float:t2 = (fMaxs[j] - fStart[j]) / fDelta[j]
            fEnter = floatmax(fEnter, floatmin(t1, t2))
            fExit  = floatmin(fExit,  floatmax(t1, t2))
            bMiss  = (fEnter > fExit)
        }

        if ( bMiss || fEnter < 0.0 || fEnter >= fBestFraction )
            continue

        fBestFraction = fEnter
        iBest = eBarrier[BARRIER_ID]
    }

    if ( iBest == -1 )
        return FMRES_IGNORED

    new Float:fHit[3]
    for (new j = 0; j < 3; j++)
        fHit[j] = fStart[j] + fDelta[j] * fBestFraction

    set_tr2(iTrace, TR_pHit, iBest)
    set_tr2(iTrace, TR_vecEndPos, fHit)
    set_tr2(iTrace, TR_flFraction, fBestFraction)
    return FMRES_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    new iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_BARRIER_GHOST] )
    {
        if ( fCurrentTime >= g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
        }

        set_pdata_float(id, PDATA_NEXT_ATTACK, fCurrentTime + 0.1, XO_CBASEPLAYER, XO_CBASEPLAYER)
        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    DisableAction(id)
    g_ePlayerData[id][PDATA_BARRIER_MENU]   = 0
    if ( g_ePlayerData[id][PDATA_BARRIER_GHOST] )
    {
        new eBarrier[BARRIER], iItem
        if ( (iItem = barrierGet(eBarrier, g_ePlayerData[id][PDATA_BARRIER_GHOST])) != -1 )
        {
            barrierKill(eBarrier)
            barrierRemove(iItem)
        }

        g_ePlayerData[id][PDATA_BARRIER_GHOST] = 0
    }
}

public barrierTrace(eBarrier[BARRIER], id)
{
    new Float:fVec1[3]
    pev(id, pev_origin, eBarrier[BARRIER_ORIGIN])
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(eBarrier[BARRIER_ORIGIN], fVec1, eBarrier[BARRIER_ORIGIN])

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eBarrier[BARRIER_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eBarrier[BARRIER_ORIGIN], fVec1, IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eBarrier[BARRIER_ORIGIN])

    barrierSetBox(eBarrier, true)
    barrierSetOffset(eBarrier)
    barrierSetBox(eBarrier, true)
    barrierBeam(eBarrier)
    set_pev(eBarrier[BARRIER_ID], pev_origin, eBarrier[BARRIER_ORIGIN])
}

stock barrierCheck(id)
{
    new eBarrier[BARRIER], Float:fVec1[3], Float:fVec2[3], Float:fVec3[3], Float:fMins[3], Float:fMaxs[3], Float:fNearest[3]
    new iBest, Float:fBestDist, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fVec2)
    engfunc(EngFunc_MakeVectors, fVec2)
    global_get(glb_v_forward, fVec2)

    iBest = -1
    fBestDist = g_eSettings[SETTING_BARRIER_CHECK]
    for ( new i = 0; i < g_iBarrier; i ++ )
    {
        ArrayGetArray(g_aBarrier, i, eBarrier)
        xs_vec_sub(eBarrier[BARRIER_ORIGIN], fVec1, fVec3)
        fDot = xs_vec_dot(fVec2, fVec3)

        if ( fDot < 0.0 )
            continue

        pev(eBarrier[BARRIER_ID], pev_absmin, fMins)
        pev(eBarrier[BARRIER_ID], pev_absmax, fMaxs)
        xs_vec_mul_scalar(fVec2, fDot, fVec3)
        xs_vec_add(fVec3, fVec1, fVec3)

        fNearest[0] = floatclamp(fVec3[0], fMins[0], fMaxs[0])
        fNearest[1] = floatclamp(fVec3[1], fMins[1], fMaxs[1])
        fNearest[2] = floatclamp(fVec3[2], fMins[2], fMaxs[2])
        fDist = get_distance_f(fVec3, fNearest)
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_BARRIER_MENU] != iBest )
    {
        ArrayGetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)
        eBarrier[BARRIER_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aBarrier, g_ePlayerData[id][PDATA_BARRIER_MENU], eBarrier)

        g_ePlayerData[id][PDATA_MENU_TRACE] = true
        g_ePlayerData[id][PDATA_BARRIER_MENU] = iBest
        barrierMenu(id, g_ePlayerData[id][PDATA_MENU_TYPE])
    }
}

stock barrierSetBox(eBarrier[BARRIER], bool:bSetCorners = false)
{
    if ( bSetCorners )
        boxCorners(eBarrier)

    xs_vec_copy(eBarrier[BARRIER_CORNERS][0], eBarrier[BARRIER_MINS])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][0], eBarrier[BARRIER_MAXS])
    for ( new i = 1; i < 8; i ++ )
    {
        for ( new j = 0; j < 3; j ++ )
        {
            eBarrier[BARRIER_MINS][j] = floatmin(eBarrier[BARRIER_MINS][j], eBarrier[BARRIER_CORNERS][i * 3 + j])
            eBarrier[BARRIER_MAXS][j] = floatmax(eBarrier[BARRIER_MAXS][j], eBarrier[BARRIER_CORNERS][i * 3 + j])
        }
    }

    xs_vec_sub(eBarrier[BARRIER_MINS], eBarrier[BARRIER_ORIGIN], eBarrier[BARRIER_MINS])
    xs_vec_sub(eBarrier[BARRIER_MAXS], eBarrier[BARRIER_ORIGIN], eBarrier[BARRIER_MAXS])
}

public boxCorners(eBarrier[BARRIER])
{
    eBarrier[BARRIER_CORNERS][0]  = eBarrier[BARRIER_ORIGIN][0] - eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][1]  = eBarrier[BARRIER_ORIGIN][1] - eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][2]  = eBarrier[BARRIER_ORIGIN][2] - eBarrier[BARRIER_SCALE][2]

    eBarrier[BARRIER_CORNERS][3]  = eBarrier[BARRIER_ORIGIN][0] + eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][4]  = eBarrier[BARRIER_ORIGIN][1] - eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][5]  = eBarrier[BARRIER_ORIGIN][2] - eBarrier[BARRIER_SCALE][2]

    eBarrier[BARRIER_CORNERS][6]  = eBarrier[BARRIER_ORIGIN][0] - eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][7]  = eBarrier[BARRIER_ORIGIN][1] + eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][8]  = eBarrier[BARRIER_ORIGIN][2] - eBarrier[BARRIER_SCALE][2]

    eBarrier[BARRIER_CORNERS][9]  = eBarrier[BARRIER_ORIGIN][0] + eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][10] = eBarrier[BARRIER_ORIGIN][1] + eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][11] = eBarrier[BARRIER_ORIGIN][2] - eBarrier[BARRIER_SCALE][2]

    eBarrier[BARRIER_CORNERS][12] = eBarrier[BARRIER_ORIGIN][0] - eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][13] = eBarrier[BARRIER_ORIGIN][1] - eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][14] = eBarrier[BARRIER_ORIGIN][2] + eBarrier[BARRIER_SCALE][2]

    eBarrier[BARRIER_CORNERS][15] = eBarrier[BARRIER_ORIGIN][0] + eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][16] = eBarrier[BARRIER_ORIGIN][1] - eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][17] = eBarrier[BARRIER_ORIGIN][2] + eBarrier[BARRIER_SCALE][2]

    eBarrier[BARRIER_CORNERS][18] = eBarrier[BARRIER_ORIGIN][0] - eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][19] = eBarrier[BARRIER_ORIGIN][1] + eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][20] = eBarrier[BARRIER_ORIGIN][2] + eBarrier[BARRIER_SCALE][2]

    eBarrier[BARRIER_CORNERS][21] = eBarrier[BARRIER_ORIGIN][0] + eBarrier[BARRIER_SCALE][0]
    eBarrier[BARRIER_CORNERS][22] = eBarrier[BARRIER_ORIGIN][1] + eBarrier[BARRIER_SCALE][1]
    eBarrier[BARRIER_CORNERS][23] = eBarrier[BARRIER_ORIGIN][2] + eBarrier[BARRIER_SCALE][2]
}

stock barrierSetOffset(eBarrier[BARRIER])
{
    new Float:fGaps[6], Float:fVec1[3], Float:fCurrentGap
    fGaps[0] = -eBarrier[BARRIER_MINS][0]
    fGaps[1] = eBarrier[BARRIER_MAXS][0]
    fGaps[2] = -eBarrier[BARRIER_MINS][1]
    fGaps[3] = eBarrier[BARRIER_MAXS][1]
    fGaps[4] = -eBarrier[BARRIER_MINS][2]
    fGaps[5] = eBarrier[BARRIER_MAXS][2]

    for ( new i = 0; i < 6; i ++ )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eBarrier[BARRIER_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eBarrier[BARRIER_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eBarrier[BARRIER_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eBarrier[BARRIER_ORIGIN], fVec1)

        if ( fCurrentGap < (fGaps[i] + 1.0) )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, (fGaps[i] + 1.0) - fCurrentGap, fVec1)
            xs_vec_add(eBarrier[BARRIER_ORIGIN], fVec1, eBarrier[BARRIER_ORIGIN])
        }
    }
}

stock barrierSetSeq(iEnt)
{
    set_pev(iEnt, pev_sequence, 0)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, 1.0)
    set_pev(iEnt, pev_animtime, get_gametime())
}

stock barrierSetSize(eBarrier[BARRIER])
{
    barrierSelect(eBarrier, TARGET_CLEAR)
    engfunc(EngFunc_SetOrigin, eBarrier[BARRIER_ID], eBarrier[BARRIER_ORIGIN])
    set_pev(eBarrier[BARRIER_ID], pev_solid, eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE ? SOLID_BBOX : SOLID_NOT)
    set_pev(eBarrier[BARRIER_ID], pev_movetype, MOVETYPE_NONE)

    engfunc(EngFunc_SetSize, eBarrier[BARRIER_ID], eBarrier[BARRIER_MINS], eBarrier[BARRIER_MAXS])
    barrierCreateTrigger(eBarrier)
}

stock barrierSetDelay(eBarrier[BARRIER])
{
    if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE )
    {
        new Float:fCurrentTime
        fCurrentTime = get_gametime()

        if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE_DELAY )
        {
            eBarrier[BARRIER_FLAGS] &= ~FLAG_ACTIVE
            eBarrier[BARRIER_NEXT_ENABLE] = fCurrentTime + random_float(g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0], g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1])

            barrierSetState(eBarrier)
        }
        else
        {
            if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE_DURATION )
                eBarrier[BARRIER_NEXT_DISABLE] = fCurrentTime + random_float(g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0], g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1])
        }
    }
}

stock barrierSetState(eBarrier[BARRIER])
{
    if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE )
    {
        set_pev(eBarrier[BARRIER_ID], pev_solid, SOLID_BBOX)
        set_pev(eBarrier[BARRIER_TRIGGER], pev_solid, SOLID_TRIGGER)
        barrierSelect(eBarrier, TARGET_CLEAR)
    }
    else
    {
        set_pev(eBarrier[BARRIER_ID], pev_solid, SOLID_NOT)
        set_pev(eBarrier[BARRIER_TRIGGER], pev_solid, SOLID_NOT)
        barrierSelect(eBarrier, TARGET_HIDE)
    }
}

stock barrierSelect(eBarrier[BARRIER], iAction)
{
    new iRender, iRenderFx, iRenderColor[3], iRenderAmt

    iRenderFx = kRenderFxNone
    if ( iAction == TARGET_SELECT )
    {
        if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE )    { iRenderColor[0] = g_iColorActive[0];      iRenderColor[1] = g_iColorActive[1];     iRenderColor[2] = g_iColorActive[2]; }
        else                                            { iRenderColor[0] = g_iColorInactive[0];    iRenderColor[1] = g_iColorInactive[1];   iRenderColor[2] = g_iColorInactive[2]; }

        iRender = kRenderTransColor
        iRenderFx = kRenderFxGlowShell
        iRenderAmt = 16

        eBarrier[BARRIER_FLAGS] |= FLAG_SELECT
    }
    else if ( iAction == TARGET_GHOST )
    {
        iRender = kRenderTransAlpha
        iRenderAmt = g_eSettings[SETTING_GHOST_ALPHA]

        eBarrier[BARRIER_FLAGS] &= ~FLAG_SELECT
    }
    else if ( iAction == TARGET_HIDE )
    {
        iRender = kRenderTransAlpha
        iRenderAmt = 0
    }
    else if ( iAction == TARGET_CLEAR )
    {
        iRender = kRenderNormal
        iRenderAmt = 255

        eBarrier[BARRIER_FLAGS] &= ~FLAG_SELECT
    }

    set_ent_rendering(eBarrier[BARRIER_ID], iRenderFx, iRenderColor[0], iRenderColor[1], iRenderColor[2], iRender, iRenderAmt)
}

stock barrierSound(iEnt, iSound, bool:bPlayer = true)
{
    new szSample[64]
    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), SOUND_NAV)
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), SOUND_REMOVE)
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), SOUND_ALERT)
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

stock barrierBeam(eBarrier[BARRIER])
{
    new Float:fCorners[8][3]
    xs_vec_copy(eBarrier[BARRIER_CORNERS][0],  fCorners[0])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][3],  fCorners[1])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][6],  fCorners[2])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][9],  fCorners[3])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][12], fCorners[4])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][15], fCorners[5])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][18], fCorners[6])
    xs_vec_copy(eBarrier[BARRIER_CORNERS][21], fCorners[7])

    beamDraw(fCorners[0], fCorners[1], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[1], fCorners[3], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[3], fCorners[2], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[2], fCorners[0], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)

    beamDraw(fCorners[0], fCorners[4], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[1], fCorners[5], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[2], fCorners[6], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[3], fCorners[7], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)

    beamDraw(fCorners[4], fCorners[5], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[5], fCorners[7], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[7], fCorners[6], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
    beamDraw(fCorners[6], fCorners[4], eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE != 0)
}

stock beamDraw(Float:fStart[3], Float:fEnd[3], bool:bActive)
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fStart)
    write_byte(TE_BEAMPOINTS)
    write_coord_f(fStart[0])
    write_coord_f(fStart[1])
    write_coord_f(fStart[2])
    write_coord_f(fEnd[0])
    write_coord_f(fEnd[1])
    write_coord_f(fEnd[2])
    write_short(g_eSettings[SETTING_BEAM])
    write_byte(0)
    write_byte(0)
    write_byte(1)
    write_byte(g_eSettings[SETTING_BEAM_WIDTH])
    write_byte(0)
    if ( bActive )
    {
        write_byte(g_iColorActive[0])
        write_byte(g_iColorActive[1])
        write_byte(g_iColorActive[2])
    }
    else
    {
        write_byte(g_iColorInactive[0])
        write_byte(g_iColorInactive[1])
        write_byte(g_iColorInactive[2])
    }
    write_byte(g_eSettings[SETTING_BEAM_ALPHA])
    write_byte(0)
    message_end()
}

stock barrierReset(eBarrier[BARRIER])
{
    eBarrier[BARRIER_FLAGS] &= ~FLAG_ACTIVE
    eBarrier[BARRIER_NEXT_ENABLE] = 0.0
    eBarrier[BARRIER_NEXT_DISABLE] = 0.0

    barrierSetState(eBarrier)
}

stock barrierGet(eBarrier[BARRIER], iEnt)
{
    new iItem
    iItem = pev(iEnt, BARRIER_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iBarrier )
        return -1

    ArrayGetArray(g_aBarrier, iItem, eBarrier)
    return iItem
}

stock bool:isBarrier(iEnt)
{
    return pev_valid(iEnt) && pev(iEnt, pev_impulse) == BARRIER_KEY
}

stock barrierKill(eBarrier[BARRIER])
{
    if ( pev_valid(eBarrier[BARRIER_ID]) )
        set_pev(eBarrier[BARRIER_ID], pev_flags, pev(eBarrier[BARRIER_ID], pev_flags) | FL_KILLME)

    if ( pev_valid(eBarrier[BARRIER_TRIGGER]) )
        set_pev(eBarrier[BARRIER_TRIGGER], pev_flags, pev(eBarrier[BARRIER_TRIGGER], pev_flags) | FL_KILLME)
}

stock parseSetting(iType, szValue[], iValueLen, any:aOutput[], iOutputLength)
{
    switch ( iType )
    {
        case DTYPE_INT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_num(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLOAT:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_float(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLAGS:
        {
            aOutput[0] = read_flags(szValue)
        }
        case DTYPE_ARRAY_STRING:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(aOutput[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                aOutput[0] = precache_model(szValue)
        }
    }
}

stock EnableAction(id)
{
    if ( !g_ePlayerData[id][PDATA_BARRIER_ACTION] )
    {
        new eBarrier[BARRIER]
        for ( new i = 0; i < g_iBarrier; i ++ )
        {
            ArrayGetArray(g_aBarrier, i, eBarrier)
            if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE )
                continue

            barrierSelect(eBarrier, TARGET_GHOST)
        }

        g_ePlayerData[id][PDATA_BARRIER_ACTION] = true
        if ( ++ g_iActivePlayers == 1 )
            EnableForward()
    }
}

stock DisableAction(id)
{
    if ( g_ePlayerData[id][PDATA_BARRIER_ACTION] )
    {
        new eBarrier[BARRIER]
        for ( new i = 0; i < g_iBarrier; i ++ )
        {
            ArrayGetArray(g_aBarrier, i, eBarrier)
            if ( eBarrier[BARRIER_FLAGS] & FLAG_ACTIVE )
                continue

            barrierSelect(eBarrier, TARGET_HIDE)
        }

        g_ePlayerData[id][PDATA_BARRIER_ACTION] = false
        if ( -- g_iActivePlayers == 0 )
            DisableForward()
    }
}

stock EnableForward()
{
    EnableHamForward(g_iFwdPreThink)
    EnableHamForward(g_iFwdKilled)
}

stock DisableForward()
{
    DisableHamForward(g_iFwdPreThink)
    DisableHamForward(g_iFwdKilled)
}

stock EnableBarrier()
{
    EnableHamForward(g_iFwdTouch)
    g_iFwdTraceLine = register_forward(FM_TraceLine, "fwdTraceLine", 1)
}

stock DisableBarrier()
{
    DisableHamForward(g_iFwdTouch)
    unregister_forward(FM_TraceLine, g_iFwdTraceLine, 1)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}
