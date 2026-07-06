using System;
using System.Collections.Generic;
using System.Reflection;
using System.Threading;
using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;
using MonoMod;
using Paris.Engine;
using Paris.Engine.Helper;
using Paris.Engine.Input;
using Paris.Engine.Localisation;
using Paris.Engine.Leaderboards;
using Paris.Engine.Stats;

namespace Paris.Engine.Context
{
	// Boot deadlock + blank sprites, both rooted in the same thing.
	//
	// FNA moved GL resource creation into native FNA3D: a worker-thread
	// FNA3D_CreateTexture2D / CreateEffect is queued (ForceToMainThread) and
	// only runs when the main thread next drains the queue, inside SwapBuffers.
	// Stock ParisEngine preloads global assets on background worker threads, so
	// during boot those GL calls pile up behind a Present that the loading state
	// suppresses: a preloader parks in the queued call holding an engine lock and
	// boot deadlocks. And because the texture upload runs (or would run) in a
	// worker's GL context, on Panfrost/GLES the main context can't sample it -
	// the portraits came up blank even when it didn't hang. Neither bit Vulkan or
	// D3D11 (they don't marshal), which is why upstream never saw it.
	//
	// Fix: mirror the TMNT: Shredder's Revenge port's split (which runs on the
	// H700). The non-GL work - audio, json, reflection, AND pool objects (pool
	// objects carry no texture data) - stays on background threads. The GL-
	// creating work runs synchronously on the main/render thread so the textures
	// are created directly in the main GL context (no worker marshaling, so no
	// queued-command deadlock and no pump/drain plumbing; and the sprites live in
	// the context that samples them). Keeping PreloadPoolObjects on a background
	// thread (rather than pulling it onto main) keeps the synchronous burst small
	// enough to fit low-memory devices - pulling it on OOM-hardlocked a Mali GPU.
	//
	// The GL work is split across two patches because MCI's structure differs
	// from TMNT's:
	//   - LoadGlobalContent runs here (main), in StartPreLoadingGlobalAssets.
	//   - The IPreloadable loop (AttackListPreload etc., the portraits) runs in
	//     the Game.exe StartInit patch instead. Those preloaders spin-wait on
	//     game-side lists (AttackList/SpawnSequenceList/CharacterManager) which,
	//     in MCI, live in Game.exe and load only later in Paris.StartInit - so
	//     they cannot run here without deadlocking. Game.exe runs them after the
	//     lists load, then calls MCI_FinishPreload() below. (In TMNT those lists
	//     were in ParisEngine, so Johnny could do it all in one patch.)
	//
	// CacheJsonFiles MUST stay on a background thread: PreloadPoolObjects and
	// LoadGlobalContent both spin-wait on its JsonFiles bit, so running it inline
	// would livelock.
	class patch_ContextManager : ContextManager
	{
		private volatile ContextManager.PreloadingState _preloadingState;
		private List<Thread> mGlobalLoadingThreads;

		public patch_ContextManager(Game game) : base(game) { }

		[MonoModReplace]
		public void StartPreLoadingGlobalAssets()
		{
			if (this.EditorMode || this._preloadingState != ContextManager.PreloadingState.Nothing)
			{
				return;
			}
			// No texture data, so these are safe to load in parallel on background
			// threads - PreloadPoolObjects included (pool objects carry no GL data).
			// This is exactly the TMNT: Shredder's Revenge port's split, which runs
			// on the H700. CacheJsonFiles MUST stay here: PreloadPoolObjects and
			// LoadGlobalContent both spin-wait on the JsonFiles bit it sets.
			foreach (Action action in new Action[]
			{
				new Action(this.PreloadAudio),
				new Action(this.CacheJsonFiles),
				new Action(this.CacheReflectionInfo),
				new Action(this.PreloadPoolObjects)
			})
			{
				Thread thread = new Thread(new ThreadStart(action.Invoke));
				thread.Priority = ThreadPriority.BelowNormal;
				thread.IsBackground = true;
				thread.Name = string.Format("Preload : {0}", action.Method.Name);
				this.mGlobalLoadingThreads.Add(thread);
				thread.Start();
			}
			// Global content creates GL, so it runs on the main/render thread -
			// created directly in the main context, no worker marshaling.
			this.LoadGlobalContent();
			// The IPreloadable loop (AttackListPreload etc.) is deliberately NOT
			// run here. Those preloaders spin-wait on game-side lists
			// (AttackList/SpawnSequenceList/CharacterManager), which in MCI live in
			// Game.exe and only load later in Paris.StartInit - unreachable from
			// this ParisEngine patch. Running them here on the main thread would
			// deadlock waiting for a list that can't load until this returns. The
			// Game.exe StartInit patch runs them (and calls MCI_FinishPreload)
			// once those lists are up. See Game.MCIPatches.mm.cs.
		}

