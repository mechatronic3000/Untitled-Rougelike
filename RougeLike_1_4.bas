$RESIZE:OFF
OPTION _EXPLICIT
'$dynamic
'$include:'RougeLikeTypes.bi'
'$include:'RougeLikeConst.bi'

'**********************************************************************************************
'   Untitled Rougelike Adventure written by Paul Martin aka justsomeguy
'**********************************************************************************************

'   Physics code ported from RandyGaul's Impulse Engine
'   https://github.com/RandyGaul/ImpulseEngine
'   http://RandyGaul.net
'**********************************************************************************************
'    Copyright (c) 2013 Randy Gaul http://RandyGaul.net

'    This software is provided 'as-is', without any express or implied
'    warranty. In no event will the authors be held liable for any damages
'    arising from the use of this software.

'    Permission is granted to anyone to use this software for any purpose,
'    including commercial applications, and to alter it and redistribute it
'    freely, subject to the following restrictions:
'      1. The origin of this software must not be misrepresented; you must not
'         claim that you wrote the original software. If you use this software
'         in a product, an acknowledgment in the product documentation would be
'         appreciated but is not required.
'      2. Altered source versions must be plainly marked as such, and must not be
'         misrepresented as being the original software.
'      3. This notice may not be removed or altered from any source distribution.
'
DIM SHARED gameOptions AS tGAMEOPTIONS
DIM SHARED fpsCount AS tFPS
DIM SHARED timers(0) AS tELAPSEDTIMER
DIM SHARED tileFont(255) AS tTILEFONT
DIM SHARED sounds(0) AS tSOUND
DIM SHARED playList AS tPLAYLIST
DIM SHARED logfile AS LONG
DIM SHARED landmark(0) AS tLANDMARK
DIM SHARED doors(0) AS tDOOR


'**********************************************************************************************
'
'**********************************************************************************************
' 05-22-21 : Added Mouse PoseEdge and NegEdge, tidyied up the code
' 05-23-21 : Push Screen Init and FPS init to functions
' 05-23-21 : Auto Center FPS Counter
' 05-23-21 : Realized that you dont need to use  if you dont use () around the arguments
'            Purged 's from main program
' 05-26-21 : Purged 's from impulse.bas
' 05-27-21 : More purging of CALL's
' 01-07-22 : Refactor for Generic Use, Removed all CALL statements
' 01-12-22 : Integrate TMX and TSX files to make level building easier
' 01-13-22 : Optimize AABB for collision detection
' 01-17-22 : Reorganized code for easier navigation
' 01-23-22 : Refactor XML parsing (Still not happy with it.)
' 01-23-22 : Adding Waypoints to the map data
' 01-27-22 : Discovered and fixed a long term bug in the circle wireframe code
'            Added Mouse code that uses as hidden image to detect collisions with sensors
'            Laid ground work for A-star usage
' 01-31-22 : Tidy up code more. Pushed mainloop items out to the Subs and functions
'            Implemented camera movement FSM
'            Player is controllable with Mouse and A Star
' 02-01-22 : Rename objectmanager to bodyManager
'            Inserted some Perlin Noise Code
'            Reworked message handler and Added a Splash Screen
' 02-04-22 : Worked on Camera following and Character movement FSM
'            The FSM still needs work
'            Integrated Background Music for the menu
' 02-06-22 : Added in baked in lighting for the map.
'            Added FSM functioanlity for Music
'            Added Landmarks
' 02-11-22 : Now able traverse Levels.
' 02-14-22 : Added Rigid Body Functionality (SLOW!!!!)
' 04-19-22 : Added Game Options Right now only volume
'**********************************************************************************************
'TODO:
'
'**********************************************************************************************
'   ENTRY POINT
'**********************************************************************************************

main

'**********************************************************************************************
'   Main Loop
'**********************************************************************************************
SUB _______________MAIN_LOOP (): END SUB
SUB main

  '**********************************************************************************************
  '   Arrays
  '**********************************************************************************************

  STATIC world AS tWORLD
  STATIC message(0) AS tMESSAGE
  STATIC poly(0) AS tPOLY
  STATIC entity(0) AS tENTITY
  STATIC body(0) AS tBODY
  STATIC joints(0) AS tJOINT
  STATIC hits(0) AS tHIT
  STATIC veh(0) AS tVEHICLE
  STATIC camera AS tCAMERA
  STATIC inputDevice AS tINPUTDEVICE
  STATIC network AS tNETWORK
  STATIC tileMap AS tTILEMAP
  STATIC tile(0) AS tTILE
  STATIC gamemap(0) AS tTILE
  STATIC engine AS tENGINE

  _TITLE "Untitled Rougelike Adventure"
  engine.logFileName = _CWD$ + "/Logfile.txt"
  engine.logFileNumber = 1
  logfile = engine.logFileNumber
  IF _FILEEXISTS(engine.logFileName) THEN KILL engine.logFileName
  OPEN engine.logFileName FOR OUTPUT AS engine.logFileNumber

  engine.currentMap = "Main_Menu.tmx"
  initScreen engine, 1024, 768, 32
  initFPS

  buildScene engine, world, entity(), gamemap(), poly(), body(), joints(), camera, tile(), tileMap, veh(), inputDevice, network, message()

  DO

    runScene engine, world, entity(), gamemap(), poly(), body(), joints(), hits(), tile(), tileMap, camera, veh(), inputDevice, network, message()
    handleNetwork body(), network
    handleTimers
    handleMusic playList, sounds()
    handleCamera camera
    handleEntitys entity(), body(), tileMap
    handleMessages tile(), message()
    handleInputDevice poly(), body(), inputDevice, camera
    handleFPS
    impulseStep engine, world, poly(), body(), joints(), hits(), cDT, cITERATIONS

    _DISPLAY
  LOOP UNTIL _KEYHIT = 27

  shutdown tile(), network

END SUB
'**********************************************************************************************
'   Scene Build
'**********************************************************************************************
SUB _______________BUILD_SCENE (): END SUB

SUB buildScene (engine AS tENGINE, world AS tWORLD, entity() AS tENTITY, gamemap() AS tTILE, poly() AS tPOLY, body() AS tBODY, j() AS tJOINT, camera AS tCAMERA, tile() AS tTILE, tilemap AS tTILEMAP, v() AS tVEHICLE, idevice AS tINPUTDEVICE, net AS tNETWORK, message() AS tMESSAGE)

  _MOUSEHIDE
  gameOptions.musicVolume = .10
  REDIM body(0) AS tBODY
  REDIM poly(0) AS tPOLY
  REDIM j(0) AS tJOINT
  REDIM v(0) AS tVEHICLE
  REDIM message(0) AS tMESSAGE
  REDIM context(0) AS tSTRINGTUPLE

  freeAllTiles tile()

  '********************************************************
  '   Setup World
  '********************************************************
  v(0).vehicleName = "Nothing" ' Clear Warning
  tilemap.tilescale = 1
  engine.displayClearColor = _RGB32(39, 67, 55)
  '********************************************************
  '   Setup Network
  '********************************************************
  net.address = "localhost"
  net.port = 1234
  net.protocol = "TCP/IP"
  net.SorC = cNET_NONE
  '********************************************************
  '   Load Map
  '********************************************************
  XMLparse _CWD$ + "/Assets/", engine.currentMap, context()
  XMLApplyAttributes engine, world, gamemap(), entity(), poly(), body(), camera, tile(), tilemap, _CWD$ + "/Assets/", context()
  initInputDevice poly(), body(), idevice, tile(idToTile(tile(), 516 + 1)).t

  DIM AS LONG playerId
  playerId = entityManagerID(body(), "PLAYER")
  IF playerId < 0 THEN
    PRINT "Player does not exist!": waitkey: END
  END IF

  entity(playerId).parameters.movementSpeed = .15
  entity(playerId).parameters.drunkiness = 1

  FSMChangeState engine.gameMode, cFSM_GAMEMODE_SPLASH

END SUB

'**********************************************************************************************
'   Scene Handling
'**********************************************************************************************
SUB _______________RUN_SCENE (): END SUB
SUB runScene (engine AS tENGINE, world AS tWORLD, entity() AS tENTITY, gamemap() AS tTILE, poly() AS tPOLY, body() AS tBODY, joints() AS tJOINT, hits() AS tHIT, tile() AS tTILE, tilemap AS tTILEMAP, camera AS tCAMERA, veh() AS tVEHICLE, iDevice AS tINPUTDEVICE, net AS tNETWORK, message() AS tMESSAGE)
  DIM AS LONG backgroundMusic, music1, music2, door
  DIM AS tVECTOR2d tempVec
  backgroundMusic = soundManagerIDClass(sounds(), "BACKGROUND")
  music1 = soundManagerIDClass(sounds(), "MUSIC_1")
  music2 = soundManagerIDClass(sounds(), "MUSIC_2")
  SELECT CASE engine.gameMode.currentState
    CASE cFSM_GAMEMODE_IDLE:
    CASE cFSM_GAMEMODE_SPLASH:
      DIM AS tVECTOR2d position
      vector2dSet position, 100, 100
      addMessage tile(), tilemap, message(), "Untitled RougeLike_    Adventure_  by Paul Martin _ aka  JUSTSOMEGUY", 4, position, 3.0
      playMusic playList, sounds(), "BACKGROUND"
      FSMChangeState engine.gameMode, cFSM_GAMEMODE_START
    CASE cFSM_GAMEMODE_START:
      engine.gameMode.timerState.duration = 9
      clearScreen engine
      FSMChangeStateOnTimer engine.gameMode, cFSM_GAMEMODE_MAINMENU
      iDevice.mouseMode = 0
    CASE cFSM_GAMEMODE_MAINMENU:
      iDevice.mouseMode = 1
      DIM AS LONG playerId, mouseId
      DIM AS tVECTOR2d mpos

      playerId = entityManagerID(body(), "PLAYER")
      IF playerId < 0 THEN
        PRINT "Object does not exist!": waitkey: END
      END IF

      mouseId = bodyManagerID(body(), "_mouse")

      ' Camera Zoom -- Mouse Scroll Wheel
      camera.zoom = camera.zoom + (iDevice.wCount * .1)
      IF camera.zoom < 1.5 THEN camera.zoom = 1.5

      vector2dSet mpos, iDevice.xy.x, iDevice.xy.y
      IF iDevice.b2PosEdge THEN
        moveCamera camera, body(mouseId).fzx.position
      END IF

      door = handleDoors(entity(), body(), hits(), doors())
      IF NOT door THEN
        stopMusic playList
        DIM tempDoor AS tDOOR: tempDoor = doors(door): 'make a copy of the activated Door
        REDIM context(0) AS tSTRINGTUPLE
        ERASE body
        REDIM body(0) AS tBODY
        ERASE poly
        REDIM poly(0) AS tPOLY
        ERASE joints
        REDIM joints(0) AS tJOINT
        ERASE veh
        REDIM veh(0) AS tVEHICLE
        ERASE gamemap
        REDIM gamemap(0) AS tTILE
        ERASE tile
        REDIM tile(0) AS tTILE
        ERASE doors
        REDIM doors(0) AS tDOOR
        ERASE hits
        REDIM hits(0) AS tHIT
        ERASE entity
        REDIM entity(0) AS tENTITY
        freeAllTiles tile()
        removeAllMusic playList, sounds()
        engine.currentMap = trim$(tempDoor.map)
        XMLparse _CWD$ + "/Assets/", trim$(engine.currentMap), context()
        XMLApplyAttributes engine, world, gamemap(), entity(), poly(), body(), camera, tile(), tilemap, _CWD$ + "/Assets/", context()
        initInputDevice poly(), body(), iDevice, tile(idToTile(tile(), 516 + 1)).t
        playerId = entityManagerID(body(), "PLAYER")
        IF playerId < 0 THEN
          PRINT "Player does not exist!": waitkey: END
        END IF
        entity(playerId).parameters.movementSpeed = .15
        entity(playerId).parameters.drunkiness = 1

        findLandmarkPositionHash landmark(), tempDoor.landmarkHash, tempVec
        setBody poly(), body(), cPARAMETER_POSITION, entity(playerId).objectID, tempVec.x, tempVec.y
        moveCamera camera, body(entity(playerId).objectID).fzx.position

        EXIT SUB
      END IF
      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senMUSIC_1")) THEN
        playMusic playList, sounds(), "MUSIC_1"
      END IF

      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senMUSIC_2")) THEN
        playMusic playList, sounds(), "MUSIC_2"
      END IF

      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senMUSIC_3")) THEN
        playMusic playList, sounds(), "BACKGROUND"
      END IF


      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senQUIT_N")) THEN
        findLandmarkPosition landmark(), "lmNEVERMIND", tempVec
        setBody poly(), body(), cPARAMETER_POSITION, entity(playerId).objectID, tempVec.x, tempVec.y
        moveCamera camera, body(entity(playerId).objectID).fzx.position
      END IF

      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senQUIT_Y")) THEN
        SYSTEM
      END IF

      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senCREDITS")) THEN
        moveCamera camera, body(entity(playerId).objectID).fzx.position
        FSMChangeState engine.gameMode, cFSM_GAMEMODE_CREDITSINIT
      END IF

      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senQUIT")) THEN
        stopMusic playList
        findLandmarkPosition landmark(), "lmQUIT", tempVec
        setBody poly(), body(), cPARAMETER_POSITION, entity(playerId).objectID, tempVec.x, tempVec.y
        moveCamera camera, body(entity(playerId).objectID).fzx.position
      END IF

      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senOPTIONS")) THEN
        findLandmarkPosition landmark(), "lmOptions", tempVec
        setBody poly(), body(), cPARAMETER_POSITION, entity(playerId).objectID, tempVec.x, tempVec.y
        moveCamera camera, body(entity(playerId).objectID).fzx.position
      END IF

      IF NOT isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senReturnToMainMenu")) THEN
        findLandmarkPosition landmark(), "lmNEVERMIND", tempVec
        setBody poly(), body(), cPARAMETER_POSITION, entity(playerId).objectID, tempVec.x, tempVec.y
        moveCamera camera, body(entity(playerId).objectID).fzx.position
      END IF



      IF 0 THEN ' disabled for now
        IF _KEYDOWN(32) OR _KEYDOWN(87) OR _KEYDOWN(119) OR _KEYDOWN(18432) THEN
          body(entity(playerId).objectID).fzx.force.y = -(entity(playerId).parameters.maxForce.y / 100)
        END IF

        IF _KEYDOWN(20480) THEN
          body(entity(playerId).objectID).fzx.force.y = (entity(playerId).parameters.maxForce.y / 100)
        END IF

        IF _KEYDOWN(65) OR _KEYDOWN(97) OR _KEYDOWN(19200) THEN
          body(entity(playerId).objectID).fzx.force.x = -(entity(playerId).parameters.maxForce.x)
        END IF

        IF _KEYDOWN(68) OR _KEYDOWN(100) OR _KEYDOWN(19712) THEN
          body(entity(playerId).objectID).fzx.force.x = entity(playerId).parameters.maxForce.x
        END IF

        body(entity(playerId).objectID).fzx.velocity.x = impulseClamp(-1000, 1000, body(entity(playerId).objectID).fzx.velocity.x)
        body(entity(playerId).objectID).fzx.velocity.y = impulseClamp(-1000, 1000, body(entity(playerId).objectID).fzx.velocity.y)
      END IF

      IF iDevice.b1PosEdge THEN
        SELECT CASE isOnSensor(engine, mpos)
          CASE ELSE
            moveEntity entity(playerId), body(), iDevice.mouse, gamemap(), tilemap
            FSMChangeState camera.fsm, cFSM_CAMERA_IDLE
        END SELECT
      END IF

      ' If entity has stopped moving, and camera was sitting still then move the camera to the player
      IF entity(playerId).fsmPrimary.currentState = cFSM_ENTITY_IDLE AND entity(playerId).fsmPrimary.previousState = cFSM_ENTITY_MOVE AND camera.fsm.previousState <> cFSM_CAMERA_MOVING THEN
        IF isBodyTouchingBody(hits(), entity(playerId).objectID, bodyManagerID(body(), "senCENTER_CAMERA")) THEN
          moveCamera camera, body(entity(playerId).objectID).fzx.position
        ELSE
          findLandmarkPosition landmark(), "lmCAMERA_CENTER", tempVec
          moveCamera camera, tempVec
        END IF
      END IF
      renderBodies engine, poly(), body(), joints(), hits(), camera


    CASE cFSM_GAMEMODE_CREDITSINIT:
      clearScreen engine
      vector2dSet position, 40, 100
      addMessage tile(), tilemap, message(), "Untitled RougeLike Adventure__by Paul Martin aka JUSTSOMEGUY_Written Using QB64___Graphics by Kenney_www.kenney.nl___Sound by Eric Matyas_soundimage.org", 4, position, 2.0
      FSMChangeState engine.gameMode, cFSM_GAMEMODE_CREDITS
    CASE cFSM_GAMEMODE_CREDITS:
      engine.gameMode.timerState.duration = 9
      clearScreen engine
      FSMChangeStateOnTimer engine.gameMode, cFSM_GAMEMODE_MAINMENU
      iDevice.mouseMode = 0
      findLandmarkPosition landmark(), "lmNEVERMIND", tempVec
      setBody poly(), body(), cPARAMETER_POSITION, entity(playerId).objectID, tempVec.x, tempVec.y
  END SELECT
END SUB

'**********************************************************************************************
'   Entity Management Subs
'**********************************************************************************************
SUB _______________ENTITY_MANAGEMENT (): END SUB

FUNCTION entityCreate (entity() AS tENTITY, p() AS tPOLY, body() AS tBODY, tilemap AS tTILEMAP, entityName AS STRING, position AS tVECTOR2d)
  DIM AS LONG index, tempid
  index = UBOUND(entity)
  tempid = createBoxBodyEx(p(), body(), entityName, tilemap.tileWidth / 2.1, tilemap.tileHeight / 2.1)
  entity(index).objectID = tempid
  setBody p(), body(), cPARAMETER_POSITION, tempid, position.x - tilemap.tileWidth, position.y - tilemap.tileHeight
  setBody p(), body(), cPARAMETER_NOPHYSICS, tempid, 0, 0
  setBody p(), body(), cPARAMETER_ENTITYID, tempid, index, 0
  REDIM _PRESERVE entity(index + 1) AS tENTITY
  entityCreate = index
END FUNCTION

FUNCTION entityManagerID (body() AS tBODY, entityName AS STRING)
  DIM AS LONG id
  id = bodyManagerID(body(), entityName)
  IF id >= 0 THEN
    entityManagerID = body(id).entityID
  ELSE
    entityManagerID = -1
  END IF
END FUNCTION

'**********************************************************************************************
'   Vector Math Functions
'**********************************************************************************************
SUB _______________VECTOR_FUNCTIONS (): END SUB

SUB vector2dSet (v AS tVECTOR2d, x AS _FLOAT, y AS _FLOAT)
  v.x = x
  v.y = y
END SUB

SUB vector2dSetVector (o AS tVECTOR2d, v AS tVECTOR2d)
  o.x = v.x
  o.y = v.y
END SUB

SUB vector2dNeg (v AS tVECTOR2d)
  v.x = -v.x
  v.y = -v.y
END SUB

SUB vector2dNegND (o AS tVECTOR2d, v AS tVECTOR2d)
  o.x = -v.x
  o.y = -v.y
END SUB

SUB vector2dMultiplyScalar (v AS tVECTOR2d, s AS _FLOAT)
  v.x = v.x * s
  v.y = v.y * s
END SUB

SUB vector2dMultiplyScalarND (o AS tVECTOR2d, v AS tVECTOR2d, s AS _FLOAT)
  o.x = v.x * s
  o.y = v.y * s
END SUB

SUB vector2dDivideScalar (v AS tVECTOR2d, s AS _FLOAT)
  v.x = v.x / s
  v.y = v.y / s
END SUB

SUB vector2dDivideScalarND (o AS tVECTOR2d, v AS tVECTOR2d, s AS _FLOAT)
  o.x = v.x / s
  o.y = v.y / s
END SUB

SUB vector2dAddScalar (v AS tVECTOR2d, s AS _FLOAT)
  v.x = v.x + s
  v.y = v.y + s
END SUB

SUB vector2dAddScalarND (o AS tVECTOR2d, v AS tVECTOR2d, s AS _FLOAT)
  o.x = v.x + s
  o.y = v.y + s
END SUB

SUB vector2dMultiplyVector (v AS tVECTOR2d, m AS tVECTOR2d)
  v.x = v.x * m.x
  v.y = v.y * m.y
END SUB

SUB vector2dMultiplyVectorND (o AS tVECTOR2d, v AS tVECTOR2d, m AS tVECTOR2d)
  o.x = v.x * m.x
  o.y = v.y * m.y
END SUB

SUB vector2dDivideVector (v AS tVECTOR2d, m AS tVECTOR2d)
  v.x = v.x / m.x
  v.y = v.y / m.y
END SUB

SUB vector2dDivideVectorND (o AS tVECTOR2d, v AS tVECTOR2d, m AS tVECTOR2d)
  o.x = v.x / m.x
  o.y = v.y / m.y
END SUB

SUB vector2dAddVector (v AS tVECTOR2d, m AS tVECTOR2d)
  v.x = v.x + m.x
  v.y = v.y + m.y
END SUB

SUB vector2dAddVectorND (o AS tVECTOR2d, v AS tVECTOR2d, m AS tVECTOR2d)
  o.x = v.x + m.x
  o.y = v.y + m.y
END SUB

SUB vector2dAddVectorScalar (v AS tVECTOR2d, m AS tVECTOR2d, s AS _FLOAT)
  v.x = v.x + m.x * s
  v.y = v.y + m.y * s
END SUB

SUB vector2dAddVectorScalarND (o AS tVECTOR2d, v AS tVECTOR2d, m AS tVECTOR2d, s AS _FLOAT)
  o.x = v.x + m.x * s
  o.y = v.y + m.y * s
END SUB

SUB vector2dSubVector (v AS tVECTOR2d, m AS tVECTOR2d)
  v.x = v.x - m.x
  v.y = v.y - m.y
END SUB

SUB vector2dSubVectorND (o AS tVECTOR2d, v AS tVECTOR2d, m AS tVECTOR2d)
  o.x = v.x - m.x
  o.y = v.y - m.y
END SUB

SUB vector2dSwap (v1 AS tVECTOR2d, v2 AS tVECTOR2d)
  SWAP v1, v2
END SUB

FUNCTION vector2dLengthSq (v AS tVECTOR2d)
  vector2dLengthSq = v.x * v.x + v.y * v.y
END FUNCTION

FUNCTION vector2dLength (v AS tVECTOR2d)
  vector2dLength = SQR(vector2dLengthSq(v))
END FUNCTION

SUB vector2dRotate (v AS tVECTOR2d, radians AS _FLOAT)
  DIM c, s, xp, yp AS _FLOAT
  c = COS(radians)
  s = SIN(radians)
  xp = v.x * c - v.y * s
  yp = v.x * s + v.y * c
  v.x = xp
  v.y = yp
END SUB

SUB vector2dNormalize (v AS tVECTOR2d)
  DIM lenSQ, invLen AS _FLOAT
  lenSQ = vector2dLengthSq(v)
  IF lenSQ > cEPSILON_SQ THEN
    invLen = 1.0 / SQR(lenSQ)
    v.x = v.x * invLen
    v.y = v.y * invLen
  END IF
END SUB

SUB vector2dMin (a AS tVECTOR2d, b AS tVECTOR2d, o AS tVECTOR2d)
  o.x = scalarMin(a.x, b.x)
  o.y = scalarMin(a.y, b.y)
END SUB

SUB vector2dMax (a AS tVECTOR2d, b AS tVECTOR2d, o AS tVECTOR2d)
  o.x = scalarMax(a.x, b.x)
  o.y = scalarMax(a.y, b.y)
END SUB

FUNCTION vector2dDot (a AS tVECTOR2d, b AS tVECTOR2d)
  vector2dDot = a.x * b.x + a.y * b.y
END FUNCTION

FUNCTION vector2dSqDist (a AS tVECTOR2d, b AS tVECTOR2d)
  DIM dx, dy AS _FLOAT
  dx = b.x - a.x
  dy = b.y - a.y
  vector2dSqDist = dx * dx + dy * dy
END FUNCTION

FUNCTION vector2dDistance (a AS tVECTOR2d, b AS tVECTOR2d)
  vector2dDistance = SQR(vector2dSqDist(a, b))
