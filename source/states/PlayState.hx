package states;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import data.*;
import data.SongData.SwagSong;
import data.chart.*;
import data.GameData.MusicBeatState;
import gameObjects.*;
import gameObjects.hud.*;
import gameObjects.hud.note.*;
import subStates.*;

class PlayState extends MusicBeatState
{
	public var song:FlxSound;

	// song stuff
	public static var SONG:SwagSong;
	public var inst:FlxSound;
	public var vocals:FlxSound;

	// 
	public static var assetModifier:String = "base";
	public static var health:Float = 1;
	// score, misses, accuracy and other stuff
	// are on the Timings.hx class!!

	// objects
	public var stageBuild:Stage;

	public var characters:Array<Character> = [];
	public var dad:Character;
	public var boyfriend:Character;

	// strumlines
	public var strumlines:FlxTypedGroup<Strumline>;
	public var bfStrumline:Strumline;
	public var dadStrumline:Strumline;

	// hud
	public var hudBuild:HudClass;

	// cameras!!
	public var camGame:FlxCamera;
	public var camHUD:FlxCamera;
	public static var defaultCamZoom:Float = 1.0;

	public var camFollow:FlxObject = new FlxObject();

	public function resetStatics()
	{
		health = 1;
		defaultCamZoom = 1.0;
		assetModifier = "base";
		Timings.init();
	}

	override public function create()
	{
		super.create();
		resetStatics();

		if(SONG == null)
			SONG = SongData.loadFromJson("ugh_fnf");

		Conductor.setBPM(SONG.bpm);
		Conductor.mapBPMChanges(SONG);

		// setting up the cameras
		camGame = new FlxCamera();
		
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		// adding the cameras
		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD, false);

		// default camera
		FlxG.cameras.setDefaultDrawTarget(camGame, true);

		//camGame.zoom = 0.6;

		stageBuild = new Stage();
		stageBuild.reloadStage("stage");
		add(stageBuild);

		camGame.zoom = defaultCamZoom;

		dad = new Character();
		dad.reloadChar(SONG.player2, false);
		dad.setPosition(50, 700);
		dad.y -= dad.height;

		boyfriend = new Character();
		boyfriend.reloadChar(SONG.player1, true);
		boyfriend.setPosition(850, 700);
		boyfriend.y -= boyfriend.height;

		characters.push(dad);
		characters.push(boyfriend);

		var addList:Array<FlxBasic> = [dad, boyfriend];

		for(item in addList)
			add(item);

		followCamera(dad);

		FlxG.camera.follow(camFollow, LOCKON, 1);
		FlxG.camera.focusOn(camFollow.getPosition());

		hudBuild = new HudClass();
		hudBuild.cameras = [camHUD];
		add(hudBuild);

		// strumlines
		strumlines = new FlxTypedGroup();
		strumlines.cameras = [camHUD];
		add(strumlines);

		//strumline.scrollSpeed = 4.0; // 2.8
		var daStrumSize:Array<Float> = [FlxG.width / 2, FlxG.width / 4];

		dadStrumline = new Strumline(daStrumSize[0] - daStrumSize[1], dad, false, false, true);
		dadStrumline.ID = 0;
		strumlines.add(dadStrumline);

		//dadStrumline.scrollSpeed = 3.4;

		bfStrumline = new Strumline(daStrumSize[0] + daStrumSize[1], boyfriend, false, true, false);
		bfStrumline.ID = 1;
		strumlines.add(bfStrumline);

		hudBuild.updateHitbox(bfStrumline.downscroll);

		var daSong:String = SONG.song.toLowerCase() + "_fnf";

		song = new FlxSound();
		song.loadEmbedded(Paths.song(daSong + "/song"), false, false);
		FlxG.sound.list.add(song);

		//Conductor.setBPM(160);
		Conductor.songPos = 0;

		var unspawnNotes:Array<Note> = ChartLoader.getChart(SONG);