		// Bridge for the Game.exe StartInit patch: it runs the IPreloadables on
		// the main thread after the game-side lists have loaded, then calls this
		// to mark preload complete. Lives here because _preloadingState is private
		// to ContextManager. Forcing Finished (as TMNT does) also guarantees
		// WaitUntilPoolManagerIsInitialized completes if a background cache thread
		// is still winding down.
		public void MCI_FinishPreload()
		{
			this._preloadingState = ContextManager.PreloadingState.Finished;
		}
	}
}

namespace Paris.Engine.Cutscenes
{
	// The stock intro movie (Content/Videos/MCI_IntroAnimation.ogv) is a ~147 MB
	// Theora file; FNA decodes Theora in software, so it crawls on weak GPUs/CPUs.
	// The first-run patchscript can transcode it to a half-resolution PATCH_
	// sibling (smooth), or, if the player opts to skip the intro, drop a tiny stub
	// PATCH_ file in its place (a near-instant blip) - matching the TMNT: Shredder's
	// Revenge port. Here we redirect VideoContext to that PATCH_ sibling when it
	// exists. We fall back to the original path if it does not, because
	// ParisContentManager.Load throws on a missing file - so this must never point
	// the player at a video that is not on disk.
	class patch_VideoContext : VideoContext
	{
		public extern void orig_Init();
		public override void Init()
		{
			string p = VideoContext.VideoPath;
			if (!string.IsNullOrEmpty(p))
			{
				int slash = p.LastIndexOfAny(new char[] { '\\', '/' });
				string patched = (slash < 0)
					? "PATCH_" + p
					: p.Substring(0, slash + 1) + "PATCH_" + p.Substring(slash + 1);
				try
				{
					string rel = patched.Replace('\\', System.IO.Path.DirectorySeparatorChar)
										 .Replace('/', System.IO.Path.DirectorySeparatorChar);
					string file = System.IO.Path.Combine(
						System.AppDomain.CurrentDomain.BaseDirectory, "Content", rel + ".ogv");
					if (System.IO.File.Exists(file))
					{
						VideoContext.VideoPath = patched;
					}
				}
				catch (Exception)
				{
				}
			}
			orig_Init();
		}
	}
}

namespace Paris.Engine.Input
{
	// Setting _disabled = true makes Ready true WITHOUT _initialized,
	// so every input read falls through to the native FNA GamePad path
	// (the Steam Input path never initializes when Steam is stubbed).
	class patch_InputManager : InputManager
	{
		private bool _disabled; // mapped by MonoMod onto InputManager._disabled
		public extern void orig_Init();
		public override void Init()
		{
			orig_Init();
			if (!SteamHelper.Initialized)
			{
				this._disabled = true;
			}
		}
	}

	// Force Nintendo-style button glyphs.
	class patch_InputManagerBase : InputManagerBase
	{
		public extern GamePadButtonType orig_GetButtonType(ParisInputType i_controllerType);
		public new GamePadButtonType GetButtonType(ParisInputType i_controllerType)
		{
			if (InputManagerBase.IsInputTypeController(i_controllerType))
			{
				return GamePadButtonType.SWITCH_PRO;
			}
			return orig_GetButtonType(i_controllerType);
		}
	}
}