END FUNCTION

FUNCTION vector2dCross (a AS tVECTOR2d, b AS tVECTOR2d)
  vector2dCross = a.x * b.y - a.y * b.x
END FUNCTION

SUB vector2dCrossScalar (o AS tVECTOR2d, v AS tVECTOR2d, a AS _FLOAT)
  o.x = v.y * -a
  o.y = v.x * a
END SUB

FUNCTION vector2dArea (a AS tVECTOR2d, b AS tVECTOR2d, c AS tVECTOR2d)
  vector2dArea = (((b.x - a.x) * (c.y - a.y)) - ((c.x - a.x) * (b.y - a.y)))
END FUNCTION

FUNCTION vector2dLeft (a AS tVECTOR2d, b AS tVECTOR2d, c AS tVECTOR2d)
  vector2dLeft = vector2dArea(a, b, c) > 0
END FUNCTION

FUNCTION vector2dLeftOn (a AS tVECTOR2d, b AS tVECTOR2d, c AS tVECTOR2d)
  vector2dLeftOn = vector2dArea(a, b, c) >= 0
END FUNCTION

FUNCTION vector2dRight (a AS tVECTOR2d, b AS tVECTOR2d, c AS tVECTOR2d)
  vector2dRight = vector2dArea(a, b, c) < 0
END FUNCTION

FUNCTION vector2dRightOn (a AS tVECTOR2d, b AS tVECTOR2d, c AS tVECTOR2d)
  vector2dRightOn = vector2dArea(a, b, c) <= 0
END FUNCTION

FUNCTION vector2dCollinear (a AS tVECTOR2d, b AS tVECTOR2d, c AS tVECTOR2d, thresholdAngle AS _FLOAT)
  IF (thresholdAngle = 0) THEN
    vector2dCollinear = (vector2dArea(a, b, c) = 0)
  ELSE
    DIM ab AS tVECTOR2d
    DIM bc AS tVECTOR2d
    DIM dot AS _FLOAT
    DIM magA AS _FLOAT
    DIM magB AS _FLOAT
    DIM angle AS _FLOAT

    ab.x = b.x - a.x
    ab.y = b.y - a.y
    bc.x = c.x - b.x
    bc.y = c.y - b.y

    dot = ab.x * bc.x + ab.y * bc.y
    magA = SQR(ab.x * ab.x + ab.y * ab.y)
    magB = SQR(bc.x * bc.x + bc.y * bc.y)
    angle = _ACOS(dot / (magA * magB))
    vector2dCollinear = angle < thresholdAngle
  END IF
END FUNCTION

SUB vector2dGetSupport (p() AS tPOLY, body() AS tBODY, index AS LONG, dir AS tVECTOR2d, bestVertex AS tVECTOR2d)
  DIM bestProjection AS _FLOAT
  DIM v AS tVECTOR2d
  DIM projection AS _FLOAT
  DIM i AS LONG
  bestVertex.x = -9999999
  bestVertex.y = -9999999
  bestProjection = -9999999

  FOR i = 0 TO body(index).pa.count
    v = p(i + body(index).pa.start).vert
    projection = vector2dDot(v, dir)
    IF projection > bestProjection THEN
      bestVertex = v
      bestProjection = projection
    END IF
  NEXT
END SUB

SUB vector2dLERP (curr AS tVECTOR2d, start AS tVECTOR2d, target AS tVECTOR2d, inc AS _FLOAT)
  curr.x = scalarLERP(start.x, target.x, inc)
  curr.y = scalarLERP(start.y, target.y, inc)
END SUB

SUB vector2dLERPSmooth (curr AS tVECTOR2d, start AS tVECTOR2d, target AS tVECTOR2d, inc AS _FLOAT)
  curr.x = scalarLERPSmooth(start.x, target.x, inc)
  curr.y = scalarLERPSmooth(start.y, target.y, inc)
END SUB

SUB vector2dLERPSmoother (curr AS tVECTOR2d, start AS tVECTOR2d, target AS tVECTOR2d, inc AS _FLOAT)
  curr.x = scalarLERPSmoother(start.x, target.x, inc)
  curr.y = scalarLERPSmoother(start.y, target.y, inc)
END SUB

SUB vector2dOrbitVector (o AS tVECTOR2d, position AS tVECTOR2d, dist AS _FLOAT, angle AS _FLOAT)
  o.x = COS(angle) * dist + position.x
  o.y = SIN(angle) * dist + position.y
END SUB

FUNCTION vector2dRoughEqual (a AS tVECTOR2d, b AS tVECTOR2d, tolerance AS _FLOAT)
  vector2dRoughEqual = scalarRoughEqual(a.x, b.x, tolerance) AND scalarRoughEqual(a.y, b.y, tolerance)
END FUNCTION

'**********************************************************************************************
'   Matrix Math Functions
'**********************************************************************************************

SUB _______________MATRIX_FUNCTIONS (): END SUB
SUB matrix2x2SetRadians (m AS tMATRIX2d, radians AS _FLOAT)
  DIM c AS _FLOAT
  DIM s AS _FLOAT
  c = COS(radians)
  s = SIN(radians)
  m.m00 = c
  m.m01 = -s
  m.m10 = s
  m.m11 = c
END SUB

SUB matrix2x2SetScalar (m AS tMATRIX2d, a AS _FLOAT, b AS _FLOAT, c AS _FLOAT, d AS _FLOAT)
  m.m00 = a
  m.m01 = b
  m.m10 = c
  m.m11 = d
END SUB

SUB matrix2x2Abs (m AS tMATRIX2d, o AS tMATRIX2d)
  o.m00 = ABS(m.m00)
  o.m01 = ABS(m.m01)
  o.m10 = ABS(m.m10)
  o.m11 = ABS(m.m11)
END SUB

SUB matrix2x2GetAxisX (m AS tMATRIX2d, o AS tVECTOR2d)
  o.x = m.m00
  o.y = m.m10
END SUB

SUB matrix2x2GetAxisY (m AS tMATRIX2d, o AS tVECTOR2d)
  o.x = m.m01
  o.y = m.m11
END SUB

SUB matrix2x2TransposeI (m AS tMATRIX2d)
  SWAP m.m01, m.m10
END SUB

SUB matrix2x2Transpose (m AS tMATRIX2d, o AS tMATRIX2d)
  DIM tm AS tMATRIX2d
  tm.m00 = m.m00
  tm.m01 = m.m10
  tm.m10 = m.m01
  tm.m11 = m.m11
  o = tm
END SUB

SUB matrix2x2Invert (m AS tMATRIX2d, o AS tMATRIX2d)
  DIM a, b, c, d, det AS _FLOAT
  DIM tm AS tMATRIX2d

  a = m.m00: b = m.m01: c = m.m10: d = m.m11
  det = a * d - b * c
  IF det = 0 THEN EXIT SUB

  det = 1 / det
  tm.m00 = det * d: tm.m01 = -det * b
  tm.m10 = -det * c: tm.m11 = det * a
  o = tm
END SUB

SUB matrix2x2MultiplyVector (m AS tMATRIX2d, v AS tVECTOR2d, o AS tVECTOR2d)
  DIM t AS tVECTOR2d
  t.x = m.m00 * v.x + m.m01 * v.y
  t.y = m.m10 * v.x + m.m11 * v.y
  o = t
END SUB

SUB matrix2x2AddMatrix (m AS tMATRIX2d, x AS tMATRIX2d, o AS tMATRIX2d)
  o.m00 = m.m00 + x.m00
  o.m01 = m.m01 + x.m01
  o.m10 = m.m10 + x.m10
  o.m11 = m.m11 + x.m11
END SUB

SUB matrix2x2MultiplyMatrix (m AS tMATRIX2d, x AS tMATRIX2d, o AS tMATRIX2d)
  o.m00 = m.m00 * x.m00 + m.m01 * x.m10
  o.m01 = m.m00 * x.m01 + m.m01 * x.m11
  o.m10 = m.m10 * x.m00 + m.m11 * x.m10
  o.m11 = m.m10 * x.m01 + m.m11 * x.m11
END SUB

'**********************************************************************************************
'   Impulse Math
'**********************************************************************************************
SUB _______________IMPULSE_MATH (): END SUB

FUNCTION impulseEqual (a AS _FLOAT, b AS _FLOAT)
  impulseEqual = ABS(a - b) <= cEPSILON
END FUNCTION

FUNCTION impulseClamp## (min AS _FLOAT, max AS _FLOAT, a AS _FLOAT)
  IF a < min THEN
    impulseClamp## = min
  ELSE IF a > max THEN
      impulseClamp## = max
    ELSE
      impulseClamp## = a
    END IF
  END IF
END FUNCTION

FUNCTION impulseRound## (a AS _FLOAT)
  impulseRound = INT(a + 0.5)
END FUNCTION

FUNCTION impulseRandomFloat## (min AS _FLOAT, max AS _FLOAT)
  impulseRandomFloat = ((max - min) * RND + min)
END FUNCTION

FUNCTION impulseRandomInteger (min AS LONG, max AS LONG)
  impulseRandomInteger = INT((max - min) * RND + min)
END FUNCTION

FUNCTION impulseGT (a AS _FLOAT, b AS _FLOAT)
  impulseGT = (a >= b * cBIAS_RELATIVE + a * cBIAS_ABSOLUTE)
END FUNCTION

'**********************************************************************************************
'   Misc
'**********************************************************************************************

SUB _______________MISC_HELPER_FUNCTIONS (): END SUB

SUB polygonMakeCCW (obj AS tTRIANGLE)
  IF vector2dLeft(obj.a, obj.b, obj.c) = 0 THEN
    SWAP obj.a, obj.c
  END IF
END SUB

FUNCTION polygonIsReflex (t AS tTRIANGLE)
  polygonIsReflex = vector2dRight(t.a, t.b, t.c)
END FUNCTION

SUB polygonSetOrient (b AS tBODY, radians AS _FLOAT)
  matrix2x2SetRadians b.shape.u, radians
END SUB

SUB polygonInvertNormals (p() AS tPOLY, b() AS tBODY, index AS LONG)
  DIM AS LONG i
  FOR i = 0 TO b(index).pa.count
    vector2dNeg p(b(index).pa.start + i).norm
  NEXT
END SUB

'**********************************************************************************************
'   Scalar helper functions
'**********************************************************************************************
SUB _______________SCALAR_HELPER_FUNCTIONS (): END SUB

FUNCTION scalarMin (a AS _FLOAT, b AS _FLOAT)
  IF a < b THEN
    scalarMin = a
  ELSE
    scalarMin = b
  END IF
END FUNCTION

FUNCTION scalarMax (a AS _FLOAT, b AS _FLOAT)
  IF a > b THEN
    scalarMax = a
  ELSE
    scalarMax = b
  END IF
END FUNCTION

FUNCTION scalarMap## (x AS _FLOAT, in_min AS _FLOAT, in_max AS _FLOAT, out_min AS _FLOAT, out_max AS _FLOAT)
  scalarMap## = (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
END FUNCTION

FUNCTION scalarLERP## (current AS _FLOAT, target AS _FLOAT, t AS _FLOAT)
  t = impulseClamp##(0, 1, t)
  scalarLERP## = current + (target - current) * t
END FUNCTION

FUNCTION scalarLERPSmooth## (current AS _FLOAT, target AS _FLOAT, t AS _FLOAT)
  t = impulseClamp##(0, 1, t)
  scalarLERPSmooth## = scalarLERP##(current, target, t * t * (3.0 - 2.0 * t))
END FUNCTION

FUNCTION scalarLERPSmoother## (current AS _FLOAT, target AS _FLOAT, t AS _FLOAT)
  t = impulseClamp##(0, 1, t)
  scalarLERPSmoother## = scalarLERP##(current, target, t * t * t * (t * (t * 6.0 - 15.0) + 10.0))
END FUNCTION

FUNCTION scalarLERPProgress## (startTime AS _FLOAT, endTime AS _FLOAT)
  scalarLERPProgress## = impulseClamp(0, 1, (TIMER(.001) - startTime) / (endTime - startTime))
END FUNCTION

FUNCTION scalarRoughEqual (a AS _FLOAT, b AS _FLOAT, tolerance AS _FLOAT)
  scalarRoughEqual = ABS(a - b) <= tolerance
END FUNCTION


'**********************************************************************************************
'   Procedural Generation Helper Functions
'**********************************************************************************************
SUB _______________PROC_GEN_HELPER_FUNCTIONS (): END SUB

FUNCTION perlinInterpolate## (a0 AS _FLOAT, a1 AS _FLOAT, w AS _FLOAT)
  perlinInterpolate## = scalarLERPSmoother##(a0, a1, w)
END FUNCTION

' Create random direction vector
SUB perlinRandomGradient (seed AS _FLOAT, ix AS INTEGER, iy AS INTEGER, o AS tVECTOR2d)
  ' Random float. No precomputed gradients mean this works for any number of grid coordinates
  DIM AS _FLOAT prandom
  prandom = seed * SIN(ix * 21942.0 + iy * 171324.0 + 8912.0) * COS(ix * 23157.0 * iy * 217832.0 + 9758.0)
  o.x = COS(prandom)
  o.y = SIN(prandom)
END SUB

' Computes the dot product of the distance and gradient vectors.
FUNCTION perlinDotGridGradient## (seed AS _FLOAT, ix AS INTEGER, iy AS INTEGER, x AS _FLOAT, y AS _FLOAT)
  DIM AS tVECTOR2d gradient
  DIM AS _FLOAT dx, dy
  ' Get gradient from integer coordinates
  perlinRandomGradient seed, ix, iy, gradient
  ' Compute the distance vector
  dx = x - ix
  dy = y - iy
  ' Compute the dot-product
  perlinDotGridGradient## = dx * gradient.x + dy * gradient.y
END FUNCTION

' Compute Perlin noise at coordinates x, y
FUNCTION perlin## (x AS _FLOAT, y AS _FLOAT, seed AS _FLOAT)
  ' Determine grid cell coordinates
  DIM AS INTEGER x0, x1, y0, y1
  DIM AS _FLOAT sx, sy, n0, n1, ix0, ix1
  x0 = INT(x)
  x1 = x0 + 1
  y0 = INT(y)
  y1 = y0 + 1

  ' Determine interpolation weights
  ' Could also use higher order polynomial/s-curve here
  sx = x - x0
  sy = y - y0

  ' Interpolate between grid point gradients
  n0 = perlinDotGridGradient##(seed, x0, y0, x, y)
  n1 = perlinDotGridGradient##(seed, x1, y0, x, y)
  ix0 = perlinInterpolate##(n0, n1, sx)

  n0 = perlinDotGridGradient##(seed, x0, y1, x, y)
  n1 = perlinDotGridGradient##(seed, x1, y1, x, y)
  ix1 = perlinInterpolate##(n0, n1, sx)

  perlin## = perlinInterpolate##(ix0, ix1, sy)
END FUNCTION

'**********************************************************************************************
'   Line Segment Helper Functions
'**********************************************************************************************
SUB _______________LINE_SEG_HELPER_FUNCTIONS (): END SUB

SUB lineIntersection (l1 AS tLINE2d, l2 AS tLINE2d, o AS tVECTOR2d)
  DIM a1, b1, c1, a2, b2, c2, det AS _FLOAT
  o.x = 0
  o.y = 0
  a1 = l1.b.y - l1.a.y
  b1 = l1.a.x - l1.b.x
  c1 = a1 * l1.a.x + b1 * l1.a.y
  a2 = l2.b.y - l2.a.y
  b2 = l2.a.x - l2.b.x
  c2 = a2 * l2.a.x + b2 * l2.a.y
  det = a1 * b2 - a2 * b1

  IF INT(det * cPRECISION) <> 0 THEN
    o.x = (b2 * c1 - b1 * c2) / det
    o.y = (a1 * c2 - a2 * c1) / det
  END IF
END SUB

FUNCTION lineSegmentsIntersect (l1 AS tLINE2d, l2 AS tLINE2d)
  DIM dx, dy, da, db, s, t AS _FLOAT
  dx = l1.b.x - l1.a.x
  dy = l1.b.y - l1.a.y
  da = l2.b.x - l2.a.x
  db = l2.b.y - l2.a.y
  IF da * dy - db * dx = 0 THEN
    lineSegmentsIntersect = 0
  ELSE
    s = (dx * (l2.a.y - l1.a.y) + dy * (l1.a.x - l2.a.x)) / (da * dy - db * dx)
    t = (da * (l1.a.y - l2.a.y) + db * (l2.a.x - l1.a.x)) / (db * dx - da * dy)
    lineSegmentsIntersect = (s >= 0 AND s <= 1 AND t >= 0 AND t <= 1)
  END IF
END FUNCTION

'**********************************************************************************************
'   AABB helper functions
'**********************************************************************************************
SUB _______________AABB_HELPER_FUNCTIONS (): END SUB

FUNCTION AABBOverlap (Ax AS _FLOAT, Ay AS _FLOAT, Aw AS _FLOAT, Ah AS _FLOAT, Bx AS _FLOAT, By AS _FLOAT, Bw AS _FLOAT, Bh AS _FLOAT)
  AABBOverlap = Ax < Bx + Bw AND Ax + Aw > Bx AND Ay < By + Bh AND Ay + Ah > By
END FUNCTION

FUNCTION AABBOverlapVector (A AS tVECTOR2d, Aw AS _FLOAT, Ah AS _FLOAT, B AS tVECTOR2d, Bw AS _FLOAT, Bh AS _FLOAT)
  AABBOverlapVector = AABBOverlap(A.x, A.y, Aw, Ah, B.x, B.y, Bw, Bh)
END FUNCTION

FUNCTION AABBOverlapObjects (body() AS tBODY, a AS LONG, b AS LONG)
  DIM AS tVECTOR2d am, bm, mam, mbm
  am.x = scalarMax(body(a).shape.maxDimension.x, body(a).shape.maxDimension.y) / 2
  am.y = scalarMax(body(a).shape.maxDimension.x, body(a).shape.maxDimension.y) / 2

  bm.x = scalarMax(body(b).shape.maxDimension.x, body(b).shape.maxDimension.y) / 2
  bm.y = scalarMax(body(b).shape.maxDimension.x, body(b).shape.maxDimension.y) / 2

  mam = am
  mbm = bm
  vector2dSubVectorND am, body(a).fzx.position, am
  vector2dSubVectorND bm, body(b).fzx.position, bm

  AABBOverlapObjects = AABBOverlap(am.x, am.y, mam.x * 2, mam.y * 2, bm.x, bm.y, mbm.x * 2, mbm.y * 2)
END FUNCTION


'**********************************************************************************************
'   Body Initilization
'**********************************************************************************************
SUB _______________BODY_INIT_FUNCTIONS (): END SUB

SUB circleInitialize (b() AS tBODY, index AS LONG)
  circleComputeMass b(), index, cMASS_DENSITY
END SUB

SUB circleComputeMass (b() AS tBODY, index AS LONG, density AS _FLOAT)
  b(index).fzx.mass = cPI * b(index).shape.radius * b(index).shape.radius * density
  IF b(index).fzx.mass <> 0 THEN
    b(index).fzx.invMass = 1.0 / b(index).fzx.mass
  ELSE
    b(index).fzx.invMass = 0.0
  END IF

  b(index).fzx.inertia = b(index).fzx.mass * b(index).shape.radius * b(index).shape.radius

  IF b(index).fzx.inertia <> 0 THEN
    b(index).fzx.invInertia = 1.0 / b(index).fzx.inertia
  ELSE
    b(index).fzx.invInertia = 0.0
  END IF
END SUB

SUB polygonInitialize (body() AS tBODY, p() AS tPOLY, index AS LONG)
  polygonComputeMass body(), p(), index, cMASS_DENSITY
END SUB

SUB polygonComputeMass (b() AS tBODY, p() AS tPOLY, index AS LONG, density AS _FLOAT)
  DIM c AS tVECTOR2d ' centroid
  DIM p1 AS tVECTOR2d
  DIM p2 AS tVECTOR2d
  DIM area AS _FLOAT
  DIM I AS _FLOAT
  DIM k_inv3 AS _FLOAT
  DIM D AS _FLOAT
  DIM triangleArea AS _FLOAT
  DIM weight AS _FLOAT
  DIM intx2 AS _FLOAT
  DIM inty2 AS _FLOAT
  DIM ii AS LONG

  k_inv3 = 1.0 / 3.0

  FOR ii = 0 TO b(index).pa.count
    p1 = p(b(index).pa.start + ii).vert
    p2 = p(b(index).pa.start + arrayNextIndex(ii, b(index).pa.count)).vert
    D = vector2dCross(p1, p2)
    triangleArea = .5 * D
    area = area + triangleArea
    weight = triangleArea * k_inv3
    vector2dAddVectorScalar c, p1, weight
    vector2dAddVectorScalar c, p2, weight
    intx2 = p1.x * p1.x + p2.x * p1.x + p2.x * p2.x
    inty2 = p1.y * p1.y + p2.y * p1.y + p2.y * p2.y
    I = I + (0.25 * k_inv3 * D) * (intx2 + inty2)
  NEXT ii

  vector2dMultiplyScalar c, 1.0 / area

  FOR ii = 0 TO b(index).pa.count
    vector2dSubVector p(b(index).pa.start + ii).vert, c
  NEXT

  b(index).fzx.mass = density * area
  IF b(index).fzx.mass <> 0.0 THEN
    b(index).fzx.invMass = 1.0 / b(index).fzx.mass
  ELSE
    b(index).fzx.invMass = 0.0
  END IF

  b(index).fzx.inertia = I * density
  IF b(index).fzx.inertia <> 0 THEN
    b(index).fzx.invInertia = 1.0 / b(index).fzx.inertia
  ELSE
    b(index).fzx.invInertia = 0.0
  END IF
END SUB

'**********************************************************************************************
'   Body Creation
'**********************************************************************************************

SUB _______________BODY_CREATION_FUNCTIONS (): END SUB

FUNCTION createCircleBody (body() AS tBODY, index AS LONG, radius AS _FLOAT)
  DIM shape AS tSHAPE
  shapeCreate shape, cSHAPE_CIRCLE, radius
  shape.maxDimension.x = radius * cAABB_TOLERANCE
  shape.maxDimension.y = radius * cAABB_TOLERANCE
  bodyCreate body(), index, shape
  'no vertices have to created for circles
  circleInitialize body(), index
  ' Even though circles do not have vertices, they still must be included in the vertices list
  IF index = 0 THEN
    body(index).pa.start = 0
  ELSE
    body(index).pa.start = body(index - 1).pa.start + body(index - 1).pa.count + 1
  END IF
  body(index).pa.count = 1
  body(index).c = _RGB32(255, 255, 255)
  createCircleBody = index
END FUNCTION

FUNCTION createCircleBodyEx (body() AS tBODY, objName AS STRING, radius AS _FLOAT)
  DIM shape AS tSHAPE
  DIM index AS LONG
  shapeCreate shape, cSHAPE_CIRCLE, radius
  shape.maxDimension.x = radius * cAABB_TOLERANCE
  shape.maxDimension.y = radius * cAABB_TOLERANCE
  bodyCreateEx body(), objName, shape, index
  'no vertices have to created for circles
  circleInitialize body(), index
  ' Even though circles do not have vertices, they still must be included in the vertices list
  IF index = 0 THEN
    body(index).pa.start = 0
  ELSE
    body(index).pa.start = body(index - 1).pa.start + body(index - 1).pa.count + 1
  END IF
  body(index).pa.count = 1
  body(index).c = _RGB32(255, 255, 255)
  createCircleBodyEx = index
END FUNCTION


FUNCTION createBoxBody (p() AS tPOLY, body() AS tBODY, index AS LONG, xs AS _FLOAT, ys AS _FLOAT)
  DIM shape AS tSHAPE
  shapeCreate shape, cSHAPE_POLYGON, 0
  shape.maxDimension.x = xs * cAABB_TOLERANCE
  shape.maxDimension.y = ys * cAABB_TOLERANCE
  bodyCreate body(), index, shape
  boxCreate p(), body(), index, xs, ys
  polygonInitialize body(), p(), index
  body(index).c = _RGB32(255, 255, 255)
  createBoxBody = index
END FUNCTION

