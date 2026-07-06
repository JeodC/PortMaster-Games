using System;
using System.Reflection;
using Paris.Engine;
using Paris.Engine.Context;
using Paris.Engine.Helper;

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

namespace Paris
{
	class patch_Paris : Paris
	{
		public extern void orig_StartInit();
		private void StartInit()
		{
			orig_StartInit();
			foreach (Type type in Assembly.GetExecutingAssembly().GetLoadableTypes())
			{
				if (typeof(IPreloadable).IsAssignableFrom(type))
				{
					((IPreloadable)Activator.CreateInstance(type)).Preload();
				}
			}

			ContextManager ctx = ContextManager.Singleton;
			MethodInfo m = ctx.GetType().GetMethod("MCI_FinishPreload");
			if (m != null)
			{
				m.Invoke(ctx, null);
			}
		}
	}
}
