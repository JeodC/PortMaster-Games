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
			// No texture data, so these are safe to load in parallel on background threads
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
		}

		// Bridge for the Game.exe StartInit patch
		public void MCI_FinishPreload()
		{
			this._preloadingState = ContextManager.PreloadingState.Finished;
		}
	}
}

namespace Paris.Engine.Cutscenes
{
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
	class patch_InputManager : InputManager
	{
		private bool _disabled;
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
	class patch_SoundEventInstance : SoundEventInstance
	{
		private FMOD.Studio.EventInstance _instance;
		private int _soundEventID;
		private FMOD.Studio.EVENT_CALLBACK _eventCallback;

		// Added by MonoMod onto SoundEventInstance.
		private bool mci_released;
		private float mci_idle;

		private const float MCI_GRACE = 10f; // Tunable

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
	// Steam is stubbed; never push stats through it.
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
	// Offline: neutralize the online lobby/disconnect paths that crash without Steam.
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

// Offline: leaderboards never initialise.
[MonoModPatch("Paris.Engine.Leaderboards.Leaderboard")]
public class patch_Leaderboard
{
	[MonoModConstructor]
	public patch_Leaderboard(LocID name, string key, LeaderboardBase.SortMode sortMode, LeaderboardBase.DisplayType displayType)
	{
	}
}
