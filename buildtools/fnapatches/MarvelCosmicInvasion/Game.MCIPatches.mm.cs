using System;
using System.Reflection;
using Paris.Engine;
using Paris.Engine.Context;
using Paris.Engine.Helper;
using Paris.Engine.Scene;
using Paris.Game.Camera;

// Ignore empty context switches instead of crashing on them
namespace Paris.Game
{
	class patch_GameContextManager
	{
		public extern void orig_SwitchToContext(string newContext, bool add);
		public void SwitchToContext(string newContext, bool add)
		{
			if (string.IsNullOrEmpty(newContext))
			{
				return;
			}
			orig_SwitchToContext(newContext, add);
		}
	}
}

// Dev: F9 completes a wave
namespace Paris.Game.Triggers
{
	class patch_CameraBlockTrigger : CameraBlockTrigger
	{
		private int _currentWaveIndex;
		private FSM _fsm;

		public extern void orig_Tick(float deltaTime);
		public override void Tick(float deltaTime)
		{
			this.orig_Tick(deltaTime);
			if (base.HasAuthority && global::Paris.Engine.Input.InputManagerBase.Singleton.IsKeyJustPressed(global::Microsoft.Xna.Framework.Input.Keys.F9, false))
			{
				Scene2d sc = Scene2d.Active;
				BeatEmUpCamera cam = (sc != null) ? (sc.CurrentCamera as BeatEmUpCamera) : null;
				if (cam != null && cam.CameraBlock == this && this._fsm.IsInState(2))
				{
					this._currentWaveIndex = this.Waves.Count;
					this._fsm.ChangeState(3);
				}
			}
		}
	}
}

// LAN build: trim the online menu down to what works without Steam/Epic
// (Create Party, Join Party Code, Quick Join).
#if MCI_LAN
namespace Paris.Game.Menu
{
	class patch_MultiplayerDash : MultiplayerDash
	{
		private global::Paris.Engine.Menu.Control.TextSelectionItem _invite;
		private global::Paris.Engine.Menu.Control.SelectionMenuControl _mainMenuSelection;
		private global::Paris.Engine.Menu.Control.SelectionMenuControl _lobbyMode;

		// RefreshMainMenu re-shows these each call and runs before input in the same
		// tick, so the fix has to live inside it.
		public extern void orig_RefreshMainMenu();
		private void RefreshMainMenu()
		{
			orig_RefreshMainMenu();
			if (this._mainMenuSelection != null && this._mainMenuSelection.Items.Count > 6)
			{
				this._mainMenuSelection.Items[1].Hidden = true;      // Invites
				this._mainMenuSelection.Items[1].CanAccept = false;
				this._mainMenuSelection.Items[2].Hidden = true;      // Join Friends
				this._mainMenuSelection.Items[2].CanAccept = false;
				this._mainMenuSelection.Items[5].Hidden = true;      // Crossplay
				this._mainMenuSelection.Items[5].CanAccept = false;
				this._mainMenuSelection.Items[6].Hidden = true;      // Link Epic Account (un-gated by the LAN login, label unresolved)
				this._mainMenuSelection.Items[6].CanAccept = false;
			}
		}

		public extern void orig_Tick(float deltaTime);
		public override void Tick(float deltaTime)
		{
			orig_Tick(deltaTime);
			if (this._invite != null)
			{
				this._invite.Disabled = true;
				this._invite.CanAccept = false;
			}
			if (this._lobbyMode != null && this._lobbyMode.Items.Count > 1)
			{
				this._lobbyMode.Items[1].Hidden = true;              // party type: Friends (Public/Private only on LAN)
				this._lobbyMode.Items[1].CanAccept = false;
			}
		}
	}
}
#endif

// Bypass NBUG and get crash reports directly
namespace Paris
{
	class patch_Program
	{
		public static extern void orig_LogException(Exception ex);
		public static void LogException(Exception ex)
		{
			try
			{
				global::System.Text.StringBuilder sb = new global::System.Text.StringBuilder();
				Exception e = ex;
				int depth = 0;
				while (e != null && depth < 8)
				{
					sb.AppendLine("[MCICRASH] " + e.GetType().FullName + ": " + e.Message);
					sb.AppendLine("[MCICRASH] " + e.StackTrace);
					global::System.Reflection.ReflectionTypeLoadException rtle = e as global::System.Reflection.ReflectionTypeLoadException;
					if (rtle != null && rtle.LoaderExceptions != null)
					{
						foreach (Exception le in rtle.LoaderExceptions)
						{
							sb.AppendLine("[MCICRASH] loader: " + ((le != null) ? (le.GetType().Name + ": " + le.Message) : "null"));
						}
					}
					e = e.InnerException;
					depth++;
				}
				string text = sb.ToString();
				Console.WriteLine(text);
				Console.Out.Flush();
				global::System.IO.File.AppendAllText("mci_crash.txt", text);
			}
			catch (Exception)
			{
			}
			orig_LogException(ex);
		}
	}
}

// Run the preloadables our engine-side preload split no longer reaches, then release the game
namespace Paris
{
	class patch_Paris : Paris
	{
		private static bool mci_nbugDropped;

		public extern void orig_StartInit();
		private void StartInit()
		{
			if (!mci_nbugDropped)
			{
				mci_nbugDropped = true;
				try
				{
					global::System.AppDomain.CurrentDomain.UnhandledException -= global::NBug.Handler.UnhandledException;
				}
				catch (Exception)
				{
				}
			}
			orig_StartInit();
			foreach (Type type in Assembly.GetExecutingAssembly().GetLoadableTypes())
			{
				if (typeof(IPreloadable).IsAssignableFrom(type))
				{
					((IPreloadable)Activator.CreateInstance(type)).Preload();
				}
			}

			// Reflection because MCI_FinishPreload only exists after the engine mixin is applied
			ContextManager ctx = ContextManager.Singleton;
			MethodInfo m = ctx.GetType().GetMethod("MCI_FinishPreload");
			if (m != null)
			{
				m.Invoke(ctx, null);
			}
		}
	}
}
