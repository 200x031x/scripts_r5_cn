global function Cl_CustomTDM_Init

global function ServerCallback_TDM_DoAnnouncement
global function ServerCallback_TDM_SetSelectedLocation
global function ServerCallback_TDM_DoLocationIntroCutscene
global function ServerCallback_TDM_PlayerKilled
global function ServerCallback_OpenTDMMenu
global function ServerCallback_TDM_DoVictoryAnnounce

global function Cl_RegisterLocation

struct {

    LocationSettings &selectedLocation
    array choices
    array<LocationSettings> locationSettings
    var scoreRui
    var score1Rui
    var score2Rui
    var score3Rui
    var victoryRui
    var latencyRui
} file;

struct PlayerInfo 
{
	string name
	int team
	int score
}

global int maxTeam = 0;

void function Cl_CustomTDM_Init()
{
    printf("cl_customTDM_init")
    
}



void function Cl_RegisterLocation(LocationSettings locationSettings)
{
    file.locationSettings.append(locationSettings)
    
}


void function MakeScoreRUI()
{
    if ( file.scoreRui != null)
    {
        RuiSetString( file.scoreRui, "messageText", "Initialize Score Board..." )
        return
    }
    clGlobal.levelEnt.EndSignal( "CloseScoreRUI" )

    UISize screenSize = GetScreenSize()
    var screenAlignmentTopo = RuiTopology_CreatePlane( <( screenSize.width * 0.25),( screenSize.height * 0.0 ), 0>, <float( screenSize.width ), 0, 0>, <0, float( screenSize.height ), 0>, false )
    var rui = RuiCreate( $"ui/announcement_quick_right.rpak", screenAlignmentTopo, RUI_DRAW_HUD, RUI_SORT_SCREENFADE + 1 )
    
    RuiSetGameTime( rui, "startTime", Time() )

    string msg = ""
    foreach(player in GetPlayerArray())
    {
        msg = msg + player.GetPlayerName() + ": " + "0" + "\n"
    }
    //RuiSetString( rui, "messageText", "Team IMC: 0  ||  Team MIL: 0" )
    RuiSetString( rui, "messageText", msg )
    RuiSetString( rui, "messageSubText", "Text 2")
    RuiSetFloat( rui, "duration", 9999999 )
    RuiSetFloat3( rui, "eventColor", SrgbToLinear( <255, 0, 0> ) )
	
    file.scoreRui = rui


    OnThreadEnd(
		function() : ( rui )
		{
			RuiDestroy( rui )
			file.scoreRui = null
		}
	)
    
    WaitForever()
}

void function ServerCallback_TDM_DoAnnouncement(float duration, int type)
{
    
    string message = ""
    string subtext = ""
    switch(type)
    {

        case eTDMAnnounce.ROUND_START:
        {
            thread MakeScoreRUI();
            thread MakeLatencyRUI();
            message = "???????????????"
            break
        }
        case eTDMAnnounce.VOTING_PHASE:
        {
            clGlobal.levelEnt.Signal( "CloseScoreRUI" )
            message = "????????????????????????"
            subtext = "sal???shrugtal??????(Neko???Black201?????????????????????)"
            break
        }
        case eTDMAnnounce.MAP_FLYOVER:
        {
            
            if(file.locationSettings.len())
                message = file.selectedLocation.name
            break
        }

    }
	AnnouncementData announcement = Announcement_Create( message )
    Announcement_SetSubText(announcement, subtext)
    //Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_RESULTS )
	Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_CIRCLE_WARNING )
	Announcement_SetPurge( announcement, true )
	Announcement_SetOptionalTextArgsArray( announcement, [ "true" ] )
	Announcement_SetPriority( announcement, 200 ) //Be higher priority than Titanfall ready indicator etc
	announcement.duration = duration
	AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}


void function ServerCallback_TDM_DoVictoryAnnounce( int winnerTeam )
{
	if ( file.victoryRui != null )
		return

    string message = ""

	asset ruiAsset = GetChampionScreenRuiAsset()
	file.victoryRui = CreateFullscreenRui( ruiAsset )
	RuiSetBool( file.victoryRui, "onWinningTeam",  GetLocalClientPlayer().GetTeam() == winnerTeam)
    //RuiSetString(file.victoryRui, "messageText", message);
    //RuiSetFloat( file.victoryRui, "duration", duration )
    //RuiSetFloat3( file.victoryRui, "eventColor", SrgbToLinear( <128, 188, 255> ) )


	EmitSoundOnEntity( GetLocalClientPlayer(), "UI_InGame_ChampionVictory" )

    thread DestroyVictoryRui()

}

void function DestroyVictoryRui()
{
    wait 5
    RuiDestroy( file.victoryRui )
    file.victoryRui = null
}

asset function GetChampionScreenRuiAsset()
{
	return $"ui/champion_screen.rpak"
}

void function ServerCallback_TDM_DoLocationIntroCutscene()
{
    thread ServerCallback_TDM_DoLocationIntroCutscene_Body()
}