FUNCTION createBoxBodyEx (p() AS tPOLY, body() AS tBODY, objName AS STRING, xs AS _FLOAT, ys AS _FLOAT)
  DIM shape AS tSHAPE
  DIM index AS LONG
  shapeCreate shape, cSHAPE_POLYGON, 0
  shape.maxDimension.x = xs * cAABB_TOLERANCE
  shape.maxDimension.y = ys * cAABB_TOLERANCE

  bodyCreateEx body(), objName, shape, index
  boxCreate p(), body(), index, xs, ys
  polygonInitialize body(), p(), index
  body(index).c = _RGB32(255, 255, 255)
  createBoxBodyEx = index
END FUNCTION

SUB createTrapBody (p() AS tPOLY, body() AS tBODY, index AS LONG, xs AS _FLOAT, ys AS _FLOAT, yoff1 AS _FLOAT, yoff2 AS _FLOAT)
  DIM shape AS tSHAPE
  shapeCreate shape, cSHAPE_POLYGON, 0
  shape.maxDimension.x = xs * cAABB_TOLERANCE
  shape.maxDimension.y = ys * cAABB_TOLERANCE

  bodyCreate body(), index, shape
  trapCreate p(), body(), index, xs, ys, yoff1, yoff2
  polygonInitialize body(), p(), index
  body(index).c = _RGB32(255, 255, 255)
END SUB

SUB createTrapBodyEx (p() AS tPOLY, body() AS tBODY, objName AS STRING, xs AS _FLOAT, ys AS _FLOAT, yoff1 AS _FLOAT, yoff2 AS _FLOAT)
  DIM shape AS tSHAPE
  DIM index AS LONG
  shapeCreate shape, cSHAPE_POLYGON, 0
  shape.maxDimension.x = xs * cAABB_TOLERANCE
  shape.maxDimension.y = ys * cAABB_TOLERANCE

  bodyCreateEx body(), objName, shape, index
  trapCreate p(), body(), index, xs, ys, yoff1, yoff2
  polygonInitialize body(), p(), index
  body(index).c = _RGB32(255, 255, 255)
END SUB

SUB bodyCreateEx (body() AS tBODY, objName AS STRING, shape AS tSHAPE, index AS LONG)
  index = bodyManagerAdd(body())
  body(index).objectName = objName
  body(index).objectHash = computeHash&&(objName)
  bodyCreate body(), index, shape
END SUB


SUB bodyCreate (body() AS tBODY, index AS LONG, shape AS tSHAPE)
  vector2dSet body(index).fzx.position, 0, 0
  vector2dSet body(index).fzx.velocity, 0, 0
  body(index).fzx.angularVelocity = 0.0
  body(index).fzx.torque = 0.0
  body(index).fzx.orient = 0.0

  vector2dSet body(index).fzx.force, 0, 0
  body(index).fzx.staticFriction = 0.5
  body(index).fzx.dynamicFriction = 0.3
  body(index).fzx.restitution = 0.2
  body(index).shape = shape
  body(index).collisionMask = 255
  body(index).enable = 1
  body(index).noPhysics = 0
END SUB

SUB boxCreate (p() AS tPOLY, body() AS tBODY, index AS LONG, sizex AS _FLOAT, sizey AS _FLOAT)
  DIM vertlength AS LONG: vertlength = 3
  DIM verts(vertlength) AS tVECTOR2d

  vector2dSet verts(0), -sizex, -sizey
  vector2dSet verts(1), sizex, -sizey
  vector2dSet verts(2), sizex, sizey
  vector2dSet verts(3), -sizex, sizey

  vertexSet p(), body(), index, verts()
END SUB

SUB trapCreate (p() AS tPOLY, body() AS tBODY, index AS LONG, sizex AS _FLOAT, sizey AS _FLOAT, yOff1 AS _FLOAT, yOff2 AS _FLOAT)
  DIM vertlength AS LONG: vertlength = 3
  DIM verts(vertlength) AS tVECTOR2d

  vector2dSet verts(0), -sizex, -sizey - yOff2
  vector2dSet verts(1), sizex, -sizey - yOff1
  vector2dSet verts(2), sizex, sizey
  vector2dSet verts(3), -sizex, sizey

  vertexSet p(), body(), index, verts()
END SUB

SUB createTerrianBody (p() AS tPOLY, body() AS tBODY, index AS LONG, slices AS LONG, sliceWidth AS _FLOAT, nominalHeight AS _FLOAT)
  DIM shape AS tSHAPE
  DIM elevation(slices) AS _FLOAT
  DIM AS LONG i, j

  FOR j = 0 TO slices
    elevation(j) = RND * 500
  NEXT

  shapeCreate shape, cSHAPE_POLYGON, 0

  FOR i = 0 TO slices - 1
    bodyCreate body(), index + i, shape
    terrainCreate p(), body(), index + i, elevation(i), elevation(i + 1), sliceWidth, nominalHeight
    polygonInitialize body(), p(), index + i
    body(index + i).c = _RGB32(255, 255, 255)
    bodySetStatic body(index + i)
  NEXT i
END SUB

SUB createTerrianBodyEx (p() AS tPOLY, body() AS tBODY, world AS tWORLD, objName AS STRING, elevation() AS _FLOAT, slices AS LONG, sliceWidth AS _FLOAT, nominalHeight AS _FLOAT)
  DIM shape AS tSHAPE
  DIM AS LONG i, index

  shapeCreate shape, cSHAPE_POLYGON, 0

  FOR i = 0 TO slices - 1
    bodyCreateEx body(), objName + "_" + LTRIM$(STR$(i)), shape, index
    terrainCreate p(), body(), index, elevation(i), elevation(i + 1), sliceWidth, nominalHeight
    polygonInitialize body(), p(), index
    body(index).c = _RGB32(255, 255, 255)
    bodySetStatic body(index)
  NEXT i

  DIM AS _FLOAT p1, p2
  DIM start AS _INTEGER64

  FOR i = 0 TO slices - 1
    start = bodyManagerID(body(), objName + "_" + LTRIM$(STR$(i)))
    p1 = (sliceWidth / 2) - p(body(start).pa.start).vert.x
    p2 = nominalHeight - p(body(start).pa.start + 1).vert.y
    setBody p(), body(), cPARAMETER_POSITION, start, world.terrainPosition.x + p1 + (sliceWidth * i), world.terrainPosition.y + p2
  NEXT
END SUB

SUB terrainCreate (p() AS tPOLY, body() AS tBODY, index AS LONG, ele1 AS _FLOAT, ele2 AS _FLOAT, sliceWidth AS _FLOAT, nominalHeight AS _FLOAT)
  DIM AS LONG vertLength
  vertLength = 3 ' numOfslices + 1
  DIM verts(vertLength) AS tVECTOR2d

  vector2dSet verts(0), 0, nominalHeight
  vector2dSet verts(1), (0) * sliceWidth, -nominalHeight - ele1
  vector2dSet verts(2), (1) * sliceWidth, -nominalHeight - ele2
  vector2dSet verts(3), (1) * sliceWidth, nominalHeight
  vertexSet p(), body(), index, verts()
END SUB

SUB vShapeCreate (p() AS tPOLY, body() AS tBODY, index AS LONG, sizex AS _FLOAT, sizey AS _FLOAT)
  DIM vertlength AS LONG: vertlength = 7
  DIM verts(vertlength) AS tVECTOR2d

  vector2dSet verts(0), -sizex, -sizey
  vector2dSet verts(1), sizex, -sizey
  vector2dSet verts(2), sizex, sizey
  vector2dSet verts(3), -sizex, sizey
  vector2dSet verts(4), -sizex, sizey / 2
  vector2dSet verts(5), sizex / 2, sizey / 2
  vector2dSet verts(6), sizex / 2, -sizey / 2
  vector2dSet verts(7), -sizex, sizey / 2

  vertexSet p(), body(), index, verts()
END SUB

'**********************************************************************************************
' Vertex set function
' This function verifies proper rotation to calculate Normals used in Collisions
' This function also removes Concave surfaces for collisions
'**********************************************************************************************

SUB _______________VERTEX_SET_FUNCTION (): END SUB
SUB vertexSet (p() AS tPOLY, body() AS tBODY, index AS LONG, verts() AS tVECTOR2d)
  DIM rightMost AS LONG: rightMost = 0
  DIM highestXCoord AS _FLOAT: highestXCoord = verts(0).x
  DIM AS LONG i, vertLength
  DIM x AS _FLOAT
  vertLength = UBOUND(verts)
  FOR i = 1 TO vertLength
    x = verts(i).x
    IF x > highestXCoord THEN
      highestXCoord = x
      rightMost = i
    ELSE
      IF x = highestXCoord THEN
        IF verts(i).y < verts(rightMost).y THEN
          rightMost = i
        END IF
      END IF
    END IF
  NEXT
  DIM hull(vertLength * 2) AS LONG
  DIM outCount AS LONG: outCount = 0
  DIM indexHull AS LONG: indexHull = rightMost
  DIM nextHullIndex AS LONG
  DIM e1 AS tVECTOR2d
  DIM e2 AS tVECTOR2d
  DIM c AS _FLOAT
  DO
    hull(outCount) = indexHull
    nextHullIndex = 0
    FOR i = 1 TO vertLength
      IF nextHullIndex = indexHull THEN
        nextHullIndex = i
        _CONTINUE
      END IF
      vector2dSubVectorND e1, verts(nextHullIndex), verts(hull(outCount))
      vector2dSubVectorND e2, verts(i), verts(hull(outCount))
      c = vector2dCross(e1, e2)
      IF c < 0.0 THEN nextHullIndex = i
      IF c = 0.0 AND (vector2dLengthSq(e2) > vector2dLengthSq(e1)) THEN
        nextHullIndex = i
      END IF
    NEXT
    outCount = outCount + 1
    indexHull = nextHullIndex
    IF nextHullIndex = rightMost THEN
      body(index).pa.count = outCount - 1
      EXIT DO
    END IF
  LOOP

  IF index = 0 THEN
    body(index).pa.start = 0
  ELSE
    body(index).pa.start = body(index - 1).pa.start + body(index - 1).pa.count + 1
  END IF

  'Make sure we don't runout of room
  IF body(index).pa.start + vertLength > UBOUND(p) THEN
    REDIM _PRESERVE p((body(index).pa.start + vertLength) * 2) AS tPOLY
  END IF

  FOR i = 0 TO vertLength
    p(body(index).pa.start + i).vert = verts(hull(i))
  NEXT

  DIM face AS tVECTOR2d
  FOR i = 0 TO vertLength
    vector2dSubVectorND face, p(body(index).pa.start + arrayNextIndex(i, body(index).pa.count)).vert, p(body(index).pa.start + i).vert
    vector2dSet p(body(index).pa.start + i).norm, face.y, -face.x
    vector2dNormalize p(body(index).pa.start + i).norm
  NEXT
END SUB
'**********************************************************************************************
'   Shape Function
'**********************************************************************************************
SUB _______________SHAPE_INIT_FUNCTION (): END SUB
SUB shapeCreate (sh AS tSHAPE, ty AS LONG, radius AS _FLOAT)
  DIM u AS tMATRIX2d
  matrix2x2SetScalar u, 1, 0, 0, 1
  sh.ty = ty
  sh.radius = radius
  sh.u = u
  sh.scaleTextureX = 1.0
  sh.scaleTextureY = 1.0
  sh.renderOrder = 1 ' 0 - will be the front most rendering
END SUB

'**********************************************************************************************
'   Body Tools
'**********************************************************************************************

SUB _______________BODY_PARAMETER_FUNCTIONS (): END SUB

SUB setBody (p() AS tPOLY, body() AS tBODY, Parameter AS LONG, Index AS LONG, arg1 AS _FLOAT, arg2 AS _FLOAT)
  SELECT CASE Parameter
    CASE cPARAMETER_POSITION:
      vector2dSet body(Index).fzx.position, arg1, arg2
    CASE cPARAMETER_VELOCITY:
      vector2dSet body(Index).fzx.velocity, arg1, arg2
    CASE cPARAMETER_FORCE:
      vector2dSet body(Index).fzx.force, arg1, arg2
    CASE cPARAMETER_ANGULARVELOCITY:
      body(Index).fzx.angularVelocity = arg1
    CASE cPARAMETER_TORQUE:
      body(Index).fzx.torque = arg1
    CASE cPARAMETER_ORIENT:
      body(Index).fzx.orient = arg1
      matrix2x2SetRadians body(Index).shape.u, body(Index).fzx.orient
    CASE cPARAMETER_STATICFRICTION:
      body(Index).fzx.staticFriction = arg1
    CASE cPARAMETER_DYNAMICFRICTION:
      body(Index).fzx.dynamicFriction = arg1
    CASE cPARAMETER_RESTITUTION:
      body(Index).fzx.restitution = arg1
    CASE cPARAMETER_COLOR:
      body(Index).c = arg1
    CASE cPARAMETER_ENABLE:
      body(Index).enable = arg1
    CASE cPARAMETER_STATIC:
      bodySetStatic body(Index)
    CASE cPARAMETER_TEXTURE:
      body(Index).shape.texture = arg1
    CASE cPARAMETER_FLIPTEXTURE: 'does the texture flip directions when moving left or right
      body(Index).shape.flipTexture = arg1
    CASE cPARAMETER_COLLISIONMASK:
      body(Index).collisionMask = arg1
    CASE cPARAMETER_INVERTNORMALS:
      IF arg1 THEN polygonInvertNormals p(), body(), Index
    CASE cPARAMETER_NOPHYSICS:
      body(Index).noPhysics = arg1
    CASE cPARAMETER_SPECIALFUNCTION:
      body(Index).specFunc.func = arg1
      body(Index).specFunc.arg = arg2
    CASE cPARAMETER_RENDERORDER:
      body(Index).shape.renderOrder = arg1
    CASE cPARAMETER_ENTITYID:
      body(Index).entityID = arg1
  END SELECT
END SUB

SUB setBodyEx (p() AS tPOLY, body() AS tBODY, Parameter AS LONG, objName AS STRING, arg1 AS _FLOAT, arg2 AS _FLOAT)
  DIM index AS LONG
  index = bodyManagerID(body(), objName)
  IF index > -1 THEN
    setBody p(), body(), Parameter, index, arg1, arg2
  END IF
END SUB

SUB bodyStop (body AS tBODY)
  vector2dSet body.fzx.velocity, 0, 0
  body.fzx.angularVelocity = 0
END SUB

SUB bodyOffset (body() AS tBODY, p() AS tPOLY, index AS LONG, vec AS tVECTOR2d)
  DIM i AS LONG
  FOR i = 0 TO body(index).pa.count
    vector2dAddVector p(body(index).pa.start + i).vert, vec
  NEXT
END SUB

SUB bodySetStatic (body AS tBODY)
  body.fzx.inertia = 0.0
  body.fzx.invInertia = 0.0
  body.fzx.mass = 0.0
  body.fzx.invMass = 0.0
END SUB

FUNCTION bodyAtRest (body AS tBODY)
  bodyAtRest = (body.fzx.velocity.x < 1 AND body.fzx.velocity.x > -1 AND body.fzx.velocity.y < 1 AND body.fzx.velocity.y > -1)
END FUNCTION

SUB copyBodies (body() AS tBODY, newBody() AS tBODY)
  DIM AS LONG index
  FOR index = 0 TO UBOUND(body)
    newBody(index) = body(index)
  NEXT
END SUB

'**********************************************************************************************
'   Misc
'**********************************************************************************************

SUB _______________MORE_MISC_FUNCTIONS (): END SUB

SUB shutdown (tile() AS tTILE, network AS tNETWORK)
  freeAllTiles tile()
  networkClose network
  CLOSE logfile
  SYSTEM
END SUB

FUNCTION arrayNextIndex (i AS LONG, count AS LONG)
  arrayNextIndex = ((i + 1) MOD (count + 1))
END FUNCTION

FUNCTION bool (b AS LONG)
  IF b = 0 THEN
    bool = 0
  ELSE
    bool = 1
  END IF
END FUNCTION

SUB waitkey
  _DISPLAY
  DO: LOOP UNTIL INKEY$ <> ""
END SUB

FUNCTION trim$ (in AS STRING)
  trim$ = RTRIM$(LTRIM$(in))
END FUNCTION

'**********************************************************************************************
'   FPS Management
'**********************************************************************************************
SUB _______________FPS_MANAGEMENT (): END SUB

SUB initFPS
  DIM timerOne AS LONG
  timerOne = _FREETIMER
  ON TIMER(timerOne, 1) FPS
  TIMER(timerOne) ON
END SUB

SUB FPS
  fpsCount.fpsLast = fpsCount.fpsCount
  fpsCount.fpsCount = 0
END SUB

SUB handleFPS ()
  DIM fpss AS STRING
  fpsCount.fpsCount = fpsCount.fpsCount + 1
  fpss = "FPS:" + STR$(fpsCount.fpsLast)
  _PRINTSTRING ((_WIDTH / 2) - (_PRINTWIDTH(fpss) / 2), 0), fpss
END SUB

'**********************************************************************************************
'   World to Gamemap Conversions
'**********************************************************************************************

SUB _______________WORLD_TO_GAMEMAP (): END SUB

FUNCTION xyToGameMapPlain (tilemap AS tTILEMAP, x AS LONG, y AS LONG)
  DIM p AS tVECTOR2d
  vector2dSet p, x, y
  xyToGameMapPlain = vector2dToGameMapPlain(tilemap, p)
END FUNCTION

FUNCTION vector2dToGameMapPlain (tilemap AS tTILEMAP, p AS tVECTOR2d)
  vector2dToGameMapPlain = p.x + (p.y * tilemap.mapWidth)
END FUNCTION

FUNCTION xyToGameMap (tilemap AS tTILEMAP, x AS LONG, y AS LONG)
  DIM p AS tVECTOR2d
  vector2dSet p, x, y
  xyToGameMap = vector2dToGameMap(tilemap, p)
END FUNCTION

FUNCTION vector2dToGameMap (tilemap AS tTILEMAP, p AS tVECTOR2d)
  vector2dToGameMap = INT((((p.x * tilemap.tilescale) / tilemap.tileWidth) + ((p.y * tilemap.tilescale) / tilemap.tileHeight) * tilemap.mapWidth))
END FUNCTION

'**********************************************************************************************
'   TIMER
'**********************************************************************************************
SUB _______________TIMER_CODE (): END SUB

SUB handleTimers
  DIM AS LONG i
  FOR i = 0 TO UBOUND(timers)
    timers(i).last = TIMER(.001)
  NEXT
END SUB

FUNCTION addTimer (duration AS LONG)
  timers(UBOUND(timers)).start = TIMER(.001)
  timers(UBOUND(timers)).duration = duration
  addTimer = UBOUND(timers)
  REDIM _PRESERVE timers(UBOUND(timers) + 1) AS tELAPSEDTIMER
END FUNCTION

SUB freeTimer (index AS LONG)
  DIM AS LONG i
  FOR i = index TO UBOUND(timers) - 1
    timers(i) = timers(i + 1)
  NEXT
  REDIM _PRESERVE timers(UBOUND(timers) - 1) AS tELAPSEDTIMER
END SUB

'**********************************************************************************************
'   Physics Collision Calculations
'**********************************************************************************************
SUB _______________COLLISION_FUNCTIONS (): END SUB

SUB collisionCCHandle (m AS tMANIFOLD, contacts() AS tVECTOR2d, A AS tBODY, B AS tBODY)
  DIM normal AS tVECTOR2d
  DIM dist_sqr AS _FLOAT
  DIM radius AS _FLOAT

  vector2dSubVectorND normal, B.fzx.position, A.fzx.position ' Subtract two vectors position A and position
  dist_sqr = vector2dLengthSq(normal) ' Calculate the distance between the balls or circles
  radius = A.shape.radius + B.shape.radius ' Add both circle A and circle B radius

  IF (dist_sqr >= radius * radius) THEN
    m.contactCount = 0
  ELSE
    DIM distance AS _FLOAT
    distance = SQR(dist_sqr)
    m.contactCount = 1

    IF distance = 0 THEN
      m.penetration = A.shape.radius
      vector2dSet m.normal, 1.0, 0.0
      vector2dSetVector contacts(0), A.fzx.position
    ELSE
      m.penetration = radius - distance
      vector2dDivideScalarND m.normal, normal, distance

      vector2dMultiplyScalarND contacts(0), m.normal, A.shape.radius
      vector2dAddVector contacts(0), A.fzx.position
    END IF
  END IF
END SUB

SUB collisionPCHandle (p() AS tPOLY, body() AS tBODY, m AS tMANIFOLD, contacts() AS tVECTOR2d, A AS LONG, B AS LONG)
  collisionCPHandle p(), body(), m, contacts(), B, A
  IF m.contactCount > 0 THEN
    vector2dNeg m.normal
  END IF
END SUB

SUB collisionCPHandle (p() AS tPOLY, body() AS tBODY, m AS tMANIFOLD, contacts() AS tVECTOR2d, A AS LONG, B AS LONG)
  'A is the Circle
  'B is the POLY
  m.contactCount = 0
  DIM center AS tVECTOR2d
  DIM tm AS tMATRIX2d
  DIM tv AS tVECTOR2d
  DIM ARadius AS _FLOAT: ARadius = body(A).shape.radius

  vector2dSubVectorND center, body(A).fzx.position, body(B).fzx.position
  matrix2x2Transpose body(B).shape.u, tm
  matrix2x2MultiplyVector tm, center, center

  DIM separation AS _FLOAT: separation = -9999999
  DIM faceNormal AS LONG: faceNormal = 0
  DIM i AS LONG
  DIM s AS _FLOAT
  FOR i = 0 TO body(B).pa.count
    vector2dSubVectorND tv, center, p(body(B).pa.start + i).vert
    s = vector2dDot(p(body(B).pa.start + i).norm, tv)
    IF s > ARadius THEN EXIT SUB
    IF s > separation THEN
      separation = s
      faceNormal = i
    END IF
  NEXT
  DIM v1 AS tVECTOR2d
  v1 = p(body(B).pa.start + faceNormal).vert
  DIM i2 AS LONG
  i2 = body(B).pa.start + arrayNextIndex(faceNormal, body(B).pa.count)
  DIM v2 AS tVECTOR2d
  v2 = p(i2).vert

  IF separation < cEPSILON THEN
    m.contactCount = 1
    matrix2x2MultiplyVector body(B).shape.u, p(body(B).pa.start + faceNormal).norm, m.normal
    vector2dNeg m.normal
    vector2dMultiplyScalarND contacts(0), m.normal, ARadius
    vector2dAddVector contacts(0), body(A).fzx.position
    m.penetration = ARadius
    EXIT SUB
  END IF

  DIM dot1 AS _FLOAT
  DIM dot2 AS _FLOAT

  DIM tv1 AS tVECTOR2d
  DIM tv2 AS tVECTOR2d
  DIM n AS tVECTOR2d
  vector2dSubVectorND tv1, center, v1
  vector2dSubVectorND tv2, v2, v1
  dot1 = vector2dDot(tv1, tv2)
  vector2dSubVectorND tv1, center, v2
  vector2dSubVectorND tv2, v1, v2
  dot2 = vector2dDot(tv1, tv2)
  m.penetration = ARadius - separation
  IF dot1 <= 0.0 THEN
    IF vector2dSqDist(center, v1) > ARadius * ARadius THEN EXIT SUB
    m.contactCount = 1
    vector2dSubVectorND n, v1, center
    matrix2x2MultiplyVector body(B).shape.u, n, n
    vector2dNormalize n
    m.normal = n
    matrix2x2MultiplyVector body(B).shape.u, v1, v1
    vector2dAddVectorND v1, v1, body(B).fzx.position
    contacts(0) = v1
  ELSE
    IF dot2 <= 0.0 THEN
      IF vector2dSqDist(center, v2) > ARadius * ARadius THEN EXIT SUB
      m.contactCount = 1
      vector2dSubVectorND n, v2, center
      matrix2x2MultiplyVector body(B).shape.u, v2, v2
      vector2dAddVectorND v2, v2, body(B).fzx.position
      contacts(0) = v2
      matrix2x2MultiplyVector body(B).shape.u, n, n
      vector2dNormalize n
      m.normal = n
    ELSE
      n = p(body(B).pa.start + faceNormal).norm
      vector2dSubVectorND tv1, center, v1
      IF vector2dDot(tv1, n) > ARadius THEN EXIT SUB
      m.contactCount = 1
      matrix2x2MultiplyVector body(B).shape.u, n, n
      vector2dNeg n
      m.normal = n
      vector2dMultiplyScalarND contacts(0), m.normal, ARadius
      vector2dAddVector contacts(0), body(A).fzx.position
    END IF
  END IF
END SUB

