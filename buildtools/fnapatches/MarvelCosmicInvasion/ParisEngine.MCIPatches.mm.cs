using System;
using System.Collections.Generic;
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

// Split asset preloading so GL work stays on the main thread
// Stock marshals it through workers, which deadlocks under GLES
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

// Redirect the intro video to the compressed version
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
				string rel = patched.Replace('\\', System.IO.Path.DirectorySeparatorChar)
									 .Replace('/', System.IO.Path.DirectorySeparatorChar);
				string file = System.IO.Path.Combine(
					System.AppDomain.CurrentDomain.BaseDirectory, "Content", rel + ".ogv");
				if (System.IO.File.Exists(file))
				{
					VideoContext.VideoPath = patched;
				}
			}
			orig_Init();
		}
	}
}

// Disable Steam Input so the game can see the controller
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

	// Force Nintendo-style button glyphs
	// This gets around some firmwares that use a PSX controller id
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
	class patch_SoundEventInstance : SoundEventInstance
	{
		private FMOD.Studio.EventInstance _instance;
		private int _soundEventID;
		private FMOD.Studio.EVENT_CALLBACK _eventCallback;

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

// Halt stats reporting since Steam is stubbed
namespace Paris.Engine.Stats
{
	public class patch_Stat : Stat
	{
		patch_Stat(string id, StatType type) : base(id, type) { }
		private bool StoreSteam()
		{
			return false;
		}
	}
	class patch_GameAnalytics : GameAnalytics
	{
		public new void Init()
		{
			// disabled
		}
	}
}

// Halt networking, EOSSDK is stubbed
namespace Paris.Engine.Networking
{
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

// Halt EpicHelper, EOSSDK is stubbed
namespace Paris.Engine
{
	[MonoModPatch("Paris.Engine.EpicHelper")]
	static class patch_EpicHelper
	{
		[MonoModReplace]
		public static void Init()
		{
		}
	}
}

// Mono 6.12 LLVM AOT miscompiles Vector3.CatmullRom/Hermite, 
// so recompute in scalar double
namespace Paris.Engine.Effects
{
	class patch_SplinePositionTween : SplinePositionTween
	{
		[MonoModReplace]
		public new void Tick(float deltaTime)
		{
			this._timer += deltaTime;
			this._progress = (this._duration != 0f) ? MCIClamp(this._timer / this._duration, 0f, 1f) : 1f;
			float t = this._progress;
			if ((int)this._splineType == 0) // CatmullRom
			{
				this._position = new Vector3(
					MCICatmull(this._curveControl.X, this._curveStart.X, this._curveEnd.X, this._curveControl.X, t),
					MCICatmull(this._curveControl.Y, this._curveStart.Y, this._curveEnd.Y, this._curveControl.Y, t),
					MCICatmull(this._curveControl.Z, this._curveStart.Z, this._curveEnd.Z, this._curveControl.Z, t));
				return;
			}
			this._position = new Vector3(
				MCIHermite(this._curveStart.X, this._tangentStart.X, this._curveEnd.X, this._tangentEnd.X, t),
				MCIHermite(this._curveStart.Y, this._tangentStart.Y, this._curveEnd.Y, this._tangentEnd.Y, t),
				MCIHermite(this._curveStart.Z, this._tangentStart.Z, this._curveEnd.Z, this._tangentEnd.Z, t));
		}

		private static float MCIClamp(float v, float lo, float hi)
		{
			return (v < lo) ? lo : ((v > hi) ? hi : v);
		}

		private static float MCICatmull(float v1, float v2, float v3, float v4, float a)
		{
			double num = (double)a * a;
			double num2 = (double)a * num;
			return (float)(0.5 * (2.0 * v2 + (-(double)v1 + v3) * a + (2.0 * v1 - 5.0 * v2 + 4.0 * v3 - v4) * num + (-(double)v1 + 3.0 * v2 - 3.0 * v3 + v4) * num2));
		}

		private static float MCIHermite(float v1, float t1, float v2, float t2, float a)
		{
			double num2 = (double)a * a;
			double num3 = (double)a * num2;
			double n4 = 2.0 * num3 - 3.0 * num2 + 1.0;
			double n5 = -2.0 * num3 + 3.0 * num2;
			double n6 = num3 - 2.0 * num2 + a;
			double n7 = num3 - num2;
			return (float)((double)v1 * n4 + (double)v2 * n5 + (double)t1 * n6 + (double)t2 * n7);
		}
	}
}

[MonoModPatch("Paris.Engine.Leaderboards.Leaderboard")]
public class patch_Leaderboard
{
	[MonoModConstructor]
	public patch_Leaderboard(LocID name, string key, LeaderboardBase.SortMode sortMode, LeaderboardBase.DisplayType displayType)
	{
	}
}

// The CRT filter's phosphor mask degenerates below 3x display scale
// Clamp it
namespace Paris.Engine.Graphics.Shaders
{
	class patch_CRTShader : CRTShader
	{
		public patch_CRTShader(string path) : base(path) { }

		public extern void orig_ApplyData(Renderer renderer, CRTShaderData data);
		public override void ApplyData(Renderer renderer, CRTShaderData data)
		{
			if (data.GameScale < 3f)
			{
				data.GameScale = 3f;
			}
			orig_ApplyData(renderer, data);
		}
	}
}

// Grow exhausted pools by one object on demand
// The stock path builds a 20% batch inline mid-frame, stalling heavy scenes
namespace Paris.Engine.Scene
{
	class patch_GameObjectPoolManager : GameObjectPoolManager
	{
		public extern GameObject2d orig_SpawnObject(string actorTemplate, Vector3 position, Guid forceGuid, bool sendToNetwork, bool reliable, bool global, int indexAuthority);
		public new GameObject2d SpawnObject(string actorTemplate, Vector3 position, Guid forceGuid, bool sendToNetwork, bool reliable, bool global = true, int indexAuthority = -1)
		{
			if (!Paris.Engine.Context.ContextManager.Singleton.EditorMode)
			{
				this.MCI_EnsureAvailable(actorTemplate, forceGuid, global);
			}
			return this.orig_SpawnObject(actorTemplate, position, forceGuid, sendToNetwork, reliable, global, indexAuthority);
		}

		private void MCI_EnsureAvailable(string actorTemplate, Guid forceGuid, bool global)
		{
			bool needOne = true;
			int count = 0;
			Monitor.Enter(this._lock);
			List<Paris.Engine.Graphics.Playfield.GameObjectData> list;
			if (this._pools.TryGetValue(actorTemplate, out list))
			{
				count = list.Count;
				foreach (Paris.Engine.Graphics.Playfield.GameObjectData d in list)
				{
					// A disposed object satisfies the spawn; so does a live
					// object already carrying the forced guid (stock reuses it)
					if (d.GameObject.Disposed || (forceGuid != Guid.Empty && d.GameObject.Id == forceGuid))
					{
						needOne = false;
						break;
					}
				}
			}
			Monitor.Exit(this._lock);
			if (!needOne)
			{
				return;
			}
			System.Diagnostics.Stopwatch stopwatch = System.Diagnostics.Stopwatch.StartNew();
			this.MCI_ConstructOne(actorTemplate, global);
			Console.WriteLine(string.Concat(new string[]
			{
				"[MCI] Pool '", actorTemplate, "' exhausted at ", count.ToString(),
				"; built 1 in ", stopwatch.ElapsedMilliseconds.ToString(), "ms."
			}));
		}

		// Mirrors AddPoolInternal's per-object steps, minus _poolStack so the stock
		// exhaustion branch can't recurse
		private void MCI_ConstructOne(string actorTemplate, bool global)
		{
			bool disableInvalidate = Paris.Engine.Physic.CollisionManager.DisableInvalidate;
			Paris.Engine.Physic.CollisionManager.DisableInvalidate = true;
			bool useGlobalContentManager = Paris.Engine.Context.ContextManager.Singleton.UseGlobalContentManager;
			Paris.Engine.Context.ContextManager.Singleton.UseGlobalContentManager = global;
			try
			{
				string text = actorTemplate.StartsWith("SceneInstance:")
					? actorTemplate
					: PathManager.NormalizePath("Actor2d\\" + actorTemplate);
				Paris.Engine.Graphics.Playfield.GameObjectData gameObjectData = new Paris.Engine.Graphics.Playfield.GameObjectData(text, false);
				Monitor.Enter(this._lock);
				List<Paris.Engine.Graphics.Playfield.GameObjectData> list;
				if (!this._pools.TryGetValue(actorTemplate, out list))
				{
					list = new List<Paris.Engine.Graphics.Playfield.GameObjectData>();
					this._pools[actorTemplate] = list;
				}
				int num = list.Count;
				Monitor.Exit(this._lock);
				gameObjectData.GameObject.Name = "POOLED_MCI_" + System.IO.Path.GetFileNameWithoutExtension(actorTemplate) + "_" + num.ToString("D3");
				gameObjectData.GameObject.PoolObject = true;
				gameObjectData.GameObject.Init();
				gameObjectData.GameObject.Disposed = true;
				gameObjectData.GameObject.Active = false;
				gameObjectData.PoolObject = true;
				gameObjectData.Saveable = false;
				Monitor.Enter(this._lock);
				list.Add(gameObjectData);
				this._poolMaxes[actorTemplate] = list.Count;
				Monitor.Exit(this._lock);
			}
			catch (Exception e)
			{
				Console.WriteLine("[MCI] Emergency pool construct failed for " + actorTemplate + ": " + e.Message);
			}
			finally
			{
				Paris.Engine.Context.ContextManager.Singleton.UseGlobalContentManager = useGlobalContentManager;
				Paris.Engine.Physic.CollisionManager.DisableInvalidate = disableInvalidate;
			}
		}
	}
}