namespace Paris.Engine.Audio
{
	// FMOD sample-data reclamation.
	//
	// MCI's AudioManager pre-creates one live FMOD EventInstance for EVERY event
	// across all four banks (Master/MUS/SFX/SFX_DLC01) at startup and never
	// releases any (SoundEventInstance.Init -> Description.createInstance; there is
	// no release()/unloadSampleData anywhere in the engine). FMOD Studio keeps a
	// sound's sample data resident while any instance references it, so with one
	// permanent instance per event the resident audio set only ever grows -
	// converging toward the whole ~131 MB SFX bank pinned in anonymous process
	// heap. On a ~1 GB device that heap can't be evicted, only swapped, so it walks
	// straight into thrash/lockup as more unique sounds fire over a session (the
	// "plays fine a while, then hard-locks and the audio cuts out last").
	//
	// Fix: once a non-music sound has been STOPPED for MCI_GRACE seconds, release
	// its FMOD instance - dropping the sample-data reference so FMOD unloads it on
	// the next Studio update - and lazily recreate the instance on the next Play.
	// Sounds replayed within the grace window keep their instance, so hot combat
	// SFX never churn; sounds that go quiet get reclaimed. This bounds the resident
	// SFX/VO set to "recently active" rather than "everything ever played", the way
	// a well-behaved FMOD title (e.g. the TMNT: Shredder's Revenge port, same FMOD
	// 2.02) lets sample data unload. Music (one song plays at a time) is untouched.
	//
	// Play/Tick are non-virtual and are always called through SoundEventInstance
	// references (AudioManager's List<SoundEventInstance>), so these patches also
	// cover the GameSoundEventInstance subclass. GameSoundEventInstance.Init only
	// adds VO name parsing (no FMOD-instance state), so recreating the bare
	// instance here is complete. NOTE: this adds instance fields to
	// SoundEventInstance, so Game.exe (which holds the GameSoundEventInstance
	// subclass) MUST be re-AOT'd alongside ParisEngine or the AOT field offsets
	// mismatch - the patchscript already AOTs both. FMOD types are fully qualified
	// to avoid pulling FMOD.System into scope alongside System.
	class patch_SoundEventInstance : SoundEventInstance
	{
		private FMOD.Studio.EventInstance _instance;
		private int _soundEventID;
		private FMOD.Studio.EVENT_CALLBACK _eventCallback;

		// Added by MonoMod onto SoundEventInstance.
		private bool mci_released;
		private float mci_idle;

		private const float MCI_GRACE = 10f;

		public patch_SoundEventInstance(int soundEventID) : base(soundEventID) { }

		public extern void orig_Tick(float deltaTime, bool frameChanged);
		public new void Tick(float deltaTime, bool frameChanged)
		{
			orig_Tick(deltaTime, frameChanged);
			if (this.IsMusic || this.mci_released)
			{
				return;
			}
			FMOD.Studio.PLAYBACK_STATE st;
			if (this._instance.getPlaybackState(out st) == FMOD.RESULT.OK
				&& st == FMOD.Studio.PLAYBACK_STATE.STOPPED)
			{
				this.mci_idle += deltaTime;
				if (this.mci_idle >= MCI_GRACE)
				{
					this._instance.release();
					this.mci_released = true;
				}
			}
			else
			{
				this.mci_idle = 0f;
			}
		}

		public extern void orig_Play();
		public new void Play()
		{
			if (this.mci_released)
			{
				this.Description.createInstance(out this._instance);
				this._instance.setUserData((IntPtr)this._soundEventID);
				this._instance.setCallback(this._eventCallback,
					FMOD.Studio.EVENT_CALLBACK_TYPE.STOPPED | FMOD.Studio.EVENT_CALLBACK_TYPE.TIMELINE_MARKER);
				this.mci_released = false;
			}
			this.mci_idle = 0f;
			orig_Play();
		}
	}
}

namespace Paris.Engine.Stats
{
	// Steam is stubbed; never push stats through it (avoids story-mode crashes).
	public class patch_Stat : Stat
	{
		patch_Stat(string id, StatType type) : base(id, type) { }
		private bool StoreSteam()
		{
			return false;
		}
	}

	// No analytics without Steam/network.
	class patch_GameAnalytics : GameAnalytics
	{
		public new void Init()
		{
			// disabled
		}
	}
}

namespace Paris.Engine.Networking
{
	// Offline: neutralise the online lobby/disconnect paths that crash without Steam.
	class patch_NetworkManager : NetworkManager
	{
		public new void Disconnect(bool transition = false)
		{
		}

		public new void ChangeLobbyLocked(bool isLocked)
		{
		}
	}
}

// Offline: leaderboards never initialise (constructor becomes a no-op).
[MonoModPatch("Paris.Engine.Leaderboards.Leaderboard")]
public class patch_Leaderboard
{
	[MonoModConstructor]
	public patch_Leaderboard(LocID name, string key, LeaderboardBase.SortMode sortMode, LeaderboardBase.DisplayType displayType)
	{
	}
}