FUNCTION collisionPPClip (n AS tVECTOR2d, c AS _FLOAT, face() AS tVECTOR2d)
  DIM sp AS LONG: sp = 0
  DIM o(10) AS tVECTOR2d

  o(0) = face(0)
  o(1) = face(1)

  DIM d1 AS _FLOAT: d1 = vector2dDot(n, face(0)) - c
  DIM d2 AS _FLOAT: d2 = vector2dDot(n, face(1)) - c

  IF d1 <= 0.0 THEN
    o(sp) = face(0)
    sp = sp + 1
  END IF

  IF d2 <= 0.0 THEN
    o(sp) = face(1)
    sp = sp + 1
  END IF

  IF d1 * d2 < 0.0 THEN
    DIM alpha AS _FLOAT: alpha = d1 / (d1 - d2)
    DIM tempv AS tVECTOR2d
    'out[sp] = face[0] + alpha * (face[1] - face[0]);
    vector2dSubVectorND tempv, face(1), face(0)
    vector2dMultiplyScalar tempv, alpha
    vector2dAddVectorND o(sp), tempv, face(0)
    sp = sp + 1
  END IF
  face(0) = o(0)
  face(1) = o(1)
  collisionPPClip = sp
END FUNCTION

SUB collisionPPFindIncidentFace (p() AS tPOLY, b() AS tBODY, v() AS tVECTOR2d, RefPoly AS LONG, IncPoly AS LONG, referenceIndex AS LONG)
  DIM referenceNormal AS tVECTOR2d
  DIM uRef AS tMATRIX2d: uRef = b(RefPoly).shape.u
  DIM uInc AS tMATRIX2d: uInc = b(IncPoly).shape.u
  DIM uTemp AS tMATRIX2d
  DIM i AS LONG
  referenceNormal = p(b(RefPoly).pa.start + referenceIndex).norm

  '        // Calculate normal in incident's frame of reference
  '        // referenceNormal = RefPoly->u * referenceNormal; // To world space
  matrix2x2MultiplyVector uRef, referenceNormal, referenceNormal
  '        // referenceNormal = IncPoly->u.Transpose( ) * referenceNormal; // To incident's model space
  matrix2x2Transpose uInc, uTemp
  matrix2x2MultiplyVector uTemp, referenceNormal, referenceNormal

  DIM incidentFace AS LONG: incidentFace = 0
  DIM minDot AS _FLOAT: minDot = 9999999
  DIM dot AS _FLOAT
  FOR i = 0 TO b(IncPoly).pa.count
    dot = vector2dDot(referenceNormal, p(b(IncPoly).pa.start + i).norm)
    IF (dot < minDot) THEN
      minDot = dot
      incidentFace = i
    END IF
  NEXT

  '// Assign face vertices for incidentFace
  '// v[0] = IncPoly->u * IncPoly->m_vertices[incidentFace] + IncPoly->body->position;
  matrix2x2MultiplyVector uInc, p(b(IncPoly).pa.start + incidentFace).vert, v(0)
  vector2dAddVector v(0), b(IncPoly).fzx.position

  '// incidentFace = incidentFace + 1 >= (int32)IncPoly->m_vertexCount ? 0 : incidentFace + 1;
  incidentFace = arrayNextIndex(incidentFace, b(IncPoly).pa.count)

  '// v[1] = IncPoly->u * IncPoly->m_vertices[incidentFace] +  IncPoly->body->position;
  matrix2x2MultiplyVector uInc, p(b(IncPoly).pa.start + incidentFace).vert, v(1)
  vector2dAddVector v(1), b(IncPoly).fzx.position
END SUB

SUB collisionPPHandle (p() AS tPOLY, body() AS tBODY, m AS tMANIFOLD, contacts() AS tVECTOR2d, A AS LONG, B AS LONG)
  m.contactCount = 0

  DIM faceA(100) AS LONG

  DIM penetrationA AS _FLOAT
  penetrationA = collisionPPFindAxisLeastPenetration(p(), body(), faceA(), A, B)
  IF penetrationA >= 0.0 THEN EXIT SUB

  DIM faceB(100) AS LONG

  DIM penetrationB AS _FLOAT
  penetrationB = collisionPPFindAxisLeastPenetration(p(), body(), faceB(), B, A)
  IF penetrationB >= 0.0 THEN EXIT SUB


  DIM referenceIndex AS LONG
  DIM flip AS LONG

  DIM RefPoly AS LONG
  DIM IncPoly AS LONG

  IF impulseGT(penetrationA, penetrationB) THEN
    RefPoly = A
    IncPoly = B
    referenceIndex = faceA(0)
    flip = 0
  ELSE
    RefPoly = B
    IncPoly = A
    referenceIndex = faceB(0)
    flip = 1
  END IF

  DIM incidentFace(2) AS tVECTOR2d

  collisionPPFindIncidentFace p(), body(), incidentFace(), RefPoly, IncPoly, referenceIndex
  DIM v1 AS tVECTOR2d
  DIM v2 AS tVECTOR2d
  DIM v1t AS tVECTOR2d
  DIM v2t AS tVECTOR2d

  v1 = p(body(RefPoly).pa.start + referenceIndex).vert
  referenceIndex = arrayNextIndex(referenceIndex, body(RefPoly).pa.count)
  v2 = p(body(RefPoly).pa.start + referenceIndex).vert
  '// Transform vertices to world space
  '// v1 = RefPoly->u * v1 + RefPoly->body->position;
  '// v2 = RefPoly->u * v2 + RefPoly->body->position;
  matrix2x2MultiplyVector body(RefPoly).shape.u, v1, v1t
  vector2dAddVectorND v1, v1t, body(RefPoly).fzx.position
  matrix2x2MultiplyVector body(RefPoly).shape.u, v2, v2t
  vector2dAddVectorND v2, v2t, body(RefPoly).fzx.position

  '// Calculate reference face side normal in world space
  '// Vec2 sidePlaneNormal = (v2 - v1);
  '// sidePlaneNormal.Normalize( );
  DIM sidePlaneNormal AS tVECTOR2d
  vector2dSubVectorND sidePlaneNormal, v2, v1
  vector2dNormalize sidePlaneNormal

  '// Orthogonalize
  '// Vec2 refFaceNormal( sidePlaneNormal.y, -sidePlaneNormal.x );
  DIM refFaceNormal AS tVECTOR2d
  vector2dSet refFaceNormal, sidePlaneNormal.y, -sidePlaneNormal.x

  '// ax + by = c
  '// c is distance from origin
  '// real refC = Dot( refFaceNormal, v1 );
  '// real negSide = -Dot( sidePlaneNormal, v1 );
  '// real posSide = Dot( sidePlaneNormal, v2 );
  DIM refC AS _FLOAT: refC = vector2dDot(refFaceNormal, v1)
  DIM negSide AS _FLOAT: negSide = -vector2dDot(sidePlaneNormal, v1)
  DIM posSide AS _FLOAT: posSide = vector2dDot(sidePlaneNormal, v2)


  '// Clip incident face to reference face side planes
  '// if(Clip( -sidePlaneNormal, negSide, incidentFace ) < 2)
  DIM negSidePlaneNormal AS tVECTOR2d
  vector2dNegND negSidePlaneNormal, sidePlaneNormal

  IF collisionPPClip(negSidePlaneNormal, negSide, incidentFace()) < 2 THEN EXIT SUB
  IF collisionPPClip(sidePlaneNormal, posSide, incidentFace()) < 2 THEN EXIT SUB

  vector2dSet m.normal, refFaceNormal.x, refFaceNormal.y
  IF flip THEN vector2dNeg m.normal

  '// Keep points behind reference face
  DIM cp AS LONG: cp = 0 '// clipped points behind reference face
  DIM separation AS _FLOAT
  separation = vector2dDot(refFaceNormal, incidentFace(0)) - refC
  IF separation <= 0.0 THEN
    contacts(cp) = incidentFace(0)
    m.penetration = -separation
    cp = cp + 1
  ELSE
    m.penetration = 0
  END IF

  separation = vector2dDot(refFaceNormal, incidentFace(1)) - refC
  IF separation <= 0.0 THEN
    contacts(cp) = incidentFace(1)
    m.penetration = m.penetration + -separation
    cp = cp + 1
    m.penetration = m.penetration / cp
  END IF
  m.contactCount = cp
END SUB

FUNCTION collisionPPFindAxisLeastPenetration (p() AS tPOLY, body() AS tBODY, faceIndex() AS LONG, A AS LONG, B AS LONG)
  DIM bestDistance AS _FLOAT: bestDistance = -9999999
  DIM bestIndex AS LONG: bestIndex = 0

  DIM n AS tVECTOR2d
  DIM nw AS tVECTOR2d
  DIM buT AS tMATRIX2d
  DIM s AS tVECTOR2d
  DIM nn AS tVECTOR2d
  DIM v AS tVECTOR2d
  DIM tv AS tVECTOR2d
  DIM d AS _FLOAT
  DIM i, k AS LONG

  FOR i = 0 TO body(A).pa.count
    k = body(A).pa.start + i

    '// Retrieve a face normal from A
    '// Vec2 n = A->m_normals[i];
    '// Vec2 nw = A->u * n;
    n = p(k).norm
    matrix2x2MultiplyVector body(A).shape.u, n, nw


    '// Transform face normal into B's model space
    '// Mat2 buT = B->u.Transpose( );
    '// n = buT * nw;
    matrix2x2Transpose body(B).shape.u, buT
    matrix2x2MultiplyVector buT, nw, n

    '// Retrieve support point from B along -n
    '// Vec2 s = B->GetSupport( -n );
    vector2dNegND nn, n
    vector2dGetSupport p(), body(), B, nn, s

    '// Retrieve vertex on face from A, transform into
    '// B's model space
    '// Vec2 v = A->m_vertices[i];
    '// v = A->u * v + A->body->position;
    '// v -= B->body->position;
    '// v = buT * v;

    v = p(k).vert
    matrix2x2MultiplyVector body(A).shape.u, v, tv
    vector2dAddVectorND v, tv, body(A).fzx.position

    vector2dSubVector v, body(B).fzx.position
    matrix2x2MultiplyVector buT, v, tv

    vector2dSubVector s, tv
    d = vector2dDot(n, s)

    IF d > bestDistance THEN
      bestDistance = d
      bestIndex = i
    END IF

  NEXT i

  faceIndex(0) = bestIndex

  collisionPPFindAxisLeastPenetration = bestDistance
END FUNCTION

'**********************************************************************************************
'   Physics Impulse Calculations
'**********************************************************************************************
SUB _______________PHYSICS_IMPULSE_MATH (): END SUB
SUB impulseIntegrateForces (world AS tWORLD, b AS tBODY, dt AS _FLOAT)
  IF b.fzx.invMass = 0.0 THEN EXIT SUB
  DIM dts AS _FLOAT
  dts = dt * .5
  vector2dAddVectorScalar b.fzx.velocity, b.fzx.force, b.fzx.invMass * dts
  vector2dAddVectorScalar b.fzx.velocity, world.gravity, dts
  b.fzx.angularVelocity = b.fzx.angularVelocity + (b.fzx.torque * b.fzx.invInertia * dts)
END SUB

SUB impulseIntegrateVelocity (world AS tWORLD, body AS tBODY, dt AS _FLOAT)
  IF body.fzx.invMass = 0.0 THEN EXIT SUB
  ' body.fzx.velocity.x = body.fzx.velocity.x * (1 - dt)
  ' body.fzx.velocity.y = body.fzx.velocity.y * (1 - dt)
  ' body.fzx.angularVelocity = body.fzx.angularVelocity * (1 - dt)
  vector2dAddVectorScalar body.fzx.position, body.fzx.velocity, dt
  body.fzx.orient = body.fzx.orient + (body.fzx.angularVelocity * dt)
  matrix2x2SetRadians body.shape.u, body.fzx.orient
  impulseIntegrateForces world, body, dt
END SUB

SUB impulseStep (engine AS tENGINE, world AS tWORLD, p() AS tPOLY, body() AS tBODY, j() AS tJOINT, hits() AS tHIT, dt AS _FLOAT, iterations AS LONG)
  DIM A AS tBODY
  DIM B AS tBODY
  DIM c(UBOUND(body)) AS tVECTOR2d
  DIM m AS tMANIFOLD
  DIM manifolds(UBOUND(body) * UBOUND(body)) AS tMANIFOLD
  DIM collisions(UBOUND(body) * UBOUND(body), UBOUND(body)) AS tVECTOR2d
  DIM AS tVECTOR2d tv, tv1
  DIM AS _FLOAT d
  DIM AS LONG mval
  DIM manifoldCount AS LONG: manifoldCount = 0
  '    // Generate new collision info
  DIM i, j, k, index AS LONG
  DIM hitCount AS LONG: hitCount = 0

  REDIM hits(0) AS tHIT
  hits(0).A = -1
  hits(0).B = -1
  hitCount = 0

  FOR i = 0 TO UBOUND(body) ' number of bodies
    A = body(i)
    IF A.enable THEN
      FOR j = i + 1 TO UBOUND(body)
        B = body(j)
        IF B.enable THEN
          IF (A.collisionMask AND B.collisionMask) THEN
            IF A.fzx.invMass = 0.0 AND B.fzx.invMass = 0.0 THEN _CONTINUE
            'Mainfold solve - handle collisions
            IF AABBOverlapObjects(body(), i, j) THEN
              IF A.shape.ty = cSHAPE_CIRCLE AND B.shape.ty = cSHAPE_CIRCLE THEN
                collisionCCHandle m, c(), A, B
              ELSE
                IF A.shape.ty = cSHAPE_POLYGON AND B.shape.ty = cSHAPE_POLYGON THEN
                  collisionPPHandle p(), body(), m, c(), i, j
                ELSE
                  IF A.shape.ty = cSHAPE_CIRCLE AND B.shape.ty = cSHAPE_POLYGON THEN
                    collisionCPHandle p(), body(), m, c(), i, j
                  ELSE
                    IF B.shape.ty = cSHAPE_CIRCLE AND A.shape.ty = cSHAPE_POLYGON THEN
                      collisionPCHandle p(), body(), m, c(), i, j
                    END IF
                  END IF
                END IF
              END IF

              IF m.contactCount > 0 THEN
                m.A = i 'identify the index of objects
                m.B = j
                manifolds(manifoldCount) = m
                FOR k = 0 TO m.contactCount
                  hits(hitCount).A = i
                  hits(hitCount).B = j
                  hits(hitCount).position = c(k)
                  collisions(manifoldCount, k) = c(k)
                  hitCount = hitCount + 1
                  IF hitCount > UBOUND(hits) THEN REDIM _PRESERVE hits(hitCount * 1.5) AS tHIT
                NEXT
                manifoldCount = manifoldCount + 1
                IF manifoldCount > UBOUND(manifolds) THEN REDIM _PRESERVE manifolds(manifoldCount * 1.5) AS tMANIFOLD
              END IF
            END IF
          END IF
        END IF
      NEXT
    END IF
  NEXT

  '    Integrate forces
  FOR i = 0 TO UBOUND(body)
    IF body(i).enable AND body(i).noPhysics = 0 THEN impulseIntegrateForces world, body(i), dt
  NEXT
  '    Initialize collision
  FOR i = 0 TO manifoldCount - 1
    FOR k = 0 TO manifolds(i).contactCount - 1
      c(k) = collisions(i, k)
    NEXT
    manifoldInit engine, manifolds(i), body(), c()
  NEXT

  ' joint pre Steps
  FOR i = 1 TO UBOUND(j)
    jointPrestep j(i), body(), dt
  NEXT

  ' Solve collisions
  FOR j = 0 TO iterations - 1
    FOR i = 0 TO manifoldCount - 1
      FOR k = 0 TO manifolds(i).contactCount - 1
        c(k) = collisions(i, k)
      NEXT
      manifoldApplyImpulse manifolds(i), body(), c()
      'store the hit speed for later
      FOR k = 0 TO hitCount - 1
        IF manifolds(i).A = hits(k).A AND manifolds(i).B = hits(k).B THEN
          hits(k).cv = manifolds(i).cv
        END IF
      NEXT
    NEXT
    FOR i = 1 TO UBOUND(j)
      jointApplyImpulse j(i), body()
    NEXT

    ' It appears that the joint bias is analgous to the stress the
    ' joint has on it.
    ' Lets give those wireframe joints some color.
    ' If that stress is greater than the max then break the joint

    index = 0
    DO
      IF j(index).max_bias > 0 THEN
        vector2dSetVector tv, j(index).bias
        vector2dSet tv1, 0, 0
        d = vector2dDistance(tv, tv1)
        mval = scalarMap(d, 0, 100000, 0, 255)
        j(index).wireframe_color = _RGB32(mval, 255 - mval, 0)
        IF d > j(index).max_bias THEN jointDelete j(), index
      END IF
      index = index + 1
    LOOP UNTIL index > UBOUND(j)

  NEXT

  '// Integrate velocities
  FOR i = 0 TO UBOUND(body)
    IF body(i).enable AND body(i).noPhysics = 0 THEN impulseIntegrateVelocity world, body(i), dt
  NEXT
  '// Correct positions
  FOR i = 0 TO manifoldCount - 1
    manifoldPositionalCorrection manifolds(i), body()
  NEXT
  '// Clear all forces
  FOR i = 0 TO UBOUND(body)
    vector2dSet body(i).fzx.force, 0, 0
    body(i).fzx.torque = 0
  NEXT
END SUB

SUB bodyApplyImpulse (body AS tBODY, impulse AS tVECTOR2d, contactVector AS tVECTOR2d)
  vector2dAddVectorScalar body.fzx.velocity, impulse, body.fzx.invMass
  body.fzx.angularVelocity = body.fzx.angularVelocity + body.fzx.invInertia * vector2dCross(contactVector, impulse)
END SUB

SUB _______________MANIFOLD_MATH_FUNCTIONS (): END SUB

SUB manifoldInit (engine AS tENGINE, m AS tMANIFOLD, body() AS tBODY, contacts() AS tVECTOR2d)
  DIM ra AS tVECTOR2d
  DIM rb AS tVECTOR2d
  DIM rv AS tVECTOR2d
  DIM tv1 AS tVECTOR2d 'temporary Vectors
  DIM tv2 AS tVECTOR2d
  m.e = scalarMin(body(m.A).fzx.restitution, body(m.B).fzx.restitution)
  m.sf = SQR(body(m.A).fzx.staticFriction * body(m.A).fzx.staticFriction)
  m.df = SQR(body(m.A).fzx.dynamicFriction * body(m.A).fzx.dynamicFriction)
  DIM i AS LONG
  FOR i = 0 TO m.contactCount - 1
    vector2dSubVectorND contacts(i), body(m.A).fzx.position, ra
    vector2dSubVectorND contacts(i), body(m.B).fzx.position, rb

    vector2dCrossScalar tv1, rb, body(m.B).fzx.angularVelocity
    vector2dCrossScalar tv2, ra, body(m.A).fzx.angularVelocity
    vector2dAddVector tv1, body(m.B).fzx.velocity
    vector2dSubVectorND tv2, body(m.A).fzx.velocity, tv2
    vector2dSubVectorND rv, tv1, tv2

    IF vector2dLengthSq(rv) < engine.resting THEN
      m.e = 0.0
    END IF
  NEXT
END SUB

SUB manifoldApplyImpulse (m AS tMANIFOLD, body() AS tBODY, contacts() AS tVECTOR2d)
  DIM ra AS tVECTOR2d
  DIM rb AS tVECTOR2d
  DIM rv AS tVECTOR2d
  DIM tv1 AS tVECTOR2d 'temporary Vectors
  DIM tv2 AS tVECTOR2d
  DIM contactVel AS _FLOAT

  DIM raCrossN AS _FLOAT
  DIM rbCrossN AS _FLOAT
  DIM invMassSum AS _FLOAT
  DIM i AS LONG
  DIM j AS _FLOAT
  DIM impulse AS tVECTOR2d

  DIM t AS tVECTOR2d
  DIM jt AS _FLOAT
  DIM tangentImpulse AS tVECTOR2d

  IF impulseEqual(body(m.A).fzx.invMass + body(m.B).fzx.invMass, 0.0) THEN
    manifoldInfiniteMassCorrection body(m.A), body(m.B)
    EXIT SUB
  END IF
  IF (body(m.A).noPhysics OR body(m.B).noPhysics) THEN
    EXIT SUB
  END IF

  FOR i = 0 TO m.contactCount - 1
    '// Calculate radii from COM to contact
    '// Vec2 ra = contacts[i] - A->position;
    '// Vec2 rb = contacts[i] - B->position;
    vector2dSubVectorND ra, contacts(i), body(m.A).fzx.position
    vector2dSubVectorND rb, contacts(i), body(m.B).fzx.position

    '// Relative velocity
    '// Vec2 rv = B->velocity + Cross( B->angularVelocity, rb ) - A->velocity - Cross( A->angularVelocity, ra );
    vector2dCrossScalar tv1, rb, body(m.B).fzx.angularVelocity
    vector2dCrossScalar tv2, ra, body(m.A).fzx.angularVelocity
    vector2dAddVectorND rv, tv1, body(m.B).fzx.velocity
    vector2dSubVector rv, body(m.A).fzx.velocity
    vector2dSubVector rv, tv2

    '// Relative velocity along the normal
    '// real contactVel = Dot( rv, normal );
    contactVel = vector2dDot(rv, m.normal)

    '// Do not resolve if velocities are separating
    IF contactVel > 0 THEN EXIT SUB
    m.cv = contactVel
    '// real raCrossN = Cross( ra, normal );
    '// real rbCrossN = Cross( rb, normal );
    '// real invMassSum = A->im + B->im + Sqr( raCrossN ) * A->iI + Sqr( rbCrossN ) * B->iI;
    raCrossN = vector2dCross(ra, m.normal)
    rbCrossN = vector2dCross(rb, m.normal)
    invMassSum = body(m.A).fzx.invMass + body(m.B).fzx.invMass + (raCrossN * raCrossN) * body(m.A).fzx.invInertia + (rbCrossN * rbCrossN) * body(m.B).fzx.invInertia

    '// Calculate impulse scalar
    j = -(1.0 + m.e) * contactVel
    j = j / invMassSum
    j = j / m.contactCount

    '// Apply impulse
    vector2dMultiplyScalarND impulse, m.normal, j
    vector2dNegND tv1, impulse
    bodyApplyImpulse body(m.A), tv1, ra
    bodyApplyImpulse body(m.B), impulse, rb

    '// Friction impulse
    '// rv = B->velocity + Cross( B->angularVelocity, rb ) - A->velocity - Cross( A->angularVelocity, ra );
    vector2dCrossScalar tv1, rb, body(m.B).fzx.angularVelocity
    vector2dCrossScalar tv2, ra, body(m.A).fzx.angularVelocity
    vector2dAddVectorND rv, tv1, body(m.B).fzx.velocity
    vector2dSubVector rv, body(m.A).fzx.velocity
    vector2dSubVector rv, tv2

    '// Vec2 t = rv - (normal * Dot( rv, normal ));
    '// t.Normalize( );
    vector2dMultiplyScalarND t, m.normal, vector2dDot(rv, m.normal)
    vector2dSubVectorND t, rv, t
    vector2dNormalize t

    '// j tangent magnitude
    jt = -vector2dDot(rv, t)
    jt = jt / invMassSum
    jt = jt / m.contactCount

    '// Don't apply tiny friction impulses
    IF impulseEqual(jt, 0.0) THEN EXIT SUB

    '// Coulumb's law
    IF ABS(jt) < j * m.sf THEN
      vector2dMultiplyScalarND tangentImpulse, t, jt
    ELSE
      vector2dMultiplyScalarND tangentImpulse, t, -j * m.df
    END IF

    '// Apply friction impulse
    '// A->ApplyImpulse( -tangentImpulse, ra );
    '// B->ApplyImpulse( tangentImpulse, rb );
    vector2dNegND tv1, tangentImpulse
    bodyApplyImpulse body(m.A), tv1, ra
    bodyApplyImpulse body(m.B), tangentImpulse, rb
  NEXT i
END SUB

SUB manifoldPositionalCorrection (m AS tMANIFOLD, body() AS tBODY)
  IF body(m.A).noPhysics OR body(m.B).noPhysics THEN EXIT SUB
  DIM correction AS _FLOAT
  correction = scalarMax(m.penetration - cPENETRATION_ALLOWANCE, 0.0) / (body(m.A).fzx.invMass + body(m.B).fzx.invMass) * cPENETRATION_CORRECTION
  vector2dAddVectorScalar body(m.A).fzx.position, m.normal, -body(m.A).fzx.invMass * correction
  vector2dAddVectorScalar body(m.B).fzx.position, m.normal, body(m.B).fzx.invMass * correction