void function ServerCallback_TDM_DoLocationIntroCutscene_Body()
{
    entity player = GetLocalClientPlayer()
    float desiredSpawnSpeed = Deathmatch_GetIntroSpawnSpeed()
    float desiredSpawnDuration = Deathmatch_GetIntroCutsceneSpawnDuration()
    float desireNoSpawns = Deathmatch_GetIntroCutsceneNumSpawns()

    if(!IsValid(player)) return
    EmitSoundOnEntity( player, "music_skyway_04_smartpistolrun" )
    
    entity camera = CreateClientSidePointCamera(file.selectedLocation.spawns[0].origin + file.selectedLocation.cinematicCameraOffset, <90, 90, 0>, 17)
    camera.SetFOV(90)
    
    entity cutsceneMover = CreateClientsideScriptMover($"mdl/dev/empty_model.rmdl", file.selectedLocation.spawns[0].origin + file.selectedLocation.cinematicCameraOffset, <90, 90, 0>)
    camera.SetParent(cutsceneMover)
    wait 1

	GetLocalClientPlayer().SetMenuCameraEntity( camera )
    ////////////////////////////////////////////////////////////////////////////////
    ///////// EFFECTIVE CUTSCENE CODE START

    array<LocPair> cutsceneSpawns
    for(int i = 0; i < desireNoSpawns; i++)
    {
        if(!cutsceneSpawns.len())
            cutsceneSpawns = clone file.selectedLocation.spawns

        LocPair spawn = cutsceneSpawns.getrandom()
        cutsceneSpawns.fastremovebyvalue(spawn)

        cutsceneMover.SetOrigin(spawn.origin)
        camera.SetAngles(spawn.angles)

        cutsceneMover.NonPhysicsMoveTo(spawn.origin + AnglesToForward(spawn.angles) * desiredSpawnDuration * desiredSpawnSpeed, desiredSpawnDuration, 0, 0)
        wait desiredSpawnDuration
    }


    ///////// EFFECTIVE CUTSCENE CODE END
    ////////////////////////////////////////////////////////////////////////////////


    GetLocalClientPlayer().ClearMenuCameraEntity()
    cutsceneMover.Destroy()

    FadeOutSoundOnEntity( player, "music_skyway_04_smartpistolrun", 1 )
    
    camera.Destroy()
    
    
}

void function ServerCallback_TDM_SetSelectedLocation(int sel)
{
    file.selectedLocation = file.locationSettings[sel]
}


//open tdm menu
void function ServerCallback_OpenTDMMenu()
{  
    RunUIScript("ServerCallback_OpenTDMMenu")
    RunUIScript("ServerCallback_ChangeToTDMMenu")
}


void function ServerCallback_TDM_PlayerKilled()
{
    if(file.scoreRui)
    {
        if(!shouldShowLatency)
		{
			shouldShowLatency = true
		}
        
        array<PlayerInfo> playersInfo = []

        foreach(player in GetPlayerArray())
        {
            PlayerInfo p
            p.name = player.GetPlayerName()
            p.team = player.GetTeam()
            p.score = GameRules_GetTeamScore(player.GetTeam())
            //PlayerInfo p = { name = player.GetPlayerName(), team = player.GetTeam(), score = GameRules_GetTeamScore(player.GetTeam()) }
            playersInfo.append(p)
        }

        
        playersInfo.sort(ComparePlayerInfo)

        string msg = ""

        for(int i = 0; i < playersInfo.len(); i++)
	    {	
		    PlayerInfo p = playersInfo[i]
           // printt("playername : " + p.name + "  score : " + p.score)
            switch(i)
            {
                case 0:
                    msg = msg + "1st " + p.name + ": " + p.score + "\n"
                    break
                case 1:
                    msg = msg + "2nd " + p.name + ": " + p.score + "\n"
                    break
                case 2:
                    msg = msg + "3rd " + p.name + ": " + p.score + "\n"
                    break
                default:
                    msg = msg + p.name + ": " + p.score + "\n"
                    break

            }
            
        }

		    
        
        RuiSetString( file.scoreRui, "messageText", msg);
    }
        
}

int function ComparePlayerInfo(PlayerInfo a, PlayerInfo b)
{
	if(a.score < b.score) return 1;
	else if(a.score > b.score) return -1;
	return 0; 
}

var function CreateTemporarySpawnRUI(entity parentEnt, float duration)
{
	var rui = AddOverheadIcon( parentEnt, RESPAWN_BEACON_ICON, false, $"ui/overhead_icon_respawn_beacon.rpak" )
	RuiSetFloat2( rui, "iconSize", <80,80,0> )
	RuiSetFloat( rui, "distanceFade", 50000 )
	RuiSetBool( rui, "adsFade", true )
	RuiSetString( rui, "hint", "SPAWN POINT" )

    wait duration

    parentEnt.Destroy()
}