		for(note in unspawnNotes)
		{
			var thisStrumline = dadStrumline;
			for(strumline in strumlines)
			{
				if(note.strumlineID == strumline.ID)
					thisStrumline = strumline;
			}

			var direc = NoteUtil.getDirection(note.noteData);
			var thisStrum = thisStrumline.strumGroup.members[note.noteData];
			var thisChar = thisStrumline.character;

			note.onHit = function()
			{
				// when the player hits notes
				if(thisStrumline.isPlayer)
				{
					popUpRating(note, false);
				}

				note.gotHit = true;
				note.checkActive();
				//note.alpha = 0;

				if(!note.isHold)
					thisStrum.playAnim("confirm");

				if(thisChar != null && !note.isHold)
				{
					thisChar.playAnim('sing' + direc.toUpperCase(), true);
					thisChar.holdTimer = 0;

					if(note.noteType != 'default')
						thisChar.playAnim('hey');
				}
			};
			note.onMiss = function()
			{
				note.gotHit = false;
				note.canHit = false;
				note.alpha = 0.1;

				if(thisChar != null)
				{
					thisChar.playAnim('sing' + direc.toUpperCase() + 'miss', true);
					thisChar.holdTimer = 0;
				}

				// when the player misses notes
				if(thisStrumline.isPlayer)
				{
					popUpRating(note, true);
				}
			};
			// only works on long notes!!
			note.onHold = function()
			{
				note.gotHit = true;

				// if not finished
				if(note.holdHitLength < note.holdLength - Conductor.stepCrochet)
				{
					thisStrum.playAnim("confirm");

					thisChar.playAnim('sing' + direc.toUpperCase(), true);
					thisChar.holdTimer = 0;
				}
			}

			thisStrumline.addNote(note);
		}