END SUB

SUB manifoldInfiniteMassCorrection (A AS tBODY, B AS tBODY)
  vector2dSet A.fzx.velocity, 0, 0
  vector2dSet B.fzx.velocity, 0, 0
END SUB

'**********************************************************************************************
'   Joint Creation
'**********************************************************************************************
SUB _______________JOINT_CREATION_FUNCTIONS (): END SUB
FUNCTION jointCreate (j() AS tJOINT, body() AS tBODY, b1 AS LONG, b2 AS LONG, x AS _FLOAT, y AS _FLOAT)
  REDIM _PRESERVE j(UBOUND(j) + 1) AS tJOINT
  jointSet j(UBOUND(j)), body(), b1, b2, x, y
  'Joint name will default to a combination of the two objects that is connects.
  'If you change it you must also recompute the hash.
  j(UBOUND(j)).jointName = body(b1).objectName + "_" + body(b2).objectName
  j(UBOUND(j)).jointHash = computeHash&&(j(UBOUND(j)).jointName)
  j(UBOUND(j)).wireframe_color = _RGB32(255, 227, 127)
  jointCreate = UBOUND(j)
END FUNCTION

SUB jointDelete (j() AS tJOINT, d AS LONG)
  DIM AS LONG index
  IF d >= 0 AND d <= UBOUND(j) AND UBOUND(j) > 0 THEN
    FOR index = d TO UBOUND(j) - 1
      j(index) = j(index + 1)
    NEXT
    REDIM _PRESERVE j(UBOUND(j) - 1) AS tJOINT
  END IF
END SUB

SUB jointSet (j AS tJOINT, body() AS tBODY, b1 AS LONG, b2 AS LONG, x AS _FLOAT, y AS _FLOAT)
  DIM anchor AS tVECTOR2d
  vector2dSet anchor, x, y
  DIM Rot1 AS tMATRIX2d: Rot1 = body(b1).shape.u
  DIM Rot2 AS tMATRIX2d: Rot2 = body(b2).shape.u
  DIM Rot1T AS tMATRIX2d: matrix2x2Transpose Rot1, Rot1T
  DIM Rot2T AS tMATRIX2d: matrix2x2Transpose Rot2, Rot2T
  DIM tv AS tVECTOR2d

  j.body1 = b1
  j.body2 = b2

  vector2dSubVectorND tv, anchor, body(b1).fzx.position
  matrix2x2MultiplyVector Rot1T, tv, j.localAnchor1

  vector2dSubVectorND tv, anchor, body(b2).fzx.position
  matrix2x2MultiplyVector Rot2T, tv, j.localAnchor2

  vector2dSet j.P, 0, 0
  ' Some default Settings
  j.softness = 0.001
  j.biasFactor = 100
  j.max_bias = 100000
END SUB

'**********************************************************************************************
'   Joint Calculations
'**********************************************************************************************

SUB _______________JOINT_MATH_FUNCTIONS (): END SUB

SUB jointPrestep (j AS tJOINT, body() AS tBODY, inv_dt AS _FLOAT)
  DIM Rot1 AS tMATRIX2d: Rot1 = body(j.body1).shape.u
  DIM Rot2 AS tMATRIX2d: Rot2 = body(j.body2).shape.u
  DIM b1invMass AS _FLOAT
  DIM b2invMass AS _FLOAT

  DIM b1invInertia AS _FLOAT
  DIM b2invInertia AS _FLOAT

  matrix2x2MultiplyVector Rot1, j.localAnchor1, j.r1
  matrix2x2MultiplyVector Rot2, j.localAnchor2, j.r2

  b1invMass = body(j.body1).fzx.invMass
  b2invMass = body(j.body2).fzx.invMass

  b1invInertia = body(j.body1).fzx.invInertia
  b2invInertia = body(j.body2).fzx.invInertia

  DIM K1 AS tMATRIX2d
  matrix2x2SetScalar K1, b1invMass + b2invMass, 0, 0, b1invMass + b2invMass
  DIM K2 AS tMATRIX2d
     matrix2x2SetScalar K2, b1invInertia * j.r1.y * j.r1.y, -b1invInertia * j.r1.x * j.r1.y,_
                            -b1invInertia * j.r1.x * j.r1.y,  b1invInertia * j.r1.x * j.r1.x

  DIM K3 AS tMATRIX2d
     matrix2x2SetScalar K3,  b2invInertia * j.r2.y * j.r2.y, - b2invInertia * j.r2.x * j.r2.y,_
                             -b2invInertia * j.r2.x * j.r2.y,   b2invInertia * j.r2.x * j.r2.x

  DIM K AS tMATRIX2d
  matrix2x2AddMatrix K1, K2, K
  matrix2x2AddMatrix K3, K, K
  K.m00 = K.m00 + j.softness
  K.m11 = K.m11 + j.softness
  matrix2x2Invert K, j.M

  DIM p1 AS tVECTOR2d: vector2dAddVectorND p1, body(j.body1).fzx.position, j.r1
  DIM p2 AS tVECTOR2d: vector2dAddVectorND p2, body(j.body2).fzx.position, j.r2
  DIM dp AS tVECTOR2d: vector2dSubVectorND dp, p2, p1

  vector2dMultiplyScalarND j.bias, dp, -j.biasFactor * inv_dt
  ' vectorSet j.bias, 0, 0
  vector2dSet j.P, 0, 0
END SUB

SUB jointApplyImpulse (j AS tJOINT, body() AS tBODY)
  DIM dv AS tVECTOR2d
  DIM impulse AS tVECTOR2d
  DIM cross1 AS tVECTOR2d
  DIM cross2 AS tVECTOR2d
  DIM tv AS tVECTOR2d

  'Vec2 dv = body2->velocity + Cross(body2->angularVelocity, r2) - body1->velocity - Cross(body1->angularVelocity, r1);
  vector2dCrossScalar cross2, j.r2, body(j.body2).fzx.angularVelocity
  vector2dCrossScalar cross1, j.r1, body(j.body1).fzx.angularVelocity
  vector2dAddVectorND dv, body(j.body2).fzx.velocity, cross2
  vector2dSubVectorND dv, dv, body(j.body1).fzx.velocity
  vector2dSubVectorND dv, dv, cross1

  ' impulse = M * (bias - dv - softness * P);
  vector2dMultiplyScalarND tv, j.P, j.softness
  vector2dSubVectorND impulse, j.bias, dv
  vector2dSubVectorND impulse, impulse, tv
  matrix2x2MultiplyVector j.M, impulse, impulse

  ' body1->velocity -= body1->invMass * impulse;

  vector2dMultiplyScalarND tv, impulse, body(j.body1).fzx.invMass
  vector2dSubVectorND body(j.body1).fzx.velocity, body(j.body1).fzx.velocity, tv

  ' body1->angularVelocity -= body1->invI * Cross(r1, impulse);
  DIM crossScalar AS _FLOAT
  crossScalar = vector2dCross(j.r1, impulse)
  body(j.body1).fzx.angularVelocity = body(j.body1).fzx.angularVelocity - body(j.body1).fzx.invInertia * crossScalar

  vector2dMultiplyScalarND tv, impulse, body(j.body2).fzx.invMass
  vector2dAddVectorND body(j.body2).fzx.velocity, body(j.body2).fzx.velocity, tv

  crossScalar = vector2dCross(j.r2, impulse)
  body(j.body2).fzx.angularVelocity = body(j.body2).fzx.angularVelocity + body(j.body2).fzx.invInertia * crossScalar

  vector2dAddVectorND j.P, j.P, impulse
END SUB
'**********************************************************************************************
'   Collision Tools
'**********************************************************************************************
SUB _______________COLLISION_QUERY_TOOLS (): END SUB
FUNCTION isOnSensor (engine AS tENGINE, p AS tVECTOR2d)
  _SOURCE engine.hiddenScr
  isOnSensor = _BLUE(POINT(p.x, p.y))
  _SOURCE engine.displayScr
END FUNCTION

FUNCTION isBodyTouchingBody (hits() AS tHIT, A AS LONG, B AS LONG)
  DIM hitcount AS LONG: hitcount = 0
  isBodyTouchingBody = -1
  FOR hitcount = 0 TO UBOUND(hits)
    IF hits(hitcount).A = A AND hits(hitcount).B = B THEN
      isBodyTouchingBody = hitcount
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION

FUNCTION isBodyTouchingStatic (body() AS tBODY, hits() AS tHIT, A AS LONG)
  DIM hitcount AS LONG: hitcount = 0
  isBodyTouchingStatic = 0
  FOR hitcount = 0 TO UBOUND(hits)
    IF hits(hitcount).A = A THEN
      IF body(hits(hitcount).B).fzx.mass = 0 THEN
        isBodyTouchingStatic = hitcount
        EXIT FUNCTION
      END IF
    ELSE
      IF hits(hitcount).B = A THEN
        IF body(hits(hitcount).A).fzx.mass = 0 THEN
          isBodyTouchingStatic = hitcount
          EXIT FUNCTION
        END IF
      END IF
    END IF
  NEXT
END FUNCTION

FUNCTION isBodyTouching (hits() AS tHIT, A AS LONG)
  DIM hitcount AS LONG: hitcount = 0
  isBodyTouching = -1
  FOR hitcount = 0 TO UBOUND(hits)
    IF hits(hitcount).A = A THEN
      isBodyTouching = hits(hitcount).B
      EXIT FUNCTION
    END IF
    IF hits(hitcount).B = A THEN
      isBodyTouching = hits(hitcount).A
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION

FUNCTION highestCollisionVelocity (hits() AS tHIT, A AS LONG) ' this function is a bit dubious and may not do as you think
  DIM hitcount AS LONG: hitcount = 0
  DIM hiCv AS _FLOAT: hiCv = 0
  highestCollisionVelocity = 0
  FOR hitcount = 0 TO UBOUND(hits)
    IF hits(hitcount).A = A AND ABS(hits(hitcount).cv) > hiCv AND hits(hitcount).cv < 0 THEN
      hiCv = ABS(hits(hitcount).cv)
    END IF
  NEXT
  highestCollisionVelocity = hiCv
END FUNCTION

'**********************************************************************************************
'   Body Managment Tools
'**********************************************************************************************
SUB _______________BODY_MANAGEMENT (): END SUB

FUNCTION bodyManagerAdd (body() AS tBODY)
  bodyManagerAdd = UBOUND(body)
  REDIM _PRESERVE body(UBOUND(body) + 1) AS tBODY
END FUNCTION

FUNCTION bodyWithHash (body() AS tBODY, hash AS _INTEGER64)
  DIM AS LONG i
  bodyWithHash = -1
  FOR i = 0 TO UBOUND(body) - 1
    IF body(i).objectHash = hash THEN
      bodyWithHash = i
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION

FUNCTION bodyWithHashMask (body() AS tBODY, hash AS _INTEGER64, mask AS LONG)
  DIM AS LONG i
  bodyWithHashMask = -1
  FOR i = 0 TO UBOUND(body) - 1
    IF (body(i).objectHash AND mask) = (hash AND mask) THEN
      bodyWithHashMask = i
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION

FUNCTION bodyManagerID (body() AS tBODY, objName AS STRING)
  DIM i AS LONG
  DIM uID AS _INTEGER64
  uID = computeHash(RTRIM$(LTRIM$(objName)))
  bodyManagerID = -1

  FOR i = 0 TO UBOUND(body)
    IF body(i).objectHash = uID THEN
      bodyManagerID = i
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION

FUNCTION bodyContainsString (body() AS tBODY, start AS LONG, s AS STRING)
  bodyContainsString = -1
  DIM AS LONG j
  FOR j = start TO UBOUND(body)
    IF INSTR(body(j).objectName, s) THEN
      bodyContainsString = j
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION

'**********************************************************************************************
'   String Hash
'**********************************************************************************************
SUB _______________GENERAL_STRING_HASH (): END SUB
FUNCTION computeHash&& (s AS STRING)
  DIM p, i AS LONG: p = 31
  DIM m AS _INTEGER64: m = 1E9 + 9
  DIM AS _INTEGER64 hash_value, p_pow
  p_pow = 1
  FOR i = 1 TO LEN(s)
    hash_value = (hash_value + (ASC(MID$(s, i)) - 97 + 1) * p_pow)
    p_pow = (p_pow * p) MOD m
  NEXT
  computeHash = hash_value
END FUNCTION
'**********************************************************************************************
'   Network Related Tools
'**********************************************************************************************

SUB _______________NETWORK_FUNCTIONALITY (): END SUB
SUB handleNetwork (body() AS tBODY, net AS tNETWORK)
  IF net.SorC = cNET_SERVER THEN
    IF net.HCHandle = 0 THEN
      networkStartHost net
    END IF
    networkTransmit body(), net
  END IF

  IF net.SorC = cNET_CLIENT THEN
    networkReceiveFromHost body(), net
  END IF
END SUB

SUB networkStartHost (net AS tNETWORK)
  DIM connection AS STRING
  connection = RTRIM$(net.protocol) + ":" + LTRIM$(STR$(net.port))
  net.HCHandle = _OPENHOST(connection)
END SUB

SUB networkReceiveFromHost (body() AS tBODY, net AS tNETWORK)
  DIM connection AS STRING
  DIM AS LONG timeout
  connection = RTRIM$(net.protocol) + ":" + LTRIM$(STR$(net.port)) + ":" + RTRIM$(net.address)
  net.HCHandle = _OPENCLIENT(connection)
  timeout = TIMER
  IF net.HCHandle THEN
    DO
      GET #net.HCHandle, , body()
      IF TIMER - timeout > 5 THEN EXIT DO ' 5 sec time out
    LOOP UNTIL EOF(net.HCHandle) = 0
    networkClose net
  END IF
END SUB

SUB networkTransmit (body() AS tBODY, net AS tNETWORK)
  IF net.HCHandle <> 0 THEN
    net.connectionHandle = _OPENCONNECTION(net.HCHandle)
    IF net.connectionHandle <> 0 THEN
      PUT #net.connectionHandle, , body()
      CLOSE net.connectionHandle
    END IF
  END IF
END SUB

SUB networkClose (net AS tNETWORK)
  IF net.HCHandle <> 0 THEN
    CLOSE net.HCHandle
    net.HCHandle = 0
  END IF
END SUB

'**********************************************************************************************
'   Handle Input Devices
'**********************************************************************************************
SUB _______________INPUT_HANDLING (): END SUB

SUB initInputDevice (p() AS tPOLY, body() AS tBODY, iDevice AS tINPUTDEVICE, icon AS LONG)
  iDevice.mouseIcon = icon
  iDevice.mouseBody = createCircleBodyEx(body(), "_mouse", 1)
  setBody p(), body(), cPARAMETER_POSITION, iDevice.mouseBody, 0, 0
  setBody p(), body(), cPARAMETER_ORIENT, iDevice.mouseBody, 0, 0
  setBody p(), body(), cPARAMETER_STATIC, iDevice.mouseBody, 0, 0
  setBody p(), body(), cPARAMETER_NOPHYSICS, iDevice.mouseBody, 1, 0
  iDevice.mouseMode = 1
END SUB

SUB handleInputDevice (p() AS tPOLY, body() AS tBODY, iDevice AS tINPUTDEVICE, camera AS tCAMERA)
  STATIC AS tVECTOR2d mouse
  cleanUpInputDevice iDevice
  iDevice.keyHit = _KEYHIT

  DO WHILE _MOUSEINPUT
    iDevice.xy.x = _MOUSEX
    iDevice.xy.y = _MOUSEY
    iDevice.b1 = _MOUSEBUTTON(1)
    iDevice.b2 = _MOUSEBUTTON(2)
    iDevice.b3 = _MOUSEBUTTON(3)
    iDevice.w = _MOUSEWHEEL
    iDevice.wCount = iDevice.wCount + iDevice.w
    iDevice.mouseOnScreen = iDevice.xy.x > 0 AND iDevice.xy.x < _WIDTH AND iDevice.xy.y > 0 AND iDevice.xy.y < _HEIGHT
  LOOP
  iDevice.b1PosEdge = bool(iDevice.lb1 > iDevice.b1) ' 0 --> -1
  iDevice.b1NegEdge = bool(iDevice.lb1 < iDevice.b1) ' -1 --> 0
  iDevice.b2PosEdge = bool(iDevice.lb2 > iDevice.b2) ' 0 --> -1
  iDevice.b2NegEdge = bool(iDevice.lb2 < iDevice.b2) ' -1 --> 0
  iDevice.b3PosEdge = bool(iDevice.lb3 > iDevice.b2) ' 0 --> -1
  iDevice.b3NegEdge = bool(iDevice.lb3 < iDevice.b3) ' -1 --> 0
  IF iDevice.mouseMode AND iDevice.mouseOnScreen THEN
    'Mouse screen position to world
    vector2dSet mouse, iDevice.xy.x, iDevice.xy.y
    cameraToWorld camera, mouse, iDevice.mouse
    setBody p(), body(), cPARAMETER_POSITION, iDevice.mouseBody, iDevice.mouse.x, iDevice.mouse.y
    alphaImage 255, iDevice.mouseIcon, iDevice.xy, camera.zoom
  END IF
END SUB

SUB cleanUpInputDevice (iDevice AS tINPUTDEVICE)
  iDevice.lb1 = iDevice.b1
  iDevice.lb2 = iDevice.b2
  iDevice.lb3 = iDevice.b3
  iDevice.lastKeyHit = iDevice.keyHit
  iDevice.wCount = 0
END SUB

'**********************************************************************************************
'   Entity Behavior
'**********************************************************************************************
SUB _______________ENTITY_HANDLING (): END SUB

SUB moveEntity (entity AS tENTITY, body() AS tBODY, endPos AS tVECTOR2d, gamemap() AS tTILE, tilemap AS tTILEMAP)
  DIM AS tVECTOR2d startPos, endPosDiv
  'Convert start and end to gamemap X and Y
  vector2dSet startPos, INT(body(entity.objectID).fzx.position.x / tilemap.tileWidth), INT(body(entity.objectID).fzx.position.y / tilemap.tileHeight)
  vector2dSet endPosDiv, INT(endPos.x / tilemap.tileWidth), INT(endPos.y / tilemap.tileHeight)
  entity.fsmSecondary.timerState.start = TIMER(.001)
  entity.fsmSecondary.timerState.duration = entity.fsmSecondary.timerState.start + entity.parameters.movementSpeed
  entity.fsmSecondary.arg3 = 1 'ARG3 in this case is used to keep track of the step in the A-star path
  entity.pathString = AStarSetPath$(entity, startPos, endPosDiv, gamemap(), tilemap)
  IF LEN(trim$(entity.pathString)) > 0 THEN ' make sure path was created
    FSMChangeState entity.fsmPrimary, cFSM_ENTITY_MOVE
    FSMChangeState entity.fsmSecondary, cFSM_ENTITY_MOVEINIT 'Calculate next tile
  END IF
END SUB

SUB handleEntitys (entity() AS tENTITY, body() AS tBODY, tilemap AS tTILEMAP)
  DIM AS LONG index, iD
  DIM AS _FLOAT progress
  DIM AS STRING dir
  FOR index = 0 TO UBOUND(entity)
    iD = entity(index).objectID
    ' If entity is moving then
    '  - Primary FSM is for moving the whole trip
    '  - Secondary FSM is traversing tile to tile
    'Primary State Machine
    SELECT CASE entity(index).fsmPrimary.currentState
      CASE cFSM_ENTITY_IDLE:
      CASE cFSM_ENTITY_MOVEINIT:
      CASE cFSM_ENTITY_MOVE: 'Move whole trip
        'Secondary State Machine
        SELECT CASE entity(index).fsmSecondary.currentState
          CASE cFSM_ENTITY_IDLE:
          CASE cFSM_ENTITY_MOVEINIT: 'Determine next tile
            'pathstring is always have a length of what was initialized regardless of actual length, so we have to trim it
            IF entity(index).fsmSecondary.arg3 <= LEN(trim$(entity(index).pathString)) THEN
              'extract next direction from pathstring
              dir = MID$(entity(index).pathString, entity(index).fsmSecondary.arg3, 1)
              'ARG 1 will be the start position
              entity(index).fsmSecondary.arg1 = body(iD).fzx.position
              'ARG 2 will be the finish position
              SELECT CASE dir
                CASE "U":
                  vector2dSet entity(index).fsmSecondary.arg2, body(iD).fzx.position.x, body(iD).fzx.position.y - tilemap.tileHeight
                CASE "D":
                  vector2dSet entity(index).fsmSecondary.arg2, body(iD).fzx.position.x, body(iD).fzx.position.y + tilemap.tileHeight
                CASE "L":
                  vector2dSet entity(index).fsmSecondary.arg2, body(iD).fzx.position.x - tilemap.tileWidth, body(iD).fzx.position.y
                CASE "R":
                  vector2dSet entity(index).fsmSecondary.arg2, body(iD).fzx.position.x + tilemap.tileWidth, body(iD).fzx.position.y
              END SELECT
              'Center Entity on destination tile
              entity(index).fsmSecondary.arg2.x = INT(entity(index).fsmSecondary.arg2.x / tilemap.tileWidth) * tilemap.tileWidth + (tilemap.tileWidth / 2)
              entity(index).fsmSecondary.arg2.y = INT(entity(index).fsmSecondary.arg2.y / tilemap.tileHeight) * tilemap.tileHeight + (tilemap.tileHeight / 2)
              'Setup movement timers
              entity(index).fsmSecondary.timerState.start = TIMER(.001)
              entity(index).fsmSecondary.timerState.duration = entity(index).fsmSecondary.timerState.start + entity(index).parameters.movementSpeed
              FSMChangeState entity(index).fsmSecondary, cFSM_ENTITY_MOVE
            ELSE
              'finish the trip
              FSMChangeState entity(index).fsmPrimary, cFSM_ENTITY_IDLE
              FSMChangeState entity(index).fsmSecondary, cFSM_ENTITY_IDLE
            END IF
          CASE cFSM_ENTITY_MOVE: 'Move between individual tiles
            progress = scalarLERPProgress(entity(index).fsmSecondary.timerState.start, entity(index).fsmSecondary.timerState.duration)
            vector2dLERP body(iD).fzx.position, entity(index).fsmSecondary.arg1, entity(index).fsmSecondary.arg2, progress
            IF scalarRoughEqual(progress, 1.0, .1) THEN 'When done move to the next step
              'increment to next step
              entity(index).fsmSecondary.arg3 = entity(index).fsmSecondary.arg3 + 1
              FSMChangeState entity(index).fsmSecondary, cFSM_ENTITY_MOVEINIT
            END IF
        END SELECT
    END SELECT
  NEXT
END SUB

'**********************************************************************************************
'   Camera Behavior
'**********************************************************************************************
SUB _______________CAMERA_HANDLING (): END SUB

SUB moveCamera (camera AS tCAMERA, targetPosition AS tVECTOR2d)
  camera.fsm.timerState.duration = 1
  camera.fsm.arg1 = camera.position
  camera.fsm.arg2 = targetPosition
  camera.fsm.arg3 = 0
  FSMChangeState camera.fsm, cFSM_CAMERA_MOVING
END SUB

SUB handleCamera (camera AS tCAMERA)
  DIM AS _FLOAT progress
  SELECT CASE camera.fsm.currentState
    CASE cFSM_CAMERA_IDLE:
    CASE cFSM_CAMERA_MOVING:
      progress = scalarLERPProgress(camera.fsm.timerState.start, camera.fsm.timerState.start + camera.fsm.timerState.duration)
      vector2dLERPSmoother camera.position, camera.fsm.arg1, camera.fsm.arg2, progress
      IF progress > .95 THEN
        FSMChangeState camera.fsm, cFSM_CAMERA_IDLE
      END IF
  END SELECT
END SUB

'**********************************************************************************************
'   FSM Handling
'**********************************************************************************************
SUB _______________FSM_HANDLING (): END SUB

SUB FSMChangeState (fsm AS tFSM, newState AS LONG)
  fsm.previousState = fsm.currentState
  fsm.currentState = newState
  fsm.timerState.start = TIMER(.001)
END SUB

SUB FSMChangeStateEx (fsm AS tFSM, newState AS LONG, arg1 AS tVECTOR2d, arg2 AS tVECTOR2d, arg3 AS LONG)
  fsm.previousState = fsm.currentState
  fsm.currentState = newState
  fsm.arg1 = arg1
  fsm.arg2 = arg2
  fsm.arg3 = arg3
END SUB

SUB FSMChangeStateOnTimer (fsm AS tFSM, newstate AS LONG)
  IF TIMER(.001) > fsm.timerState.start + fsm.timerState.duration THEN
    FSMChangeState fsm, newstate
  END IF
END SUB


'**********************************************************************************************
'   Rendering
'**********************************************************************************************
SUB _______________RENDERING (): END SUB
SUB renderBodies (engine AS tENGINE, p() AS tPOLY, body() AS tBODY, j() AS tJOINT, hits() AS tHIT, camera AS tCAMERA)
  DIM AS LONG i, layer
  DIM hitcount AS LONG
  DIM AS tVECTOR2d viewPortSize, viewPortCenter, camUpLeft, BB

  clearScreen engine

  vector2dSet viewPortSize, _WIDTH, _HEIGHT
  vector2dSet viewPortCenter, _WIDTH / 2.0, _HEIGHT / 2.0
  vector2dSubVectorND camUpLeft, camera.position, viewPortCenter
  FOR layer = 3 TO 0 STEP -1 ' Crude layering from rear to front
    FOR i = 0 TO UBOUND(body) - 1
      IF body(i).shape.renderOrder = layer THEN
        IF body(i).enable THEN
          'AABB to cut down on rendering objects out of camera view
          vector2dAddVectorND BB, body(i).fzx.position, camera.AABB
          IF AABBOverlap(camUpLeft.x, camUpLeft.y, viewPortSize.x, viewPortSize.y, BB.x, BB.y, camera.AABB_size.x, camera.AABB_size.y) THEN
            IF body(i).shape.ty = cSHAPE_CIRCLE THEN
              IF body(i).specFunc.func = 0 THEN '0-normal 1-sensor
                IF body(i).shape.texture = 0 THEN
                  IF cRENDER_WIREFRAME THEN renderWireframeCircle body(), i, camera
                ELSE
                  renderTexturedCircle body(), i, camera
                END IF
              ELSE
                IF cRENDER_WIREFRAME THEN renderWireframeCircle body(), i, camera
                _DEST engine.hiddenScr
                renderTexturedCircle body(), i, camera
                _DEST 0
              END IF
            ELSE IF body(i).shape.ty = cSHAPE_POLYGON THEN
                IF body(i).specFunc.func = 0 THEN
                  IF body(i).shape.texture = 0 THEN
                    IF cRENDER_WIREFRAME THEN renderWireframePoly p(), body(), i, camera
                  ELSE
                    renderTexturedBox p(), body(), i, camera
                  END IF
                ELSE
                  IF cRENDER_WIREFRAME THEN renderWireframePoly p(), body(), i, camera
                  _DEST engine.hiddenScr
                  renderTexturedBox p(), body(), i, camera
                  _DEST 0
                END IF
              END IF
            END IF
            IF cRENDER_AABB THEN
              DIM AS tVECTOR2d am, mm
              am.x = scalarMax(body(i).shape.maxDimension.x, body(i).shape.maxDimension.y) / 2
              am.y = scalarMax(body(i).shape.maxDimension.x, body(i).shape.maxDimension.y) / 2
              vector2dNegND mm, am
              worldToCameraBodyNR body(), camera, i, am
              worldToCameraBodyNR body(), camera, i, mm
              LINE (am.x, am.y)-(mm.x, mm.y), _RGB(0, 255, 0), B
              CIRCLE (am.x, am.y), 5
            END IF
          END IF
        END IF
      END IF
    NEXT
  NEXT
  IF cRENDER_JOINTS THEN
    FOR i = 1 TO UBOUND(j)
      renderJoints j(i), body(), camera
    NEXT
  END IF
  IF cRENDER_COLLISIONS THEN
    hitcount = 0
    DO WHILE hits(hitcount).A <> hits(hitcount).B
      renderWireframeCircleVector hits(hitcount).position, camera
      hitcount = hitcount + 1
      IF hitcount > UBOUND(hits) THEN EXIT DO
    LOOP
  END IF
END SUB

SUB initScreen (engine AS tENGINE, w AS LONG, h AS LONG, bbp AS LONG)
  _DELAY .5 ' Keeps from segfaulting when starting
  engine.displayScr = _NEWIMAGE(w, h, bbp)
  engine.hiddenScr = _NEWIMAGE(w, h, bbp)
  SCREEN engine.displayScr
END SUB

SUB clearScreen (engine AS tENGINE)
  _DEST engine.displayScr
  _PRINTMODE _KEEPBACKGROUND
  CLS , engine.displayClearColor
  _DEST engine.hiddenScr
  CLS , 0
  _DEST engine.displayScr
END SUB

SUB renderJoints (j AS tJOINT, b() AS tBODY, camera AS tCAMERA)
  DIM v1 AS tVECTOR2d
  DIM v2 AS tVECTOR2d
  worldToCameraBody b(), camera, j.body1, v1
  worldToCameraBody b(), camera, j.body2, v2
  LINE (v1.x, v1.y)-(v2.x, v2.y), j.wireframe_color
END SUB

SUB renderWireframePoly (p() AS tPOLY, b() AS tBODY, index AS LONG, camera AS tCAMERA)
  DIM a AS tVECTOR2d ' dummy vertices
  DIM b AS tVECTOR2d

  DIM i, element, element_next AS LONG
  FOR i = 0 TO b(index).pa.count
    element = b(index).pa.start + i
    element_next = b(index).pa.start + arrayNextIndex(i, b(index).pa.count)
    a = p(element).vert
    b = p(element_next).vert
    worldToCameraBody b(), camera, index, a
    worldToCameraBody b(), camera, index, b
    LINE (a.x, a.y)-(b.x, b.y), b(index).c
  NEXT
END SUB

SUB renderTexturedBox (p() AS tPOLY, b() AS tBODY, index AS LONG, camera AS tCAMERA)
  DIM vert(3) AS tVECTOR2d

  DIM AS SINGLE W, H
  DIM bm AS LONG ' Texture map
  bm = b(index).shape.texture
  W = _WIDTH(bm): H = _HEIGHT(bm)

  DIM i AS LONG
  FOR i = 0 TO 3
    vert(i) = p(b(index).pa.start + i).vert
    vert(i).x = vert(i).x + b(index).shape.offsetTextureX
    vert(i).y = vert(i).y + b(index).shape.offsetTextureY
    vert(i).x = vert(i).x * b(index).shape.scaleTextureX
    vert(i).y = vert(i).y * b(index).shape.scaleTextureY
    worldToCameraBody b(), camera, index, vert(i)
  NEXT

  IF b(index).fzx.velocity.x > 1 OR b(index).shape.flipTexture = 0 THEN
    _MAPTRIANGLE (0, 0)-(W - 1, 0)-(W - 1, H - 1), bm TO(vert(3).x, vert(3).y)-(vert(0).x, vert(0).y)-(vert(1).x, vert(1).y)
    _MAPTRIANGLE (0, 0)-(0, H - 1)-(W - 1, H - 1), bm TO(vert(3).x, vert(3).y)-(vert(2).x, vert(2).y)-(vert(1).x, vert(1).y)
  ELSE
    _MAPTRIANGLE (0, 0)-(W - 1, 0)-(W - 1, H - 1), bm TO(vert(0).x, vert(0).y)-(vert(3).x, vert(3).y)-(vert(2).x, vert(2).y)
    _MAPTRIANGLE (0, 0)-(0, H - 1)-(W - 1, H - 1), bm TO(vert(0).x, vert(0).y)-(vert(1).x, vert(1).y)-(vert(2).x, vert(2).y)
  END IF

END SUB

SUB renderWireframeCircle (b() AS tBODY, index AS LONG, camera AS tCAMERA)
  DIM tv AS tVECTOR2d
  worldToCameraBody b(), camera, index, tv
  CIRCLE (tv.x, tv.y), b(index).shape.radius * camera.zoom, b(index).c
  LINE (tv.x, tv.y)-(tv.x + COS(b(index).fzx.orient) * (b(index).shape.radius * camera.zoom), _
                     tv.y + SIN(b(index).fzx.orient) * (b(index).shape.radius) * camera.zoom), b(index).c
END SUB

SUB renderWireframeCircleVector (in AS tVECTOR2d, camera AS tCAMERA)
  DIM tv AS tVECTOR2d
  worldToCamera camera, in, tv
  CIRCLE (tv.x, tv.y), 2.0 * camera.zoom, _RGB(127, 127, 0)
END SUB

SUB renderTexturedCircle (b() AS tBODY, index AS LONG, camera AS tCAMERA)
  DIM vert(3) AS tVECTOR2d
  DIM W, H AS LONG
  DIM bm AS LONG
  bm = b(index).shape.texture
  W = _WIDTH(bm): H = _HEIGHT(bm)
  vector2dSet vert(0), -b(index).shape.radius, -b(index).shape.radius
  vector2dSet vert(1), -b(index).shape.radius, b(index).shape.radius
  vector2dSet vert(2), b(index).shape.radius, b(index).shape.radius
  vector2dSet vert(3), b(index).shape.radius, -b(index).shape.radius
  DIM i AS LONG
  FOR i = 0 TO 3
    worldToCameraBody b(), camera, index, vert(i)
  NEXT
  _MAPTRIANGLE (0, 0)-(0, H - 1)-(W - 1, H - 1), bm TO(vert(0).x, vert(0).y)-(vert(1).x, vert(1).y)-(vert(2).x, vert(2).y)
  _MAPTRIANGLE (0, 0)-(W - 1, 0)-(W - 1, H - 1), bm TO(vert(0).x, vert(0).y)-(vert(3).x, vert(3).y)-(vert(2).x, vert(2).y)
END SUB

SUB mapImage (src AS LONG, dest AS LONG, p AS tVECTOR2d, bitmask AS LONG)
  DIM AS tVECTOR2d srcVert(3), vert(3)
  DIM AS LONG w, h, bitMaskHorz, bitMaskVert, bitMaskXYYX
  w = _WIDTH(src): h = _HEIGHT(src)
  vector2dSet vert(0), p.x, p.y
  vector2dSet vert(1), p.x + w, p.y
  vector2dSet vert(2), p.x + w, p.y + h
  vector2dSet vert(3), p.x, p.y + h

  vector2dSet srcVert(0), 0, 0
  vector2dSet srcVert(1), w - 1, 0
  vector2dSet srcVert(2), w - 1, h - 1
  vector2dSet srcVert(3), 0, h - 1

  bitMaskHorz = _SHR(bitmask, 31) AND 1
  bitMaskVert = _SHR(bitmask, 30) AND 1
  bitMaskXYYX = _SHR(bitmask, 29) AND 1

  IF bitMaskXYYX THEN
    vector2dSwap srcVert(1), srcVert(3)
  END IF

  IF bitMaskHorz THEN
    vector2dSwap srcVert(0), srcVert(1)
    vector2dSwap srcVert(2), srcVert(3)
  END IF

  IF bitMaskVert THEN
    vector2dSwap srcVert(0), srcVert(3)
    vector2dSwap srcVert(1), srcVert(2)
  END IF

  _MAPTRIANGLE (srcVert(0).x, srcVert(0).y)-(srcVert(1).x, srcVert(1).y)-(srcVert(2).x, srcVert(2).y), _
         src TO(vert(0).x, vert(0).y)-(vert(1).x, vert(1).y)-(vert(2).x, vert(2).y), dest
  _MAPTRIANGLE (srcVert(0).x, srcVert(0).y)-(srcVert(3).x, srcVert(3).y)-(srcVert(2).x, srcVert(2).y), _
         src TO(vert(0).x, vert(0).y)-(vert(3).x, vert(3).y)-(vert(2).x, vert(2).y), dest

END SUB

SUB alphaImage (alpha AS INTEGER, image AS LONG, p AS tVECTOR2d, scale AS _FLOAT)
  _SETALPHA alpha, 0 TO _RGB(255, 255, 255), image
  _CLEARCOLOR _RGB(0, 0, 0), image
  _PUTIMAGE (p.x, p.y)-(p.x + (_WIDTH(image) * scale), p.y + (_HEIGHT(image) * scale)), image
END SUB

SUB createLightingMask (engine AS tENGINE, tile() AS tTILE, xs AS LONG, ys AS LONG)
  engine.displayMask = allocateTextureEX(tile(), _NEWIMAGE(xs, ys, 32))
  DIM AS LONG position, maxdist
  DIM AS tVECTOR2d p, c, z
  DIM AS _UNSIGNED _BYTE dist
  DIM AS _MEM buffer
  DIM AS _OFFSET offset, lastOffset
  buffer = _MEMIMAGE(tile(engine.displayMask).t)
  offset = buffer.OFFSET
  lastOffset = buffer.OFFSET + xs * ys * 4
  position = 0
  c.x = xs / 2
  c.y = ys / 2
  z.x = 0
  z.y = 0
  maxdist = INT(vector2dDistance(c, z))
  DO
    p.x = position MOD xs
    p.y = INT(position / xs)
    dist = impulseClamp(0, 255, vector2dDistance(p, c) / maxdist * 255.0)
    _MEMPUT buffer, offset + 0, &H00 AS _UNSIGNED _BYTE
    _MEMPUT buffer, offset + 1, &H00 AS _UNSIGNED _BYTE
    _MEMPUT buffer, offset + 2, &H00 AS _UNSIGNED _BYTE
    _MEMPUT buffer, offset + 3, dist AS _UNSIGNED _BYTE 'Alpha channel
    position = position + 1
    offset = offset + 4
  LOOP UNTIL offset = lastOffset
  _MEMFREE buffer
END SUB

SUB colorMixBitmap (img AS LONG, rgb AS LONG, amount AS _FLOAT)
  DIM AS _UNSIGNED _BYTE r, g, b, nr, ng, nb
  DIM AS _MEM buffer
  DIM AS _OFFSET offset, lastOffset
  buffer = _MEMIMAGE(img)
  offset = buffer.OFFSET
  lastOffset = buffer.OFFSET + _WIDTH(img) * _HEIGHT(img) * 4
  $CHECKING:OFF
  DO
    r = _MEMGET(buffer, offset + 0, _UNSIGNED _BYTE)
    g = _MEMGET(buffer, offset + 1, _UNSIGNED _BYTE)
    b = _MEMGET(buffer, offset + 2, _UNSIGNED _BYTE)
    nr = colorChannelMixer(r, _RED(rgb), amount)
    ng = colorChannelMixer(g, _GREEN(rgb), amount)
    nb = colorChannelMixer(b, _BLUE(rgb), amount)
    _MEMPUT buffer, offset + 0, nr AS _UNSIGNED _BYTE
    _MEMPUT buffer, offset + 1, ng AS _UNSIGNED _BYTE
    _MEMPUT buffer, offset + 2, nb AS _UNSIGNED _BYTE
    offset = offset + 4
  LOOP UNTIL offset = lastOffset
  $CHECKING:ON
  _MEMFREE buffer

END SUB

'**********************************************************************************************
'   Texture Loading
'**********************************************************************************************
SUB _______________TEXTURE_HANDLING (): END SUB

FUNCTION allocateTexture (tile() AS tTILE)
  allocateTexture = UBOUND(tile)
  REDIM _PRESERVE tile(UBOUND(tile) + 1) AS tTILE
END FUNCTION

FUNCTION allocateTextureEX (tile() AS tTILE, img AS LONG)
  tile(UBOUND(tile)).t = img
  allocateTextureEX = UBOUND(tile)
  REDIM _PRESERVE tile(UBOUND(tile) + 1) AS tTILE
END FUNCTION

SUB loadBitmapError (tile() AS tTILE, index AS LONG, fl AS STRING)
  IF tile(index).t > -2 THEN
    PRINT "Unable to load image "; fl; " with return of "; tile(index).t
    END
  END IF
END SUB

SUB tileMapImagePosition (tile AS LONG, t AS tTILEMAP, sx1 AS LONG, sy1 AS LONG, sx2 AS LONG, sy2 AS LONG)
  DIM tile_width AS LONG
  DIM tile_height AS LONG
  DIM tile_x, tile_y AS LONG

  tile_width = t.tileSize + t.tilePadding
  tile_height = t.tileSize + t.tilePadding

  tile_x = tile MOD t.numberOfTilesX
  tile_y = INT(tile / t.numberOfTilesX)

  sx1 = tile_x * tile_width
  sy1 = tile_y * tile_height

  sx2 = sx1 + t.tileSize - t.tilePadding
  sy2 = sy1 + t.tileSize - t.tilePadding
END SUB

FUNCTION idToTile (t() AS tTILE, id AS LONG)
  DIM AS LONG index
  FOR index = 0 TO UBOUND(t)
    IF t(index).id = id THEN
      idToTile = index
      EXIT FUNCTION
    END IF
  NEXT
  idToTile = -1
END FUNCTION

SUB freeImageEX (tile() AS tTILE, img AS LONG)
  IF img < -1 THEN
    DIM AS LONG i, j
    FOR i = 0 TO UBOUND(tile) - 1
      IF tile(i).t = img THEN
        FOR j = i TO UBOUND(tile) - 1
          tile(j) = tile(j + 1)
        NEXT
        IF UBOUND(tile) > 0 THEN REDIM _PRESERVE tile(UBOUND(tile) - 1) AS tTILE
        IF img < -1 THEN _FREEIMAGE img
        EXIT SUB
      END IF
    NEXT
  END IF
END SUB

SUB freeAllTiles (tile() AS tTILE)
  DO WHILE UBOUND(tile)
    IF tile(UBOUND(tile) - 1).t < -1 THEN
      freeImageEX tile(), tile(UBOUND(tile) - 1).t
    ELSE
      REDIM _PRESERVE tile(UBOUND(tile) - 1) AS tTILE
    END IF
  LOOP
END SUB

'**********************************************************************************************
'   TMX Loading
' Related functions are in XML Section
'**********************************************************************************************

SUB _______________TMX_FILE_HANDLING (): END SUB

SUB loadFile (fl AS STRING, in() AS STRING)
  fl = LTRIM$(RTRIM$(fl)) 'clean the filename
  DIM AS LONG file_num
  IF _FILEEXISTS(fl) THEN
    file_num = FREEFILE
    OPEN fl FOR INPUT AS #file_num
    DO UNTIL EOF(file_num)
      LINE INPUT #file_num, in(UBOUND(in))
      REDIM _PRESERVE in(UBOUND(in) + 1) AS STRING
    LOOP
    CLOSE file_num
  ELSE
    PRINT "File not found :"; fl
    END
  END IF
END SUB

SUB loadTSX (dir AS STRING, tile() AS tTILE, tilemap AS tTILEMAP, firstid AS LONG)
  DIM AS STRING tsx(0), i
  DIM AS LONG img, index, id, arg

  loadFile dir + tilemap.tsxFile, tsx()
  FOR index = 0 TO UBOUND(tsx)
    i = tsx(index)
    IF INSTR(i, "<tileset") THEN
      tilemap.numberOfTilesX = getXMLArgValue(i, "columns=")
      tilemap.tileCount = getXMLArgValue(i, "tilecount=")
      tilemap.tilePadding = 0
    END IF
    IF INSTR(i, "<image source=") THEN
      tilemap.file = getXMLArgString$(i, "<image source=")
      img = allocateTextureEX(tile(), _LOADIMAGE(RTRIM$(LTRIM$(dir + tilemap.file))))
      tilemap.tileMap = tile(img).t
      loadBitmapError tile(), img, dir + tilemap.file
      loadTilesIntoBuffer tile(), tilemap, firstid
    END IF
    IF INSTR(i, "<tile ") THEN
      id = idToTile(tile(), getXMLArgValue(i, "id="))
      tile(id).class = getXMLArgString$(i, "type=")
      IF INSTR(tile(id).class, "CHARACTER") THEN
        index = index + 1: i = tsx(index)
        IF INSTR(i, "<properties>") THEN
          index = index + 1: i = tsx(index)
          DO
            IF INSTR(i, "<property ") THEN
              IF getXMLArgString$(i, "name=") = "CHAR" THEN
                arg = ASC(getXMLArgString$(i, "value="))
                tileFont(arg).id = id + 2 ' No Idea why this is off
                tileFont(arg).t = tile(idToTile(tile(), tileFont(arg).id)).t
                tileFont(arg).c = arg
              END IF
            END IF
            index = index + 1: i = tsx(index)
          LOOP UNTIL INSTR(i, "/")
        END IF
      END IF
    END IF
  NEXT
END SUB

SUB loadTilesIntoBuffer (tile() AS tTILE, tilemap AS tTILEMAP, firstid AS LONG)
  DIM AS LONG textmapCount
  DIM AS LONG x1, y1, x2, y2, index

  FOR index = 0 TO tilemap.tileCount - 1
    textmapCount = allocateTextureEX(tile(), _NEWIMAGE(tilemap.tileWidth, tilemap.tileHeight, 32))
    tileMapImagePosition index, tilemap, x1, y1, x2, y2
    _PUTIMAGE (0, 0), tilemap.tileMap, tile(textmapCount).t, (x1, y1)-(x2, y2)
    tile(textmapCount).id = firstid + index
  NEXT
  freeImageEX tile(), tilemap.tileMap
END SUB

'**********************************************************************************************
'   Construct Game Map
'**********************************************************************************************
SUB _______________CONSTRUCT_GAMEMAP (): END SUB

SUB constructGameMap (engine AS tENGINE, p() AS tPOLY, body() AS tBODY, gamemap() AS tTILE, tile() AS tTILE, tilemap AS tTILEMAP, lights() AS tLIGHT)
  DIM AS LONG xs, ys, tempID, backgroundImageID
  xs = tilemap.mapWidth * tilemap.tileWidth * tilemap.tilescale
  ys = tilemap.mapHeight * tilemap.tileHeight * tilemap.tilescale

  tempID = createBoxBodyEx(p(), body(), "_BACKGROUND", xs / 2, ys / 2)
  setBody p(), body(), cPARAMETER_POSITION, tempID, xs / 2, xs / 2
  setBody p(), body(), cPARAMETER_ORIENT, tempID, 0, 0
  setBody p(), body(), cPARAMETER_STATIC, tempID, 1, 0
  setBody p(), body(), cPARAMETER_COLLISIONMASK, tempID, 0, 0
  setBody p(), body(), cPARAMETER_NOPHYSICS, tempID, 1, 0
  setBody p(), body(), cPARAMETER_RENDERORDER, tempID, 3, 0
  backgroundImageID = allocateTextureEX(tile(), _NEWIMAGE(tilemap.tileWidth * tilemap.mapWidth, tilemap.tileHeight * tilemap.mapHeight, 32))
  CLS , engine.displayClearColor

  applyGameMapToBody engine, gamemap(), tile(), tilemap, tile(backgroundImageID).t, lights()
  setBody p(), body(), cPARAMETER_TEXTURE, tempID, tile(backgroundImageID).t, 0
END SUB

SUB addLightsToGamemap (gamemap() AS tTILE, tilemap AS tTILEMAP, lights() AS tLIGHT)
  DIM AS LONG index
  FOR index = 0 TO UBOUND(lights) - 1
    gamemap(xyToGameMap(tilemap, lights(index).position.x, lights(index).position.y)).lightColor = lights(index).lightColor
  NEXT
END SUB