		//trace("where is it");
		startSong();
	}

	override function openSubState(state:FlxSubState)
	{
		super.openSubState(state);
		if(song != null)
		{
			song.pause();
		}
	}

	override function closeSubState()
	{
		super.closeSubState();
		if(song != null)
		{
			song.play();
		}
	}

	public function popUpRating(note:Note, miss:Bool = false)
	{
		var noteDiff:Float = Math.abs(note.songTime - Conductor.songPos);
		if(note.isHold && !miss)
			noteDiff = 0;

		var judge:Float = Timings.diffToJudge(noteDiff);
		if(miss)
			judge = Timings.timingsMap.get('miss')[1];

		// handling stuff
		health += 0.05 * judge;
		Timings.score += Math.floor(100 * judge);
		Timings.addAccuracy(judge);

		if(miss)
		{
			Timings.misses++;
		}
		else
		{
			if(judge <= Timings.timingsMap.get('shit')[1])
				note.onMiss();
		}

		hudBuild.updateText();
	}

	public function startSong()
	{
		song.stop();
		song.play();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
		camGame.followLerp = elapsed * 3;

		if(FlxG.keys.justPressed.ENTER)
		{
			/*if(song.playing)
				song.pause();
			else
				song.play();*/
			openSubState(new PauseSubState());
		}

		if(FlxG.keys.justPressed.ESCAPE)
			Main.switchState(new MenuState());

		if(FlxG.keys.justPressed.R)
			health = 0;

		if(FlxG.keys.justPressed.SPACE)
		{
			for(strumline in strumlines.members)
			{
				strumline.downscroll = !strumline.downscroll;
				strumline.updateHitbox();
			}
			hudBuild.updateHitbox(bfStrumline.downscroll);
		}

		//strumline.scrollSpeed = 2.8 + Math.sin(FlxG.game.ticks / 500) * 1.5;

		if(song.playing)
			Conductor.songPos = song.time;

		var pressed:Array<Bool> = [
			controls.pressed("LEFT"),
			controls.pressed("DOWN"),
			controls.pressed("UP"),
			controls.pressed("RIGHT")
		];
		var justPressed:Array<Bool> = [
			controls.justPressed("LEFT"),
			controls.justPressed("DOWN"),
			controls.justPressed("UP"),
			controls.justPressed("RIGHT")
		];
		var released:Array<Bool> = [
			controls.released("LEFT"),
			controls.released("DOWN"),
			controls.released("UP"),
			controls.released("RIGHT")
		];

		// strumline handler!!
		for(strumline in strumlines.members)
		{
			for(strum in strumline.strumGroup)
			{
				if(strumline.isPlayer && !strumline.botplay)
				{
					if(pressed[strum.strumData])
					{
						if(!["pressed", "confirm"].contains(strum.animation.curAnim.name))
							strum.playAnim("pressed");
					}
					else
						strum.playAnim("static");
				}
				else
				{
					if(strum.animation.curAnim.name == "confirm"
					&& strum.animation.curAnim.finished)
						strum.playAnim("static");
				}
			}

			var canHitNotes:Array<Note> = [];

			/* since all the notes are loaded at once
			** use note.active to get specific notes
			** so the game doesn't lag*/
			for(note in strumline.allNotes)
			{
				note.checkActive();
			}

			for(note in strumline.noteGroup)
			{
				if(!note.active) continue;

				var downMult:Int = (strumline.downscroll ? -1 : 1);
				var thisStrum = strumline.strumGroup.members[note.noteData];

				note.x = thisStrum.x + note.noteOffset.x;
				note.y = thisStrum.y + (thisStrum.height / 12 * downMult) + (note.noteOffset.y * downMult);

				/*note.scale.set(
					1 + Math.sin(FlxG.game.ticks / 64) * 0.3,
					1 - Math.sin(FlxG.game.ticks / 64) * 0.3
				);*/
				//note.angle = flixel.math.FlxMath.lerp(note.angle, FlxG.random.int(-360, 360), elapsed * 8);

				note.y += downMult * ((note.songTime - Conductor.songPos) * (strumline.scrollSpeed * 0.45));

				//note.canHit = true;
				if(-(note.songTime - Conductor.songPos) >= Timings.timingsMap.get("good")[0] && !note.gotHit && note.canHit)
				{
					note.onMiss();
				}

				if(Math.abs(note.songTime - Conductor.songPos) <= Timings.minTiming)
				{
					if(canHitNotes[note.noteData] == null && note.canHit && !note.gotHit)
						canHitNotes[note.noteData] = note;
				}

				if(strumline.botplay)
				{
					if(note.songTime - Conductor.songPos <= 0 && !note.gotHit)
						note.onHit();
				}
			}

			for(hold in strumline.holdGroup)
			{
				if(!hold.active) continue;

				var downMult:Int = (strumline.downscroll ? -1 : 1);

				if(hold.scrollSpeed != strumline.scrollSpeed)
				{
					hold.scrollSpeed = strumline.scrollSpeed;

					if(!hold.isHoldEnd)
					{
						var newHoldSize:Array<Float> = [
							hold.frameWidth * hold.scale.x,
							(hold.holdLength - (Conductor.stepCrochet / 2)) * (strumline.scrollSpeed * 0.45)
						];

						hold.setGraphicSize(
							Math.floor(newHoldSize[0]),
							Math.floor(newHoldSize[1])
						);
					}

					hold.updateHitbox();
				}

				hold.flipY = strumline.downscroll;

				if(hold.parentNote != null)
				{
					var thisStrum = strumline.strumGroup.members[hold.noteData];
					var holdParent = hold.parentNote;

					if(!hold.isHoldEnd)
					{
						hold.x = (holdParent.x + holdParent.width / 2 - hold.width / 2) + hold.noteOffset.x;
						hold.y = holdParent.y + holdParent.height / 2;
					}
					else
					{
						hold.x = holdParent.x;
						hold.y = holdParent.y + (strumline.downscroll ? 0 : holdParent.height) + (-downMult * 0.5);
					}

					if(strumline.downscroll)
						hold.y -= hold.height;

					// input!!
					if(!holdParent.canHit && hold.canHit)
						hold.onMiss();

					var pressedCheck:Bool = (pressed[hold.noteData] && holdParent.gotHit && hold.canHit);

					if(!strumline.isPlayer || strumline.botplay)
						pressedCheck = (holdParent.gotHit && hold.canHit);

					if(hold.isHoldEnd)
						pressedCheck = (holdParent.gotHit && holdParent.canHit);

					if(pressedCheck)
					{
						hold.holdHitLength = Conductor.songPos - hold.songTime;
						//trace('${hold.holdHitLength} / ${hold.holdLength}');
						
						var daRect = new FlxRect(
							0,
							0,
							hold.frameWidth,
							hold.frameHeight
						);

						var center:Float = (thisStrum.y + thisStrum.height / 2);

						if(!strumline.downscroll)
						{
							if(hold.y < center)
								daRect.y = (center - hold.y) / hold.scale.y;
						}
						else
						{
							if(hold.y + hold.height > center)
								daRect.y = ((hold.y + hold.height) - center) / hold.scale.y;
						}

						hold.clipRect = daRect;

						hold.onHold();
					}

					if(strumline.isPlayer && !strumline.botplay)
					{
						if(released.contains(true))
						{					
							if(released[hold.noteData] && hold.canHit && holdParent.gotHit && !hold.isHoldEnd)
							{
								thisStrum.playAnim("static");

								if(hold.holdHitLength >= hold.holdLength - Conductor.stepCrochet)
								{
									hold.onHit();
								}
								else
									hold.onMiss();
							}
						}
					}
					else
					{
						if(holdParent.gotHit && !hold.isHoldEnd)
						{
							if(hold.holdHitLength >= hold.holdLength - Conductor.stepCrochet)
								hold.onHit();
							else
							{
								hold.onHold();
								thisStrum.playAnim("confirm");
							}
						}
					}
				}
			}

			if(strumline.isPlayer && !strumline.botplay)
			{
				if(justPressed.contains(true))
				{
					for(i in 0...canHitNotes.length)
					{
						if(canHitNotes[i] != null)
						{
							var note = canHitNotes[i];

							if(justPressed[i])
							{
								canHitNotes.remove(note);
								note.onHit();
							}
						}
					}
				}
			}

			// dumb stuff!!!
			if(SONG.song.toLowerCase() == "disruption")
			{
				for(strum in strumline.strumGroup)
				{
					var daTime:Float = (FlxG.game.ticks / 1000);

					var strumMult:Int = (strum.strumData % 2 == 0) ? 1 : -1;

					strum.x = strum.initialPos.x + Math.sin(daTime) * 20 * strumMult;
					strum.y = strum.initialPos.y + Math.cos(daTime) * 20 * strumMult;

					strum.scale.x = strum.strumSize + Math.sin(daTime) * 0.4;
					strum.scale.y = strum.strumSize - Math.sin(daTime) * 0.4;

					//strum.x -= strum.scaleOffset.x / 2;
				}
				for(note in strumline.allNotes)
				{
					if(!note.active) continue;

					var thisStrum = strumline.strumGroup.members[note.noteData];

					note.scale.x = thisStrum.scale.x;
					if(!note.isHold)
						note.scale.y = thisStrum.scale.y;
				}
			}
		}

		var curSection = PlayState.SONG.notes[Std.int(curStep / 16)];
		if(curSection != null)
		{
			if(curSection.mustHitSection)
				followCamera(boyfriend);
			else
				followCamera(dad);
		}

		if(health <= 0)
		{
			persistentDraw = false;
			openSubState(new GameOverSubState(boyfriend));
		}

		camGame.zoom = FlxMath.lerp(camGame.zoom, defaultCamZoom, elapsed * 6);
		camHUD.zoom  = FlxMath.lerp(camHUD.zoom,  1.0, elapsed * 6);

		health = FlxMath.bound(health, 0, 2); // bounds the health
	}

	public function followCamera(?char:Character, ?offsetX:Float = 0, ?offsetY:Float = 0)
	{
		camFollow.setPosition(0,0);

		if(char != null)
		{
			var playerMult:Int = char.isPlayer ? -1 : 1;

			camFollow.setPosition(char.getMidpoint().x + (200 * playerMult), char.getMidpoint().y - 20);
		}

		camFollow.x += offsetX;
		camFollow.y += offsetY;
	}

	override function beatHit()
	{
		super.beatHit();
		hudBuild.beatHit(curBeat);

		if(curBeat % 4 == 0)
		{
			camGame.zoom += 0.05;
			camHUD.zoom += 0.025;
		}
		if(curBeat % 2 == 0)
		{
			for(char in characters)
			{
				var canIdle = (char.holdTimer >= char.holdLength);

				/*if(char.isPlayer)
				{
					if(pressed.contains(true))
						canIdle = false;
				}*/

				if(canIdle)
					char.dance();
			}
		}
	}
}