FUNCTION createLightingMask (engine AS tENGINE, tile() AS tTILE, tilemap AS tTILEMAP, lights() AS tLIGHT)
  DIM AS LONG img, index, x, y, lc, flatPos, W, dx, dy, vlq
  DIM AS _FLOAT dist, maxDist
  ' DIM AS tVECTOR2d current
  maxDist = tilemap.tileWidth * engine.mapParameters.maxLightDistance ' Maximum Light influence
  img = allocateTextureEX(tile(), _NEWIMAGE(tilemap.tileWidth * tilemap.mapWidth, tilemap.tileHeight * tilemap.mapHeight, 32))
  DIM AS _MEM buffer
  DIM AS _OFFSET offset, lastOffset
  buffer = _MEMIMAGE(tile(img).t)
  offset = buffer.OFFSET
  lastOffset = buffer.OFFSET + _WIDTH(tile(img).t) * _HEIGHT(tile(img).t) * 4
  flatPos = 0
  PRINT #logfile, TIMER(.001)
  $CHECKING:OFF
  W = _WIDTH(tile(img).t)
  DO
    x = flatPos MOD W
    y = INT(flatPos / W)
    lc = 0
    FOR index = 0 TO UBOUND(lights) - 1
      dx = x - lights(index).position.x
      dy = y - lights(index).position.y
      vlq = dx * dx + dy * dy
      IF vlq < maxDist * maxDist THEN
        dist = SQR(vlq)
        lc = colorMixer(lights(index).lightColor, lc, impulseClamp(0, 1, (maxDist / dist) / UBOUND(lights) * .2))
        _MEMPUT buffer, offset + 0, _BLUE(lc) AS _UNSIGNED _BYTE
        _MEMPUT buffer, offset + 1, _GREEN(lc) AS _UNSIGNED _BYTE
        _MEMPUT buffer, offset + 2, _RED(lc) AS _UNSIGNED _BYTE
        _MEMPUT buffer, offset + 3, _ALPHA(lc) AS _UNSIGNED _BYTE
      END IF
    NEXT
    offset = offset + 4
    flatPos = flatPos + 1
  LOOP UNTIL offset = lastOffset
  $CHECKING:ON
  createLightingMask = img
  _MEMFREE buffer
  PRINT #logfile, TIMER(.001)
END FUNCTION

SUB refreshGameMap (engine AS tENGINE, body() AS tBODY, gamemap() AS tTILE, tile() AS tTILE, tilemap AS tTILEMAP, lights() AS tLIGHT)
  DIM AS LONG xs, ys, tempID, backgroundImageID
  xs = tilemap.mapWidth * tilemap.tileWidth * tilemap.tilescale
  ys = tilemap.mapHeight * tilemap.tileHeight * tilemap.tilescale
  tempID = bodyManagerID(body(), "_BACKGROUND")
  IF tempID > -1 THEN
    backgroundImageID = body(tempID).shape.texture
    _DEST backgroundImageID
    CLS , engine.displayClearColor
    _DEST 0
    applyGameMapToBody engine, gamemap(), tile(), tilemap, backgroundImageID, lights()
  END IF
END SUB

SUB applyGameMapToBody (engine AS tENGINE, gamemap() AS tTILE, tile() AS tTILE, tilemap AS tTILEMAP, backGroundImageID AS LONG, lights() AS tLIGHT)
  DIM AS LONG x, y
  DIM AS LONG lightmask, bgc, lmc

  buildMultiTileMap gamemap(), tile(), tilemap, backGroundImageID, 0

  lightmask = createLightingMask(engine, tile(), tilemap, lights())
  FOR y = 0 TO _HEIGHT(tile(lightmask).t)
    FOR x = 0 TO _WIDTH(tile(lightmask).t)
      _SOURCE tile(lightmask).t
      lmc = POINT(x, y)
      _SOURCE backGroundImageID
      _DEST backGroundImageID
      bgc = POINT(x, y)
      PSET (x, y), colorMixer(lmc, bgc, .75)
    NEXT
  NEXT
  freeImageEX tile(), lightmask
  _SOURCE 0
  _DEST 0
END SUB

SUB buildMultiTileMap (map() AS tTILE, tile() AS tTILE, layout AS tTILEMAP, img AS LONG, layer AS INTEGER)
  DIM AS LONG index
  DIM AS LONG sx, tileId, bitMaskLo, tileLayer
  DIM AS tVECTOR2d p
  sx = layout.tilescale * layout.tileSize
  FOR index = 0 TO UBOUND(map)
    IF layer = 0 THEN
      tileLayer = map(index).t
    ELSE
      tileLayer = map(index).t0
    END IF
    IF tileLayer <> 0 THEN
      bitMaskLo = tileLayer AND &H00FFFFFF 'Extract actual Tile ID number
      p.x = (index MOD layout.mapWidth) * sx
      p.y = INT(index / layout.mapWidth) * sx
      tileId = idToTile(tile(), bitMaskLo)
      mapImage tile(tileId).t, img, p, tileLayer
    END IF
  NEXT
END SUB

'**********************************************************************************************
'   Camera and World Translation subs
'**********************************************************************************************
SUB _______________CAMERA_TRANSLATE_SUBS (): END SUB
SUB worldToCamera (camera AS tCAMERA, iVert AS tVECTOR2d, oVert AS tVECTOR2d)
  DIM screenCenter AS tVECTOR2d
  vector2dSet screenCenter, _WIDTH / 2 * (1 / camera.zoom), _HEIGHT / 2 * (1 / camera.zoom) ' Camera Center
  vector2dAddVector oVert, iVert ' Add Position
  vector2dSubVector oVert, camera.position 'Sub Camera Position
  vector2dAddVector oVert, screenCenter ' Add to camera Center
  vector2dMultiplyScalar oVert, camera.zoom 'Zoom everything
END SUB

SUB worldToCameraBody (body() AS tBODY, camera AS tCAMERA, index AS LONG, vert AS tVECTOR2d)
  DIM screenCenter AS tVECTOR2d
  vector2dSet screenCenter, _WIDTH / 2 * (1 / camera.zoom), _HEIGHT / 2 * (1 / camera.zoom) ' Camera Center
  matrix2x2MultiplyVector body(index).shape.u, vert, vert ' Rotate body
  vector2dAddVector vert, body(index).fzx.position ' Add Position
  vector2dSubVector vert, camera.position 'Sub Camera Position
  vector2dAddVector vert, screenCenter ' Add to Screen Center
  vector2dMultiplyScalar vert, camera.zoom 'Zoom everything
END SUB

SUB worldToCameraBodyNR (body() AS tBODY, camera AS tCAMERA, index AS LONG, vert AS tVECTOR2d)
  DIM screenCenter AS tVECTOR2d
  vector2dSet screenCenter, _WIDTH / 2 * (1 / camera.zoom), _HEIGHT / 2 * (1 / camera.zoom) ' Camera Center
  vector2dAddVector vert, body(index).fzx.position ' Add Position
  vector2dSubVector vert, camera.position 'Sub Camera Position
  vector2dAddVector vert, screenCenter ' Add to camera Center
  vector2dMultiplyScalar vert, camera.zoom 'Zoom everything
END SUB

SUB cameraToWorld (camera AS tCAMERA, iVec AS tVECTOR2d, oVec AS tVECTOR2d)
  DIM AS tVECTOR2d screenCenter
  vector2dSet screenCenter, _WIDTH / 2.0 * (1 / camera.zoom), _HEIGHT / 2.0 * (1 / camera.zoom) ' Camera Center
  vector2dSet oVec, iVec.x * (1 / camera.zoom), iVec.y * (1 / camera.zoom)
  vector2dAddVector oVec, camera.position
  vector2dSubVector oVec, screenCenter
END SUB

'**********************************************************************************************
'   GUI Handling
'**********************************************************************************************

SUB _______________GUI_MESSAGE_HANDLING (): END SUB
SUB prepMessage (tile() AS tTILE, tilemap AS tTILEMAP, message AS tMESSAGE, messageString AS STRING)
  DIM AS LONG i, numberOfLines, linelengthCount, longestLine, ch
  DIM AS tVECTOR2d cursor
  numberOfLines = 1
  longestLine = 1
  'prescanline to determine dimensions
  FOR i = 1 TO LEN(messageString)
    linelengthCount = linelengthCount + 1
    ch = ASC(MID$(messageString, i, 1))
    IF ch = 95 THEN ' check for underscore
      numberOfLines = numberOfLines + 1
      IF linelengthCount > longestLine THEN longestLine = linelengthCount
      linelengthCount = 0
    END IF
  NEXT
  IF linelengthCount > longestLine THEN longestLine = linelengthCount
  message.baseImage = allocateTextureEX(tile(), _NEWIMAGE(longestLine * tilemap.tileWidth, numberOfLines * tilemap.tileHeight, 32))
  _DEST tile(message.baseImage).t
  FOR i = 1 TO LEN(messageString)
    ch = ASC(MID$(UCASE$(messageString), i, 1))
    IF ch = 95 THEN
      cursor.x = 0
      cursor.y = cursor.y + tilemap.tileHeight
    ELSE
      _PUTIMAGE (cursor.x, cursor.y), tileFont(ch).t, tile(message.baseImage).t
      cursor.x = cursor.x + tilemap.tileWidth
    END IF
  NEXT
  _DEST 0
END SUB

SUB addMessage (tile() AS tTILE, tilemap AS tTILEMAP, message() AS tMESSAGE, messageString AS STRING, timeOut AS LONG, position AS tVECTOR2d, scale AS _FLOAT)
  DIM AS LONG m
  REDIM _PRESERVE message(UBOUND(message) + 1) AS tMESSAGE
  m = UBOUND(message)
  prepMessage tile(), tilemap, message(m), messageString
  message(m).fsm.timerState.duration = timeOut
  message(m).position = position
  message(m).scale = scale
  FSMChangeState message(m).fsm, cFSM_MESSAGE_INIT
END SUB

SUB handleMessages (tile() AS tTILE, message() AS tMESSAGE)
  DIM AS LONG alpha, i
  i = UBOUND(message)
  IF i > 0 THEN
    SELECT CASE message(i).fsm.currentState
      CASE cFSM_MESSAGE_IDLE:
      CASE cFSM_MESSAGE_INIT:
        FSMChangeState message(i).fsm, cFSM_MESSAGE_FADEIN
      CASE cFSM_MESSAGE_FADEIN:
        alpha = scalarLERPSmoother##(0, 255, scalarLERPProgress(message(i).fsm.timerState.start, message(i).fsm.timerState.start + (message(i).fsm.timerState.duration * .1)))
        alphaImage alpha, tile(message(i).baseImage).t, message(i).position, message(i).scale
        FSMChangeStateOnTimer message(i).fsm, cFSM_MESSAGE_SHINE
      CASE cFSM_MESSAGE_SHINE:
        alphaImage 255, tile(message(i).baseImage).t, message(i).position, message(i).scale
        FSMChangeStateOnTimer message(i).fsm, cFSM_MESSAGE_FADEOUT
      CASE cFSM_MESSAGE_FADEOUT:
        alpha = scalarLERPSmoother##(255, 0, scalarLERPProgress(message(i).fsm.timerState.start, message(i).fsm.timerState.start + (message(i).fsm.timerState.duration * .1)))
        alphaImage alpha, tile(message(i).baseImage).t, message(i).position, message(i).scale
        FSMChangeStateOnTimer message(i).fsm, cFSM_MESSAGE_CLEANUP
      CASE cFSM_MESSAGE_CLEANUP:
        freeImageEX tile(), tile(message(i).baseImage).t
        removeMessage message(), i
        'No need to change back to IDLE since we are deleting this message
      CASE ELSE
        'Nada
    END SELECT
  END IF
END SUB

SUB removeMessage (message() AS tMESSAGE, i AS LONG)
  DIM AS LONG j
  IF i < UBOUND(message) THEN
    FOR j = i TO UBOUND(message) - 1
      message(j) = message(j + 1)
    NEXT
  END IF
  IF UBOUND(message) > 0 THEN REDIM _PRESERVE message(UBOUND(message) - 1) AS tMESSAGE
END SUB

'**********************************************************************************************
'   A* Path Finding
'  Needs Proper Integration
'**********************************************************************************************

SUB _______________A_STAR_PATHFINDING (): END SUB

FUNCTION AStarSetPath$ (entity AS tENTITY, startPos AS tVECTOR2d, TargetPos AS tVECTOR2d, gamemap() AS tTILE, tilemap AS tTILEMAP)
  IF TargetPos.x >= 0 AND TargetPos.x <= tilemap.mapWidth AND _
     TargetPos.y >= 0 AND TargetPos.y <= tilemap.mapHeight AND _
     AStarCollision(gamemap(), tilemap, targetpos) THEN
    DIM TargetFound AS LONG
    DIM PathMap(tilemap.mapWidth * tilemap.mapHeight) AS tPATH
    DIM maxpathlength AS LONG
    DIM ix, iy, count, i AS LONG
    DIM NewG AS LONG
    DIM OpenPathCount AS LONG
    DIM LowF AS LONG
    DIM ixOptimal, iyOptimal, OptimalPath_i AS LONG
    DIM startreached AS LONG
    DIM pathlength AS LONG
    DIM AS STRING pathString
    DIM AS tVECTOR2d currPos, nextPos
    DIM AS tVECTOR2d startPosition
    maxpathlength = tilemap.mapWidth * tilemap.mapHeight
    DIM SearchPathSet(4) AS tPATH, OpenPathSet(maxpathlength) AS tPATH
    startPosition = startPos

    FOR ix = 0 TO tilemap.mapWidth - 1
      FOR iy = 0 TO tilemap.mapHeight - 1
        PathMap(xyToGameMapPlain(tilemap, ix, iy)).position.x = ix
        PathMap(xyToGameMapPlain(tilemap, ix, iy)).position.y = iy
      NEXT
    NEXT
    TargetFound = 0

    DO
      PathMap(xyToGameMapPlain(tilemap, startPosition.x, startPosition.y)).status = 2
      count = count + 1

      IF PathMap(xyToGameMapPlain(tilemap, TargetPos.x, TargetPos.y)).status = 2 THEN TargetFound = 1: EXIT DO
      IF count > maxpathlength THEN EXIT DO

      SearchPathSet(0) = PathMap(xyToGameMapPlain(tilemap, startPosition.x, startPosition.y))
      IF startPosition.x < tilemap.mapWidth THEN SearchPathSet(1) = PathMap(xyToGameMapPlain(tilemap, startPosition.x + 1, startPosition.y))
      IF startPosition.x > 0 THEN SearchPathSet(2) = PathMap(xyToGameMapPlain(tilemap, startPosition.x - 1, startPosition.y))
      IF startPosition.y < tilemap.mapHeight THEN SearchPathSet(3) = PathMap(xyToGameMapPlain(tilemap, startPosition.x, startPosition.y + 1))
      IF startPosition.y > 0 THEN SearchPathSet(4) = PathMap(xyToGameMapPlain(tilemap, startPosition.x, startPosition.y - 1))

      FOR i = 1 TO 4
        IF AStarCollision(gamemap(), tilemap, SearchPathSet(i).position) THEN

          IF SearchPathSet(i).status = 1 THEN
            NewG = AStarPathGCost(SearchPathSet(0).g)
            IF NewG < SearchPathSet(i).g THEN SearchPathSet(i).g = NewG
          END IF

          IF SearchPathSet(i).status = 0 THEN
            SearchPathSet(i).parent = SearchPathSet(0).position
            SearchPathSet(i).status = 1
            SearchPathSet(i).g = AStarPathGCost(SearchPathSet(0).g)
            SearchPathSet(i).h = AStarPathHCost(SearchPathSet(i), TargetPos, entity)
            SearchPathSet(i).f = SearchPathSet(i).g + SearchPathSet(i).h + (AStarWalkway(gamemap(), tilemap, SearchPathSet(i).position) * 10)
            OpenPathSet(OpenPathCount) = SearchPathSet(i)
            OpenPathCount = OpenPathCount + 1
          END IF
        END IF
      NEXT

      IF startPosition.x < tilemap.mapWidth THEN PathMap(xyToGameMapPlain(tilemap, startPosition.x + 1, startPosition.y)) = SearchPathSet(1)
      IF startPosition.x > 0 THEN PathMap(xyToGameMapPlain(tilemap, startPosition.x - 1, startPosition.y)) = SearchPathSet(2)
      IF startPosition.y < tilemap.mapHeight THEN PathMap(xyToGameMapPlain(tilemap, startPosition.x, startPosition.y + 1)) = SearchPathSet(3)
      IF startPosition.y > 0 THEN PathMap(xyToGameMapPlain(tilemap, startPosition.x, startPosition.y - 1)) = SearchPathSet(4)

      IF OpenPathCount > (maxpathlength - 4) THEN EXIT DO

      LowF = 32000: ixOptimal = 0: iyOptimal = 0
      FOR i = 0 TO OpenPathCount
        IF OpenPathSet(i).status = 1 AND OpenPathSet(i).f <> 0 THEN
          IF OpenPathSet(i).f < LowF THEN
            LowF = OpenPathSet(i).f
            ixOptimal = OpenPathSet(i).position.x
            iyOptimal = OpenPathSet(i).position.y
            OptimalPath_i = i
          END IF
        END IF
      NEXT

      IF ixOptimal = 0 AND iyOptimal = 0 THEN EXIT DO
      startPosition = PathMap(xyToGameMapPlain(tilemap, ixOptimal, iyOptimal)).position
      OpenPathSet(OptimalPath_i).status = 2
    LOOP

    IF TargetFound = 1 THEN

      DIM backpath(maxpathlength) AS tPATH
      backpath(0).position = PathMap(xyToGameMapPlain(tilemap, TargetPos.x, TargetPos.y)).position

      startreached = 0
      FOR i = 1 TO count
        backpath(i).position = PathMap(xyToGameMapPlain(tilemap, backpath(i - 1).position.x, backpath(i - 1).position.y)).parent
        IF (startreached = 0) AND (backpath(i).position.x = startPosition.x) AND (backpath(i).position.y = startPosition.y) THEN
          pathlength = i: startreached = 1
        END IF
      NEXT

      pathString = ""
      FOR i = count TO 1 STEP -1
        IF backpath(i).position.x > 0 AND backpath(i).position.x < tilemap.mapWidth AND backpath(i).position.y > 0 AND backpath(i).position.y < tilemap.mapHeight THEN
          currPos = backpath(i).position
          nextPos = backpath(i - 1).position
          IF nextPos.x < currPos.x THEN pathString = pathString + "L"
          IF nextPos.x > currPos.x THEN pathString = pathString + "R"
          IF nextPos.y < currPos.y THEN pathString = pathString + "U"
          IF nextPos.y > currPos.y THEN pathString = pathString + "D"
        END IF
      NEXT
    END IF
    AStarSetPath = pathString
  END IF
END FUNCTION

FUNCTION AStarPathGCost (ParentG)
  AStarPathGCost = ParentG + 10
END FUNCTION

FUNCTION AStarPathHCost (TilePath AS tPATH, TargetPos AS tVECTOR2d, entity AS tENTITY)
  DIM dx, dy AS LONG
  DIM distance AS DOUBLE
  DIM SearchIntensity AS LONG
  dx = ABS(TilePath.position.x - TargetPos.x)
  dy = ABS(TilePath.position.y - TargetPos.y)
  distance = SQR(dx ^ 2 + dy ^ 2)
  SearchIntensity = INT(RND * entity.parameters.drunkiness)
  AStarPathHCost = ((SearchIntensity / 20) + 10) * (dx + dy + ((SearchIntensity / 10) * distance))
END FUNCTION

FUNCTION AStarCollision (gamemap() AS tTILE, tilemap AS tTILEMAP, Position AS tVECTOR2d)
  ' This is hack that requires the block at 0 to be a collider block
  AStarCollision = NOT (gamemap(vector2dToGameMapPlain(tilemap, Position)).collision = gamemap(0).collision)
END FUNCTION

FUNCTION AStarWalkway (gamemap() AS tTILE, tilemap AS tTILEMAP, position AS tVECTOR2d)
  'This is to detect optimal paths based on using sidewalks
  'I'm using the same block as collision block except the rotated bit is set
  AStarWalkway = (gamemap(vector2dToGameMapPlain(tilemap, position)).collision AND &HFFFFFF) = (gamemap(0).collision AND &HFFFFFF)
END FUNCTION

'**********************************************************************************************
'   XML
'**********************************************************************************************

SUB _______________XML_HANDLING (): END SUB
SUB XMLparse (dir AS STRING, file AS STRING, con() AS tSTRINGTUPLE)
  DIM AS STRING xml(0), x, element_name, stack(0), context
  DIM AS LONG index
  DIM AS LONG element_start, element_ending
  DIM AS LONG element_first_space, element_pop
  DIM AS LONG element_end_of_family, element_no_family
  DIM AS LONG header_start, header_finish
  DIM AS LONG element_name_start, element_name_end
  DIM AS LONG comment_start, comment_end, comment_multiline_start, comment_multiline_end
  DIM AS LONG mute, j

  loadFile trim$(dir) + trim$(file), xml()

  mute = 0

  FOR index = 0 TO UBOUND(xml) - 1
    x = RTRIM$(LTRIM$(xml(index)))
    header_start = INSTR(x, "<?")
    header_finish = INSTR(x, "?>")
    comment_start = INSTR(x, "<!")
    comment_end = INSTR(x, "!>")
    comment_multiline_start = INSTR(x, "<!--")
    comment_multiline_end = INSTR(x, "-->")
    IF comment_start OR comment_multiline_start THEN mute = 1
    IF comment_end OR comment_multiline_end THEN mute = 0

    IF header_start = 0 AND mute = 0 THEN
      element_start = INSTR(x, "<")
      element_end_of_family = INSTR(x, "</")
      element_first_space = INSTR(element_start, x, " ")
      element_pop = INSTR(x, "/")
      element_ending = INSTR(x, ">")
      element_no_family = INSTR(x, "/>")
      element_name = ""
      IF element_start THEN
        'Get Element Name
        'Starting character
        IF element_end_of_family THEN
          element_name_start = element_end_of_family + 2 'start after '</'
        ELSE
          element_name_start = element_start + 1 'start after '<'
        END IF
        'Ending character
        IF element_first_space THEN ' check for a space after the element name
          element_name_end = element_first_space
        ELSE
          IF element_no_family THEN ' check for no family
            element_name_end = element_no_family
          ELSE
            IF element_ending THEN ' check for family name
              element_name_end = element_ending
            ELSE
              PRINT "XML malformed. "; x
              waitkey
              SYSTEM
            END IF
          END IF
        END IF
        element_name = MID$(x, element_name_start, element_name_end - element_name_start)
        ' Determine level
        IF element_end_of_family = 0 THEN
          pushStackString stack(), element_name
          ' Compile context tree
          context = ""
          FOR j = 0 TO UBOUND(stack) - 1 'push_pop
            context = context + stack(j)
            IF j < UBOUND(stack) - 1 THEN
              context = context + " "
            END IF
          NEXT
        END IF
        IF element_pop THEN popStackString stack()
      END IF
      ' push onto Context tuple
      IF element_end_of_family = 0 THEN pushStackContextArg con(), context, x
    END IF
  NEXT
END SUB

SUB XMLApplyAttributes (engine AS tENGINE, world AS tWORLD, gamemap() AS tTILE, entity() AS tENTITY, p() AS tPOLY, body() AS tBODY, camera AS tCAMERA, tile() AS tTILE, tilemap AS tTILEMAP, dir AS STRING, con() AS tSTRINGTUPLE)
  DIM AS STRING context, arg, elementName, elementString, objectGroupName, objectName, objectType, propertyName, propertyValueString, objectID, mapLayer, elementValueString
  DIM AS LONG index, firstId, start, comma, mapIndex, tempId, sensorImage, tempColor
  DIM AS tVECTOR2d o, tempVec
  DIM AS _FLOAT elementValue, xp, yp, xs, ys, propertyValue, tempVal, xl, yl
  DIM AS tLIGHT lights(0)
  FOR index = 0 TO UBOUND(con) - 1
    context = LTRIM$(RTRIM$(con(index).contextName))
    arg = LTRIM$(RTRIM$(con(index).arg))
    SELECT CASE context
      CASE "map":
        tilemap.mapWidth = getXMLArgValue(arg, " width=")
        tilemap.mapHeight = getXMLArgValue(arg, " height=")
        tilemap.tileWidth = getXMLArgValue(arg, " tilewidth=")
        tilemap.tileHeight = getXMLArgValue(arg, " tileheight=")
        tilemap.tileSize = tilemap.tileWidth
      CASE "map group":
        elementName = getXMLArgString$(arg, " name=")
      CASE "map group properties property":
        SELECT CASE elementName
          CASE "SOUNDS":
            addMusic sounds(), getXMLArgString$(arg, " value="), getXMLArgString$(arg, " name=")
        END SELECT
      CASE "map tileset":
        tilemap.tsxFile = RTRIM$(LTRIM$(getXMLArgString$(arg, " source=")))
        firstId = getXMLArgValue(arg, " firstgid=")
        loadTSX dir, tile(), tilemap, firstId
      CASE "map properties property":
        elementName = getXMLArgString$(arg, " name=")
        elementValue = getXMLArgValue##(arg, " value=")
        elementValueString = getXMLArgString$(arg, " value=")
        SELECT CASE elementName
          CASE "GRAVITY_X":
            world.gravity.x = elementValue
            vector2dMultiplyScalarND o, world.gravity, cDT: engine.resting = vector2dLengthSq(o) + cEPSILON
          CASE "GRAVITY_Y":
            world.gravity.y = elementValue
            vector2dMultiplyScalarND o, world.gravity, cDT: engine.resting = vector2dLengthSq(o) + cEPSILON
          CASE "CAMERA_ZOOM":
            camera.zoom = elementValue
          CASE "CAMERA_FOCUS_X":
            camera.position.x = elementValue
          CASE "CAMERA_FOCUS_Y":
            camera.position.y = elementValue
          CASE "CAMERA_AABB_X":
            camera.AABB.x = elementValue
          CASE "CAMERA_AABB_Y":
            camera.AABB.y = elementValue
          CASE "CAMERA_AABB_SIZE_X":
            camera.AABB_size.x = elementValue
          CASE "CAMERA_AABB_SIZE_Y":
            camera.AABB_size.y = elementValue
          CASE "CAMERA_MODE"
          CASE "LIGHT_MAX_DISTANCE":
            engine.mapParameters.maxLightDistance = elementValue
        END SELECT
      CASE "map layer":
        mapLayer = getXMLArgString$(arg, " name=")
      CASE "map layer data": ' Load GameMap
        elementString = getXMLArgString$(arg, "encoding=")
        IF elementString = "csv" THEN
          mapIndex = 0
        ELSE
          'Read in comma delimited gamemap data
          start = 1
          arg = RTRIM$(LTRIM$(arg))
          DO WHILE start <= LEN(arg)
            comma = INSTR(start, arg, ",")
            IF comma = 0 THEN
              IF start < LEN(arg) THEN ' catch the last value at the end of the list
                tempVal = VAL(RIGHT$(arg, LEN(arg) - start + 1))
                XMLsetGameMap gamemap(), mapIndex, mapLayer, tempVal
              END IF
              EXIT DO
            END IF
            tempVal = VAL(MID$(arg, start, comma - start))
            XMLsetGameMap gamemap(), mapIndex, mapLayer, tempVal
            start = comma + 1
          LOOP
        END IF
      CASE "map objectgroup": 'Get object group name
        objectGroupName = getXMLArgString$(arg, " name=")
      CASE "map objectgroup object": 'Get object name
        SELECT CASE objectGroupName
          CASE "Objects":
            objectType = getXMLArgString$(arg, " type=")
            SELECT CASE objectType
              CASE "PLAYER":
                objectName = getXMLArgString$(arg, " name=")
                xp = getXMLArgValue(arg, " x=") * tilemap.tilescale
                yp = getXMLArgValue(arg, " y=") * tilemap.tilescale
                vector2dSet tempVec, xp + tilemap.tileWidth, yp + tilemap.tileHeight
                tempId = entityCreate(entity(), p(), body(), tilemap, objectName, tempVec)
              CASE "SENSOR":
                objectName = getXMLArgString$(arg, " name=")
                xp = getXMLArgValue(arg, " x=") * tilemap.tilescale
                yp = getXMLArgValue(arg, " y=") * tilemap.tilescale
                xs = (getXMLArgValue(arg, " width=") * tilemap.tilescale) / 2
                ys = (getXMLArgValue(arg, " height=") * tilemap.tilescale) / 2
                tempId = createBoxBodyEx(p(), body(), objectName, xs, ys)
                setBody p(), body(), cPARAMETER_POSITION, tempId, xp + xs, yp + ys
                setBody p(), body(), cPARAMETER_ORIENT, tempId, 0, 0
                setBody p(), body(), cPARAMETER_STATIC, tempId, 1, 0
                setBody p(), body(), cPARAMETER_COLOR, tempId, _RGBA32(0, 255, 0, 255), 0
                setBody p(), body(), cPARAMETER_NOPHYSICS, tempId, 1, 0
                setBody p(), body(), cPARAMETER_SPECIALFUNCTION, tempId, 1, tempId
                'Sensors have couple of ways to trigger
                'There is the body collision and there is the image collision
                'There is a hidden image that is the same size as the gamemap
                'The hidden image is black except for the images of the sensors
                'This allows for you to detect sensor collisions with the POINT command
                'This is useful for mouse interactions with menu items
                'The color is embedded with bodyID to help sort which sensor got hit
                sensorImage = allocateTextureEX(tile(), _NEWIMAGE(64, 64, 32))
                _DEST tile(sensorImage).t
                LINE (0, 0)-(64, 64), _RGB(0, 0, tempId), BF
                _DEST 0
                setBody p(), body(), cPARAMETER_TEXTURE, tempId, tile(sensorImage).t, 0
              CASE "LANDMARK":
                objectName = getXMLArgString$(arg, " name=")
                xp = getXMLArgValue(arg, " x=") * tilemap.tilescale
                yp = getXMLArgValue(arg, " y=") * tilemap.tilescale
                landmark(UBOUND(landmark)).landmarkName = objectName
                landmark(UBOUND(landmark)).landmarkHash = computeHash&&(objectName)
                landmark(UBOUND(landmark)).position.x = xp
                landmark(UBOUND(landmark)).position.y = yp
                REDIM _PRESERVE landmark(UBOUND(landmark) + 1) AS tLANDMARK
              CASE "DOOR":
                objectName = getXMLArgString$(arg, " name=")
                xp = getXMLArgValue(arg, " x=") * tilemap.tilescale
                yp = getXMLArgValue(arg, " y=") * tilemap.tilescale
                xs = (getXMLArgValue(arg, " width=") * tilemap.tilescale) / 2
                ys = (getXMLArgValue(arg, " height=") * tilemap.tilescale) / 2
                tempId = createBoxBodyEx(p(), body(), objectID, xs, ys)
                setBody p(), body(), cPARAMETER_POSITION, tempId, xp + xs, yp + ys
                setBody p(), body(), cPARAMETER_ORIENT, tempId, 0, 0
                setBody p(), body(), cPARAMETER_STATIC, tempId, 1, 0
                setBody p(), body(), cPARAMETER_NOPHYSICS, tempId, 1, 0
                setBody p(), body(), cPARAMETER_COLOR, tempId, _RGBA32(255, 0, 0, 255), 0
                doors(UBOUND(doors)).bodyId = tempId
                doors(UBOUND(doors)).doorName = objectName
                doors(UBOUND(doors)).doorHash = computeHash&&(objectName)
                doors(UBOUND(doors)).position.x = xp
                doors(UBOUND(doors)).position.y = yp
                REDIM _PRESERVE doors(UBOUND(doors) + 1) AS tDOOR
            END SELECT
          CASE "Collision":
            objectID = getXMLArgString$(arg, " id=")
            xp = getXMLArgValue(arg, " x=") * tilemap.tilescale
            yp = getXMLArgValue(arg, " y=") * tilemap.tilescale
            xs = (getXMLArgValue(arg, " width=") * tilemap.tilescale) / 2
            ys = (getXMLArgValue(arg, " height=") * tilemap.tilescale) / 2
            tempId = createBoxBodyEx(p(), body(), objectID, xs, ys)
            setBody p(), body(), cPARAMETER_POSITION, tempId, xp + xs, yp + ys
            setBody p(), body(), cPARAMETER_ORIENT, tempId, 0, 0
            setBody p(), body(), cPARAMETER_STATIC, tempId, 1, 0
            setBody p(), body(), cPARAMETER_COLOR, tempId, _RGBA32(255, 0, 0, 255), 0
          CASE "Lights":
            xl = getXMLArgValue(arg, " x=")
            yl = getXMLArgValue(arg, " y=")
          CASE "fzxBody":
            XMLaddRigidBody p(), body(), gamemap(), tile(), tilemap, arg
        END SELECT
      CASE "map objectgroup object properties property":
        SELECT CASE objectGroupName
          CASE "Objects":
            SELECT CASE objectType
              CASE "PLAYER":
                propertyName = getXMLArgString$(arg, " name=")
                propertyValue = getXMLArgValue(arg, " value=")
                tempId = bodyManagerID(body(), objectName)
                SELECT CASE propertyName
                  CASE "TileID":
                    setBody p(), body(), cPARAMETER_TEXTURE, tempId, tile(idToTile(tile(), propertyValue + 1)).t, 0
                  CASE "MAX_FORCE_X":
                    entity(body(tempId).entityID).parameters.maxForce.x = propertyValue
                  CASE "MAX_FORCE_Y":
                    entity(body(tempId).entityID).parameters.maxForce.y = propertyValue
                  CASE "NO_PHYSICS":
                    setBody p(), body(), cPARAMETER_NOPHYSICS, tempId, propertyValue, 0
                END SELECT
              CASE "SENSOR": ' No properties
              CASE "WAYPOINT": ' No properties
              CASE "DOOR":
                propertyName = getXMLArgString$(arg, " name=")
                propertyValue = getXMLArgValue(arg, " value=")
                propertyValueString = getXMLArgString$(arg, " value=")
                SELECT CASE propertyName
                  CASE "LANDMARK":
                    doors(UBOUND(doors) - 1).landmarkHash = computeHash&&(propertyValueString)
                  CASE "MAP":
                    doors(UBOUND(doors) - 1).map = propertyValueString
                  CASE "OPEN_CLOSED_LOCKED":
                    doors(UBOUND(doors) - 1).status = propertyValue
                  CASE "TILE_CLOSED":
                    doors(UBOUND(doors) - 1).tileOpen = propertyValue
                  CASE "TILE_OPEN":
                    doors(UBOUND(doors) - 1).tileClosed = propertyValue
                END SELECT
            END SELECT
          CASE "Lights":
            elementValueString = getXMLArgString$(arg, " value=")
            elementValueString = UCASE$("&H" + RIGHT$(elementValueString, LEN(elementValueString) - INSTR(elementValueString, "#")))
            tempColor = VAL(elementValueString)
            lights(UBOUND(lights)).position.x = xl
            lights(UBOUND(lights)).position.y = yl
            lights(UBOUND(lights)).lightColor = tempColor
            REDIM _PRESERVE lights(UBOUND(lights) + 1) AS tLIGHT
        END SELECT
    END SELECT
  NEXT
  constructGameMap engine, p(), body(), gamemap(), tile(), tilemap, lights()
END SUB

SUB XMLaddRigidBody (p() AS tPOLY, body() AS tBODY, gamemap() AS tTILE, tile() AS tTILE, tilemap AS tTILEMAP, arg AS STRING)
  DIM AS STRING objectId, objectName, objectType
  DIM AS _FLOAT xp, yp, xs, ys
  DIM AS LONG tempId

  objectId = getXMLArgString$(arg, " id=")
  objectName = getXMLArgString$(arg, " name=")
  objectType = getXMLArgString$(arg, " type=")

  xp = getXMLArgValue(arg, " x=") * tilemap.tilescale
  yp = getXMLArgValue(arg, " y=") * tilemap.tilescale
  xs = (getXMLArgValue(arg, " width=") * tilemap.tilescale)
  ys = (getXMLArgValue(arg, " height=") * tilemap.tilescale)
  ' Create Ridid body
  IF objectType = "BOX" THEN
    tempId = createBoxBodyEx(p(), body(), objectName, xs / 2, ys / 2)
  ELSE IF objectType = "CIRCLE" THEN
      tempId = createCircleBodyEx(body(), objectName, xs / 2)
    END IF
  END IF
  setBody p(), body(), cPARAMETER_POSITION, tempId, xp + (xs / 2), yp + (ys / 2)
  setBody p(), body(), cPARAMETER_ORIENT, tempId, 0, 0
  setBody p(), body(), cPARAMETER_NOPHYSICS, tempId, 0, 0
  'build texture for Box
  DIM AS tTILEMAP tempLayout
  DIM AS LONG tx, ty, tileStartX, tileStartY, mapSizeX, mapSizeY, gameMapX, gameMapY, tempMapPos, gameMapPos, imgId
  tileStartX = xp / tilemap.tileWidth
  tileStartY = yp / tilemap.tileHeight
  mapSizeX = xs / tilemap.tileWidth
  mapSizeY = ys / tilemap.tileHeight
  imgId = allocateTextureEX(tile(), _NEWIMAGE(xs, ys, 32))
  DIM AS tTILE tempMAP(mapSizeX * mapSizeY)
  FOR ty = 0 TO mapSizeY - 1
    FOR tx = 0 TO mapSizeX - 1
      gameMapX = tx + tileStartX
      gameMapY = ty + tileStartY
      gameMapPos = gameMapX + (gameMapY * tilemap.mapWidth)
      tempMapPos = tx + ty * mapSizeX
      tempMAP(tempMapPos) = gamemap(gameMapPos)
    NEXT
  NEXT
  tempLayout = tilemap
  tempLayout.mapWidth = mapSizeX
  tempLayout.mapHeight = mapSizeY
  buildMultiTileMap tempMAP(), tile(), tempLayout, tile(imgId).t, 1
  setBody p(), body(), cPARAMETER_TEXTURE, tempId, tile(imgId).t, 0
END SUB

SUB XMLsetGameMap (gamemap() AS tTILE, mapindex AS LONG, mapLayer AS STRING, value AS _FLOAT)
  IF mapindex > UBOUND(gamemap) THEN REDIM _PRESERVE gamemap(mapindex) AS tTILE
  SELECT CASE mapLayer
    CASE "Tile Layer 1":
      gamemap(mapindex).t = value
    CASE "Tile Rigid Body":
      gamemap(mapindex).t0 = value
    CASE "Tile Collision":
      gamemap(mapindex).collision = value
  END SELECT
  mapindex = mapindex + 1
END SUB

FUNCTION getXMLArgValue## (i AS STRING, s AS STRING)
  DIM AS LONG sp, space
  DIM AS STRING m
  sp = INSTR(i, s)
  IF sp THEN
    sp = sp + LEN(s) + 1 ' add one for the quotes
    space = INSTR(sp + 1, i, CHR$(34)) - sp
    m = MID$(i, sp, space)
    getXMLArgValue## = VAL(m)
  END IF
END FUNCTION

FUNCTION getXMLArgString$ (i AS STRING, s AS STRING)
  DIM AS LONG sp, space
  DIM AS STRING m
  sp = INSTR(i, s)
  IF sp THEN
    sp = sp + LEN(s) + 1 ' add one for the quotes
    space = INSTR(sp + 1, i, CHR$(34)) - sp
    m = MID$(i, sp, space)
    getXMLArgString$ = RTRIM$(LTRIM$(m))
  END IF
END FUNCTION

'**********************************************************************************************
'   Stack Functions/Subs
'**********************************************************************************************
SUB _______________STACK_HANDLING (): END SUB
SUB pushStackString (stack() AS STRING, element AS STRING)
  stack(UBOUND(stack)) = element
  REDIM _PRESERVE stack(UBOUND(stack) + 1) AS STRING
END SUB

SUB popStackString (stack() AS STRING)
  IF UBOUND(stack) > 0 THEN REDIM _PRESERVE stack(UBOUND(stack) - 1) AS STRING
END SUB

FUNCTION topStackString$ (stack() AS STRING)
  IF UBOUND(stack) > 0 THEN
    topStackString$ = stack(UBOUND(stack) - 1)
  ELSE
    topStackString$ = stack(UBOUND(stack))
  END IF
END FUNCTION

SUB pushStackVector (stack() AS tVECTOR2d, element AS tVECTOR2d)
  stack(UBOUND(stack)) = element
  REDIM _PRESERVE stack(UBOUND(stack) + 1) AS tVECTOR2d
END SUB

SUB popStackVector (stack() AS tVECTOR2d)
  IF UBOUND(stack) > 0 THEN REDIM _PRESERVE stack(UBOUND(stack) - 1) AS tVECTOR2d
END SUB

SUB topStackVector (o AS tVECTOR2d, stack() AS tVECTOR2d)
  IF UBOUND(stack) > 0 THEN
    o = stack(UBOUND(stack) - 1)
  ELSE
    o = stack(UBOUND(stack))
  END IF
END SUB

SUB pushStackContextArg (stack() AS tSTRINGTUPLE, element_name AS STRING, element AS STRING)
  stack(UBOUND(stack)).contextName = element_name
  stack(UBOUND(stack)).arg = element
  REDIM _PRESERVE stack(UBOUND(stack) + 1) AS tSTRINGTUPLE
END SUB

SUB pushStackContext (stack() AS tSTRINGTUPLE, element AS tSTRINGTUPLE)
  stack(UBOUND(stack)) = element
  REDIM _PRESERVE stack(UBOUND(stack) + 1) AS tSTRINGTUPLE
END SUB

SUB popStackContext (stack() AS tSTRINGTUPLE)
  IF UBOUND(stack) > 0 THEN REDIM _PRESERVE stack(UBOUND(stack) - 1) AS tSTRINGTUPLE
END SUB

'**********************************************************************************************
'   SOUND Functions/Subs
'**********************************************************************************************
SUB _______________SOUND_HANDLING (): END SUB

SUB playMusic (playlist AS tPLAYLIST, sounds() AS tSOUND, id AS STRING)
  DIM AS LONG music
  music = soundManagerIDClass(sounds(), id)
  IF music > -1 THEN
    IF NOT _SNDPLAYING(sounds(music).handle) THEN
      IF playlist.fsm.currentState = cFSM_SOUND_IDLE THEN
        playlist.currentMusic = music
      ELSE
        playlist.nextMusic = music
      END IF
    END IF
  END IF
END SUB

SUB stopMusic (playlist AS tPLAYLIST)
  playlist.nextMusic = -1
  FSMChangeState playlist.fsm, cFSM_SOUND_LEADOUT
END SUB

SUB handleMusic (playlist AS tPLAYLIST, sounds() AS tSOUND)
  playlist.fsm.timerState.duration = 3
  SELECT CASE playlist.fsm.currentState
    CASE cFSM_SOUND_IDLE:
      IF playlist.currentMusic > -1 THEN
        FSMChangeState playlist.fsm, cFSM_SOUND_START
      END IF
    CASE cFSM_SOUND_START:
      _SNDVOL sounds(playlist.currentMusic).handle, 0
      _SNDPLAY sounds(playlist.currentMusic).handle
      _SNDLOOP sounds(playlist.currentMusic).handle
      FSMChangeState playlist.fsm, cFSM_SOUND_LEADIN
    CASE cFSM_SOUND_LEADIN:
      _SNDVOL sounds(playlist.currentMusic).handle, gameOptions.musicVolume * scalarLERPProgress##(playlist.fsm.timerState.start, playlist.fsm.timerState.start + playlist.fsm.timerState.duration)
      FSMChangeStateOnTimer playlist.fsm, cFSM_SOUND_PLAY
    CASE cFSM_SOUND_PLAY:
      IF playlist.currentMusic <> playlist.nextMusic AND playlist.nextMusic > -1 THEN
        FSMChangeState playlist.fsm, cFSM_SOUND_LEADOUT
      END IF
    CASE cFSM_SOUND_LEADOUT:
      IF playlist.currentMusic > -1 THEN
        _SNDVOL sounds(playlist.currentMusic).handle, gameOptions.musicVolume * (1 - scalarLERPProgress##(playlist.fsm.timerState.start, playlist.fsm.timerState.start + playlist.fsm.timerState.duration))
        FSMChangeStateOnTimer playlist.fsm, cFSM_SOUND_CLEANUP
      ELSE
        FSMChangeState playlist.fsm, cFSM_SOUND_CLEANUP
      END IF
    CASE cFSM_SOUND_CLEANUP:
      IF playlist.currentMusic > -1 THEN _SNDSTOP sounds(playlist.currentMusic).handle
      IF playlist.nextMusic = -1 THEN
        playlist.currentMusic = -1
        FSMChangeState playlist.fsm, cFSM_SOUND_IDLE
      ELSE
        playlist.currentMusic = playlist.nextMusic
        playlist.nextMusic = -1
        FSMChangeState playlist.fsm, cFSM_SOUND_START
      END IF
  END SELECT
END SUB

SUB addMusic (sounds() AS tSOUND, filename AS STRING, class AS STRING)
  DIM AS LONG index
  index = UBOUND(sounds)
  sounds(index).handle = _SNDOPEN(_CWD$ + "/Assets/" + filename)
  IF sounds(index).handle = 0 THEN
    PRINT "Could not open "; _CWD$ + "/Assets/" + filename
    waitkey
    SYSTEM
  END IF
  sounds(index).fileName = filename
  sounds(index).fileHash = computeHash&&(filename)
  sounds(index).class = class
  sounds(index).classHash = computeHash&&(class)
  REDIM _PRESERVE sounds(index + 1) AS tSOUND
END SUB

SUB removeAllMusic (playlist AS tPLAYLIST, sounds() AS tSOUND)
  DIM AS LONG index
  playlist.nextMusic = -1
  playlist.currentMusic = -1
  FSMChangeState playlist.fsm, cFSM_SOUND_IDLE
  FOR index = 0 TO UBOUND(sounds)
    _SNDSTOP sounds(index).handle
    _SNDCLOSE sounds(index).handle
  NEXT
  REDIM sounds(0) AS tSOUND
END SUB

FUNCTION soundManagerIDFilename (sounds() AS tSOUND, objName AS STRING)
  DIM i AS LONG
  DIM uID AS _INTEGER64
  uID = computeHash&&(RTRIM$(LTRIM$(objName)))
  soundManagerIDFilename = -1
  FOR i = 0 TO UBOUND(sounds) - 1
    IF sounds(i).fileHash = uID THEN
      soundManagerIDFilename = i
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION

FUNCTION soundManagerIDClass (sounds() AS tSOUND, objName AS STRING)
  DIM i AS LONG
  DIM uID AS _INTEGER64
  uID = computeHash&&(RTRIM$(LTRIM$(objName)))
  soundManagerIDClass = -1
  FOR i = 0 TO UBOUND(sounds)
    IF sounds(i).classHash = uID THEN
      soundManagerIDClass = i
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION


'**********************************************************************************************
'   Color Mixer Functions/Subs
'**********************************************************************************************
SUB _______________COLOR_MIXER (): END SUB
FUNCTION colorChannelMixer (colorChannelA AS _UNSIGNED _BYTE, colorChannelB AS _UNSIGNED _BYTE, amountToMix AS _FLOAT)
  DIM AS _FLOAT channelA, channelB
  channelA = colorChannelA * amountToMix
  channelB = colorChannelB * (1 - amountToMix)
  colorChannelMixer = INT(channelA + channelB)
END FUNCTION

FUNCTION colorMixer& (rgbA AS LONG, rgbB AS LONG, amountToMix AS _FLOAT)
  DIM AS _UNSIGNED _BYTE r, g, b
  r = colorChannelMixer(_RED(rgbA), _RED(rgbB), amountToMix)
  g = colorChannelMixer(_GREEN(rgbA), _GREEN(rgbB), amountToMix)
  b = colorChannelMixer(_BLUE(rgbA), _BLUE(rgbB), amountToMix)
  colorMixer = _RGB(r, g, b)
END FUNCTION

'**********************************************************************************************
'     LandMarks Functions/Subs
'**********************************************************************************************
SUB _______________LANDMARK_SUBS (): END SUB

SUB findLandmarkPosition (landmarks() AS tLANDMARK, id AS STRING, o AS tVECTOR2d)
  DIM AS LONG index
  DIM AS _INTEGER64 hash
  hash = computeHash&&(id)
  FOR index = 0 TO UBOUND(landmarks) - 1
    IF landmarks(index).landmarkHash = hash THEN
      o = landmarks(index).position
      EXIT SUB
    END IF
  NEXT
END SUB

SUB findLandmarkPositionHash (landmarks() AS tLANDMARK, hash AS _INTEGER64, o AS tVECTOR2d)
  DIM AS LONG index
  FOR index = 0 TO UBOUND(landmarks) - 1
    IF landmarks(index).landmarkHash = hash THEN
      o = landmarks(index).position
      EXIT SUB
    END IF
  NEXT
END SUB

'**********************************************************************************************
'     Door Functions/Subs
'**********************************************************************************************
SUB _______________DOOR_FUNCTION (): END SUB

FUNCTION handleDoors& (entity() AS tENTITY, body() AS tBODY, hits() AS tHIT, doors() AS tDOOR)
  DIM AS LONG index, playerid
  playerid = entityManagerID(body(), "PLAYER")
  handleDoors = -1
  FOR index = 0 TO UBOUND(doors) - 1
    IF NOT isBodyTouchingBody(hits(), entity(playerid).objectID, doors(index).bodyId) THEN
      handleDoors = index
      EXIT FUNCTION
    END IF
  NEXT
END FUNCTION


