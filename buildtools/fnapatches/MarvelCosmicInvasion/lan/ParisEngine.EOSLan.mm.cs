// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jeod
//
// ParisEngine.EOSLan.mm.cs - EOS-over-LAN shim for MARVEL Cosmic Invasion.
//
// Replaces Epic Online Services with a LAN backend (libEOSSDK-LAN.cs) so two devices on
// the same network can play co-op. No Epic account, no internet, no native EOSSDK.
// Written clean-room against the game's own EOS C# wrapper (Epic.OnlineServices.*).
// Fully isolated from the real services: nothing here contacts Epic or Steam, and all
// traffic stays on the local subnet - real online sessions can't be touched from here.
//
// MciLan holds the identity side-table (puid string <-> fake handle) and the callback
// queue pumped by Platform.Tick. LobbyBridge glues the EOS lobby/P2P surface onto the
// LAN core. The patch_ classes replace the high-level wrapper methods; the wrapper types
// are sealed, so each patch inherits Handle and binds by name via [MonoModPatch].
//
// Built together with the base ship mixin and the LAN core using -d:MCI_LAN (which also
// compiles out the base mixin's EOS/networking no-ops). See BUILD.md section 4.
using System;
using System.Collections.Generic;
using MonoMod;
using Epic.OnlineServices;
using Epic.OnlineServices.Platform;
using Epic.OnlineServices.Connect;
using Epic.OnlineServices.Lobby;
using Epic.OnlineServices.Auth;
using Epic.OnlineServices.Presence;
using Epic.OnlineServices.P2P;
using Paris.Engine;
using Paris.Engine.EOSLan;

namespace Paris.Engine.EOSLan
{
	// Identity side-table plus the Tick-pumped callback queue, shared by every shim.
	static class MciLan
	{
		static readonly object gate = new object();
		static readonly Dictionary<string, IntPtr> idToHandle = new Dictionary<string, IntPtr>();
		static readonly Dictionary<IntPtr, string> handleToId = new Dictionary<IntPtr, string>();
		static long nextHandle = 0x4000L;   // start high so minted handles never look like a small real pointer
		static readonly Queue<Action> callbacks = new Queue<Action>();
		static string localId;

		// One non-null sentinel for the Platform + interface objects. The game only ever
		// compares those for null, so a single value suffices.
		public static readonly IntPtr FakeHandle = new IntPtr(1);

		// Stable local identity, seeded from the hostname so two devices differ.
		// DisplayName is what players see; LocalId is the ProductUserId string.
		public static string DisplayName
		{
			get
			{
				if (displayName == null)
				{
					string h = "Player";
					try { h = System.Net.Dns.GetHostName(); } catch { }
					displayName = string.IsNullOrEmpty(h) ? "Player" : h;
				}
				return displayName;
			}
		}
		static string displayName;

		public static string LocalId
		{
			get
			{
				if (localId == null)
				{
					localId = "LAN-" + DisplayName;
				}
				return localId;
			}
		}

		public static IntPtr HandleForId(string id)
		{
			if (string.IsNullOrEmpty(id)) return IntPtr.Zero;
			lock (gate)
			{
				IntPtr h;
				if (!idToHandle.TryGetValue(id, out h))
				{
					h = new IntPtr(nextHandle++);
					idToHandle[id] = h;
					handleToId[h] = id;
				}
				return h;
			}
		}

		public static string IdForHandle(IntPtr h)
		{
			lock (gate) { string s; return handleToId.TryGetValue(h, out s) ? s : null; }
		}

		// Queue a callback to fire on the next Platform.Tick (EOS-style async delivery).
		public static void Post(Action cb) { lock (gate) callbacks.Enqueue(cb); }

		public static void Pump()
		{
			while (true)
			{
				Action cb;
				lock (gate) { if (callbacks.Count == 0) return; cb = callbacks.Dequeue(); }
				try { cb(); }
				catch (Exception e) { Console.WriteLine("[EOSLAN] callback error: " + e); }
			}
		}
	}
}

namespace Epic.OnlineServices
{
	// ProductUserId backed by the side-table: FromString/ToString round-trip, minted ids are valid.
	[MonoModPatch("Epic.OnlineServices.ProductUserId")]
	class patch_ProductUserId : Handle
	{
		[MonoModReplace]
		public static ProductUserId FromString(Utf8String productUserIdString)
		{
			return new ProductUserId(MciLan.HandleForId(productUserIdString));
		}

		[MonoModReplace]
		public bool IsValid()
		{
			return base.InnerHandle != IntPtr.Zero;
		}

		[MonoModReplace]
		public Result ToString(out Utf8String outBuffer)
		{
			string s = MciLan.IdForHandle(base.InnerHandle);
			outBuffer = s ?? "";
			return Result.Success;
		}
	}
}

namespace Epic.OnlineServices.Platform
{
	// Platform: init/create succeed with the sentinel handle; Tick() pumps our callbacks.
	[MonoModPatch("Epic.OnlineServices.Platform.PlatformInterface")]
	class patch_PlatformInterface : Handle
	{
		[MonoModReplace]
		public static Result Initialize(ref InitializeOptions options)
		{
			return Result.Success;
		}

		[MonoModReplace]
		public static PlatformInterface Create(ref Options options)
		{
			return new PlatformInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public ConnectInterface GetConnectInterface()
		{
			return new ConnectInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public LobbyInterface GetLobbyInterface()
		{
			return new LobbyInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public AuthInterface GetAuthInterface()
		{
			return new AuthInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public PresenceInterface GetPresenceInterface()
		{
			return new PresenceInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public P2PInterface GetP2PInterface()
		{
			return new P2PInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public Epic.OnlineServices.Sanctions.SanctionsInterface GetSanctionsInterface()
		{
			return new Epic.OnlineServices.Sanctions.SanctionsInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public Epic.OnlineServices.UserInfo.UserInfoInterface GetUserInfoInterface()
		{
			return new Epic.OnlineServices.UserInfo.UserInfoInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public Epic.OnlineServices.Friends.FriendsInterface GetFriendsInterface()
		{
			return new Epic.OnlineServices.Friends.FriendsInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public Epic.OnlineServices.Reports.ReportsInterface GetReportsInterface()
		{
			return new Epic.OnlineServices.Reports.ReportsInterface(MciLan.FakeHandle);
		}

		[MonoModReplace]
		public void Tick()
		{
			MciLan.Pump();
		}

		// NetworkManager.Tick polls this every frame while connected; the LAN is always up.
		[MonoModReplace]
		public NetworkStatus GetNetworkStatus()
		{
			return NetworkStatus.Online;
		}

		// Exit path (Uninit -> Release + Shutdown). The stub SDK lacks EOS_Shutdown, and an
		// exception here would mask whatever was unwinding through Game.Dispose.
		[MonoModReplace]
		public void Release()
		{
		}

		[MonoModReplace]
		public static Result Shutdown()
		{
			return Result.Success;
		}
	}
}

namespace Epic.OnlineServices.Connect
{
	// Connect: logins succeed immediately as the local product user, delivered on Tick.
	[MonoModPatch("Epic.OnlineServices.Connect.ConnectInterface")]
	class patch_ConnectInterface : Handle
	{
		[MonoModReplace]
		public void Login(ref LoginOptions options, object clientData, OnLoginCallback completionDelegate)
		{
			ProductUserId puid = new ProductUserId(MciLan.HandleForId(MciLan.LocalId));
			MciLan.Post(delegate
			{
				LoginCallbackInfo info = new LoginCallbackInfo
				{
					ResultCode = Result.Success,
					ClientData = clientData,
					LocalUserId = puid
				};
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public void CreateUser(ref CreateUserOptions options, object clientData, OnCreateUserCallback completionDelegate)
		{
			ProductUserId puid = new ProductUserId(MciLan.HandleForId(MciLan.LocalId));
			MciLan.Post(delegate
			{
				CreateUserCallbackInfo info = new CreateUserCallbackInfo
				{
					ResultCode = Result.Success,
					ClientData = clientData,
					LocalUserId = puid
				};
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public ulong AddNotifyLoginStatusChanged(ref AddNotifyLoginStatusChangedOptions options, object clientData, OnLoginStatusChangedCallback notification)
		{
			// No status transitions in the LAN backend yet; a non-zero id keeps callers happy.
			return 1UL;
		}

		[MonoModReplace]
		public ulong AddNotifyAuthExpiration(ref AddNotifyAuthExpirationOptions options, object clientData, OnAuthExpirationCallback notification)
		{
			return 1UL;
		}

		// Identity mappings resolve trivially on LAN - every puid string is already local.
		[MonoModReplace]
		public void QueryProductUserIdMappings(ref QueryProductUserIdMappingsOptions options, object clientData, OnQueryProductUserIdMappingsCallback completionDelegate)
		{
			ProductUserId local = new ProductUserId(MciLan.HandleForId(MciLan.LocalId));
			MciLan.Post(delegate
			{
				QueryProductUserIdMappingsCallbackInfo info = new QueryProductUserIdMappingsCallbackInfo { ResultCode = Result.Success, ClientData = clientData, LocalUserId = local };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public void QueryExternalAccountMappings(ref QueryExternalAccountMappingsOptions options, object clientData, OnQueryExternalAccountMappingsCallback completionDelegate)
		{
			ProductUserId local = new ProductUserId(MciLan.HandleForId(MciLan.LocalId));
			MciLan.Post(delegate
			{
				QueryExternalAccountMappingsCallbackInfo info = new QueryExternalAccountMappingsCallbackInfo { ResultCode = Result.Success, ClientData = clientData, LocalUserId = local };
				completionDelegate(ref info);
			});
		}

		// NotFound on purpose: Success would route name resolution into the Epic-account
		// path (native UserInfo). Names come from lobby member attributes instead.
		[MonoModReplace]
		public Result GetProductUserIdMapping(ref GetProductUserIdMappingOptions options, out Utf8String outBuffer)
		{
			outBuffer = null;
			return Result.NotFound;
		}

		[MonoModReplace]
		public uint GetProductUserExternalAccountCount(ref GetProductUserExternalAccountCountOptions options)
		{
			return 0U;
		}
	}
}

namespace Paris.Engine
{
	// Un-gate EpicHelper: skip the real EOS+Steam startup (needs a Steam ticket / Epic
	// account we don't have) and log straight in with a device-local identity.
	// Replaces the base mixin's no-op, which is #if'd out under MCI_LAN.
	[MonoModPatch("Paris.Engine.EpicHelper")]
	static class patch_EpicHelper
	{
		[MonoModReplace]
		public static void Init()
		{
			if (EpicHelper._initialized)
			{
				return;
			}
			EpicHelper._initialized = true;
			EpicHelper.Interface = new PlatformInterface(MciLan.FakeHandle);
			Console.WriteLine("[EOSLAN] Init: fake platform ready");
			EpicHelper.Login(false);   // LAN: no account selection, log in immediately
		}

		[MonoModReplace]
		public static void Login(bool forceRetry = false)
		{
			if (EpicHelper._loggedIn || EpicHelper._loggingIn)
			{
				return;
			}
			EpicHelper._localUserId = new ProductUserId(MciLan.HandleForId(MciLan.LocalId));
			EpicHelper._loggedIn = true;
			Console.WriteLine("[EOSLAN] Login: logged in as " + MciLan.LocalId);
		}
	}
}

// LAN lobby adapter: Lobby/LobbyDetails/LobbySearch/LobbyModification over the LAN
// core, plus Presence/P2P so the multiplayer flow never touches the native SDK
namespace Paris.Engine.EOSLan
{
	// Attributes staged on a LobbyModification, applied to the lobby on UpdateLobby.
	class ModStage
	{
		public readonly System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string, LanAttr>> Attrs =
			new System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string, LanAttr>>();
		public readonly System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string, LanAttr>> MemberAttrs =
			new System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<string, LanAttr>>();
		public string Bucket;
		public uint? Max;
	}

	// Glue between the EOS lobby/P2P surface and the LAN core: owns the net instance,
	// mints handles, stores notify callbacks, re-posts net events onto Platform.Tick.
	static class LobbyBridge
	{
		static readonly object gate = new object();
		static MciLanNet net;
		static long nextHandle = 0x8000L;

		static readonly System.Collections.Generic.Dictionary<IntPtr, LanLobbyInfo> details =
			new System.Collections.Generic.Dictionary<IntPtr, LanLobbyInfo>();   // value null => live current lobby
		static readonly System.Collections.Generic.Dictionary<IntPtr, ModStage> mods =
			new System.Collections.Generic.Dictionary<IntPtr, ModStage>();
		static readonly System.Collections.Generic.Dictionary<IntPtr, string> searches =
			new System.Collections.Generic.Dictionary<IntPtr, string>();

		static OnLobbyMemberStatusReceivedCallback memberStatusCb; static object memberStatusCd;
		static OnLobbyUpdateReceivedCallback lobbyUpdateCb; static object lobbyUpdateCd;
		static OnLobbyMemberUpdateReceivedCallback memberUpdateCb; static object memberUpdateCd;

		// P2P connection lifecycle. The join flow depends on it: the host only marks a member
		// NeedsSync (-> sends PrepareJoinGame) from OnRemoteConnectionEstablished.
		static Epic.OnlineServices.P2P.OnIncomingConnectionRequestCallback connReqCb; static object connReqCd;
		static Epic.OnlineServices.P2P.OnPeerConnectionEstablishedCallback connEstCb; static object connEstCd;
		static readonly System.Collections.Generic.HashSet<string> connIn = new System.Collections.Generic.HashSet<string>();
		static readonly System.Collections.Generic.HashSet<string> connOut = new System.Collections.Generic.HashSet<string>();

		public static void SetConnReqCb(Epic.OnlineServices.P2P.OnIncomingConnectionRequestCallback cb, object cd) { lock (gate) { connReqCb = cb; connReqCd = cd; } }
		public static void SetConnEstCb(Epic.OnlineServices.P2P.OnPeerConnectionEstablishedCallback cb, object cd) { lock (gate) { connEstCb = cb; connEstCd = cd; } }

		public static void ResetConnections() { lock (gate) { connIn.Clear(); connOut.Clear(); } }

		// first packet we SEND to a peer: consider the outgoing connection established
		public static void NotePacketSent(string toId, string socket)
		{
			bool fire; lock (gate) { fire = connOut.Add(toId); }
			if (fire) FireEstablished(toId, socket);
		}

		// first packet we RECEIVE from a peer: incoming request, auto-accepted, established
		public static void NotePacketReceived(string fromId, string socket)
		{
			bool fire; lock (gate) { fire = connIn.Add(fromId); }
			if (fire) { FireConnRequest(fromId, socket); FireEstablished(fromId, socket); }
		}

		static void FireConnRequest(string id, string socket)
		{
			Epic.OnlineServices.P2P.OnIncomingConnectionRequestCallback cb; object cd;
			lock (gate) { cb = connReqCb; cd = connReqCd; }
			if (cb == null) return;
			ProductUserId remote = new ProductUserId(MciLan.HandleForId(id));
			ProductUserId local = new ProductUserId(MciLan.HandleForId(MciLan.LocalId));
			Epic.OnlineServices.P2P.SocketId sock = new Epic.OnlineServices.P2P.SocketId { SocketName = socket };
			MciLan.Post(delegate
			{
				Epic.OnlineServices.P2P.OnIncomingConnectionRequestInfo info = new Epic.OnlineServices.P2P.OnIncomingConnectionRequestInfo
				{ ClientData = cd, LocalUserId = local, RemoteUserId = remote, SocketId = new Epic.OnlineServices.P2P.SocketId?(sock) };
				cb(ref info);
			});
		}

		static void FireEstablished(string id, string socket)
		{
			Epic.OnlineServices.P2P.OnPeerConnectionEstablishedCallback cb; object cd;
			lock (gate) { cb = connEstCb; cd = connEstCd; }
			if (cb == null) return;
			ProductUserId remote = new ProductUserId(MciLan.HandleForId(id));
			ProductUserId local = new ProductUserId(MciLan.HandleForId(MciLan.LocalId));
			Epic.OnlineServices.P2P.SocketId sock = new Epic.OnlineServices.P2P.SocketId { SocketName = socket };
			MciLan.Post(delegate
			{
				Epic.OnlineServices.P2P.OnPeerConnectionEstablishedInfo info = new Epic.OnlineServices.P2P.OnPeerConnectionEstablishedInfo
				{
					ClientData = cd, LocalUserId = local, RemoteUserId = remote,
					SocketId = new Epic.OnlineServices.P2P.SocketId?(sock),
					ConnectionType = Epic.OnlineServices.P2P.ConnectionEstablishedType.NewConnection,
					NetworkType = Epic.OnlineServices.P2P.NetworkConnectionType.DirectConnection
				};
				cb(ref info);
			});
		}

		public static MciLanNet Net
		{
			get
			{
				lock (gate)
				{
					if (net == null)
					{
						net = new MciLanNet { LocalId = MciLan.LocalId, LocalName = MciLan.DisplayName };
						net.MemberJoined += delegate (LanMember m) { FireMemberStatus(m.Id, LobbyMemberStatus.Joined); FireMemberUpdate(m.Id); };
						net.MemberLeft += delegate (string id) { FireMemberStatus(id, LobbyMemberStatus.Left); };
						net.LobbyChanged += FireLobbyUpdate;
						net.MemberChanged += FireMemberUpdate;
						net.Start();
						Console.WriteLine("[EOSLAN] LAN net started (" + MciLan.LocalId + ")");
					}
					return net;
				}
			}
		}

		static IntPtr Mint() { lock (gate) { return new IntPtr(nextHandle++); } }

		public static IntPtr NewDetailsLive() { IntPtr h = Mint(); lock (gate) details[h] = null; return h; }
		public static IntPtr NewDetailsFrozen(LanLobbyInfo info) { IntPtr h = Mint(); lock (gate) details[h] = info; return h; }
		public static LanLobbyInfo DetailsInfo(IntPtr h)
		{
			lock (gate)
			{
				LanLobbyInfo info;
				if (!details.TryGetValue(h, out info)) return null;
				return info != null ? info : CurrentSnapshot();
			}
		}

		public static IntPtr NewMod() { IntPtr h = Mint(); lock (gate) mods[h] = new ModStage(); return h; }
		public static ModStage Mod(IntPtr h) { lock (gate) { ModStage s; return mods.TryGetValue(h, out s) ? s : null; } }
		public static void CommitMod(IntPtr h)
		{
			ModStage s = Mod(h);
			if (s == null) return;
			foreach (System.Collections.Generic.KeyValuePair<string, LanAttr> kv in s.Attrs) Net.SetLobbyAttr(kv.Key, kv.Value);
			if (s.Bucket != null) Net.SetBucket(s.Bucket);
			if (s.Max.HasValue) Net.SetMaxMembers(s.Max.Value);
			if (s.MemberAttrs.Count > 0)
			{
				Net.SetLocalMemberAttrs(s.MemberAttrs);
				foreach (System.Collections.Generic.KeyValuePair<string, LanAttr> kv in s.MemberAttrs)
					if (kv.Key == "NAME" && kv.Value.Type == 's') Net.SetLocalName(kv.Value.StringValue);
			}
		}

		public static IntPtr NewSearch(string filter) { IntPtr h = Mint(); lock (gate) searches[h] = filter; return h; }
		public static void SetSearchFilter(IntPtr h, string f) { lock (gate) searches[h] = f; }
		public static string SearchFilter(IntPtr h) { lock (gate) { string f; searches.TryGetValue(h, out f); return f; } }

		public static LanLobbyInfo CurrentSnapshot()   // caller may hold gate; only reads Net snapshots
		{
			MciLanNet n = Net;
			LanLobbyInfo info = new LanLobbyInfo { LobbyId = n.LobbyId, HostId = n.HostId, MaxMembers = n.MaxMembers, Bucket = n.Bucket };
			foreach (LanMember m in n.Members()) info.Members.Add(m);
			foreach (System.Collections.Generic.KeyValuePair<string, LanAttr> kv in n.Attributes()) info.Attributes[kv.Key] = kv.Value;
			return info;
		}

		public static void SetMemberStatusCb(OnLobbyMemberStatusReceivedCallback cb, object cd) { lock (gate) { memberStatusCb = cb; memberStatusCd = cd; } }
		public static void SetLobbyUpdateCb(OnLobbyUpdateReceivedCallback cb, object cd) { lock (gate) { lobbyUpdateCb = cb; lobbyUpdateCd = cd; } }
		public static void SetMemberUpdateCb(OnLobbyMemberUpdateReceivedCallback cb, object cd) { lock (gate) { memberUpdateCb = cb; memberUpdateCd = cd; } }

		static void FireMemberUpdate(string memberId)
		{
			OnLobbyMemberUpdateReceivedCallback cb; object cd; string lid;
			lock (gate) { cb = memberUpdateCb; cd = memberUpdateCd; lid = (net != null ? net.LobbyId : null); }
			if (cb == null) return;
			ProductUserId puid = new ProductUserId(MciLan.HandleForId(memberId));
			MciLan.Post(delegate
			{
				LobbyMemberUpdateReceivedCallbackInfo info = new LobbyMemberUpdateReceivedCallbackInfo
				{ ClientData = cd, LobbyId = lid, TargetUserId = puid };
				cb(ref info);
			});
		}

		static void FireMemberStatus(string memberId, LobbyMemberStatus status)
		{
			OnLobbyMemberStatusReceivedCallback cb; object cd; string lid;
			lock (gate) { cb = memberStatusCb; cd = memberStatusCd; lid = (net != null ? net.LobbyId : null); }
			if (cb == null) return;
			ProductUserId puid = new ProductUserId(MciLan.HandleForId(memberId));
			MciLan.Post(delegate
			{
				LobbyMemberStatusReceivedCallbackInfo info = new LobbyMemberStatusReceivedCallbackInfo
				{ ClientData = cd, LobbyId = lid, TargetUserId = puid, CurrentStatus = status };
				cb(ref info);
			});
		}

		static void FireLobbyUpdate()
		{
			OnLobbyUpdateReceivedCallback cb; object cd; string lid;
			lock (gate) { cb = lobbyUpdateCb; cd = lobbyUpdateCd; lid = (net != null ? net.LobbyId : null); }
			if (cb == null) return;
			MciLan.Post(delegate
			{
				LobbyUpdateReceivedCallbackInfo info = new LobbyUpdateReceivedCallbackInfo { ClientData = cd, LobbyId = lid };
				cb(ref info);
			});
		}

		public static void PostDelayed(int ms, Action a)
		{
			System.Threading.Thread t = new System.Threading.Thread(delegate () { System.Threading.Thread.Sleep(ms); MciLan.Post(a); });
			t.IsBackground = true; t.Start();
		}

		// Typed attribute conversion (EOS union <-> LanAttr)
		public static Epic.OnlineServices.Lobby.Attribute? ToEosAttr(string key, LanAttr a)
		{
			if (a == null) return null;
			AttributeDataValue v;
			switch (a.Type)
			{
				case 'i': v = (long?)a.IntValue; break;
				case 'b': v = (bool?)a.BoolValue; break;
				case 'd': v = (double?)a.DoubleValue; break;
				default: v = (a.StringValue ?? ""); break;
			}
			return new Epic.OnlineServices.Lobby.Attribute
			{
				Data = new AttributeData { Key = key, Value = v },
				Visibility = LobbyAttributeVisibility.Public
			};
		}

		public static LanAttr FromEos(AttributeData d)
		{
			AttributeDataValue v = d.Value;
			if (v.AsInt64.HasValue) return LanAttr.Int(v.AsInt64.Value);
			if (v.AsBool.HasValue) return LanAttr.Bool(v.AsBool.Value);
			if (v.AsDouble.HasValue) return LanAttr.Dbl(v.AsDouble.Value);
			return LanAttr.Str(v.AsUtf8);
		}
	}
}

namespace Epic.OnlineServices.Lobby
{
	[MonoModPatch("Epic.OnlineServices.Lobby.LobbyInterface")]
	class patch_LobbyInterface : Handle
	{
		[MonoModReplace]
		public void CreateLobby(ref CreateLobbyOptions options, object clientData, OnCreateLobbyCallback completionDelegate)
		{
			LobbyBridge.ResetConnections();
			string id = MciLanBridge().CreateLobby(options.LobbyId, options.MaxLobbyMembers, options.BucketId);
			Console.WriteLine("[EOSLAN] CreateLobby -> " + id + " (max " + options.MaxLobbyMembers + ")");
			MciLan.Post(delegate
			{
				CreateLobbyCallbackInfo info = new CreateLobbyCallbackInfo { ResultCode = Result.Success, ClientData = clientData, LobbyId = id };
				completionDelegate(ref info);
			});
		}

		static MciLanNet MciLanBridge() { return LobbyBridge.Net; }

		[MonoModReplace]
		public Result CreateLobbySearch(ref CreateLobbySearchOptions options, out LobbySearch outLobbySearchHandle)
		{
			outLobbySearchHandle = new LobbySearch(LobbyBridge.NewSearch(null));
			return Result.Success;
		}

		[MonoModReplace]
		public void JoinLobby(ref JoinLobbyOptions options, object clientData, OnJoinLobbyCallback completionDelegate)
		{
			LobbyBridge.ResetConnections();
			LanLobbyInfo li = (options.LobbyDetailsHandle != null) ? LobbyBridge.DetailsInfo(options.LobbyDetailsHandle.InnerHandle) : null;
			string id = (li != null) ? li.LobbyId : null;
			bool ok = LobbyBridge.Net.Join(li);   // snapshot join: immune to search refreshes
			Console.WriteLine("[EOSLAN] JoinLobby " + (id ?? "<null>") + " -> " + (ok ? "Success" : "NotFound"));
			MciLan.Post(delegate
			{
				JoinLobbyCallbackInfo info = new JoinLobbyCallbackInfo { ResultCode = ok ? Result.Success : Result.NotFound, ClientData = clientData, LobbyId = id };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public void LeaveLobby(ref LeaveLobbyOptions options, object clientData, OnLeaveLobbyCallback completionDelegate)
		{
			string id = LobbyBridge.Net.LobbyId;
			LobbyBridge.Net.Leave();
			LobbyBridge.ResetConnections();
			MciLan.Post(delegate
			{
				LeaveLobbyCallbackInfo info = new LeaveLobbyCallbackInfo { ResultCode = Result.Success, ClientData = clientData, LobbyId = id };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public void DestroyLobby(ref DestroyLobbyOptions options, object clientData, OnDestroyLobbyCallback completionDelegate)
		{
			string id = LobbyBridge.Net.LobbyId;
			LobbyBridge.Net.Leave();
			MciLan.Post(delegate
			{
				DestroyLobbyCallbackInfo info = new DestroyLobbyCallbackInfo { ResultCode = Result.Success, ClientData = clientData, LobbyId = id };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public Result CopyLobbyDetailsHandle(ref CopyLobbyDetailsHandleOptions options, out LobbyDetails outLobbyDetailsHandle)
		{
			outLobbyDetailsHandle = new LobbyDetails(LobbyBridge.NewDetailsLive());
			return Result.Success;
		}

		[MonoModReplace]
		public Result UpdateLobbyModification(ref UpdateLobbyModificationOptions options, out LobbyModification outLobbyModificationHandle)
		{
			outLobbyModificationHandle = new LobbyModification(LobbyBridge.NewMod());
			return Result.Success;
		}

		[MonoModReplace]
		public void UpdateLobby(ref UpdateLobbyOptions options, object clientData, OnUpdateLobbyCallback completionDelegate)
		{
			if (options.LobbyModificationHandle != null) LobbyBridge.CommitMod(options.LobbyModificationHandle.InnerHandle);
			string id = LobbyBridge.Net.LobbyId;
			MciLan.Post(delegate
			{
				UpdateLobbyCallbackInfo info = new UpdateLobbyCallbackInfo { ResultCode = Result.Success, ClientData = clientData, LobbyId = id };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public ulong AddNotifyLobbyMemberStatusReceived(ref AddNotifyLobbyMemberStatusReceivedOptions options, object clientData, OnLobbyMemberStatusReceivedCallback notificationFn)
		{
			LobbyBridge.SetMemberStatusCb(notificationFn, clientData);
			return 1UL;
		}

		[MonoModReplace]
		public ulong AddNotifyLobbyUpdateReceived(ref AddNotifyLobbyUpdateReceivedOptions options, object clientData, OnLobbyUpdateReceivedCallback notificationFn)
		{
			LobbyBridge.SetLobbyUpdateCb(notificationFn, clientData);
			return 2UL;
		}

		[MonoModReplace]
		public ulong AddNotifyLobbyMemberUpdateReceived(ref AddNotifyLobbyMemberUpdateReceivedOptions options, object clientData, OnLobbyMemberUpdateReceivedCallback notificationFn)
		{
			LobbyBridge.SetMemberUpdateCb(notificationFn, clientData);
			return 3UL;
		}
		[MonoModReplace]
		public ulong AddNotifyJoinLobbyAccepted(ref AddNotifyJoinLobbyAcceptedOptions options, object clientData, OnJoinLobbyAcceptedCallback notificationFn) { return 4UL; }
		[MonoModReplace]
		public ulong AddNotifyLobbyInviteAccepted(ref AddNotifyLobbyInviteAcceptedOptions options, object clientData, OnLobbyInviteAcceptedCallback notificationFn) { return 5UL; }
		[MonoModReplace]
		public ulong AddNotifyLobbyInviteReceived(ref AddNotifyLobbyInviteReceivedOptions options, object clientData, OnLobbyInviteReceivedCallback notificationFn) { return 6UL; }

		[MonoModReplace] public void RemoveNotifyLobbyMemberStatusReceived(ulong inId) { }
		[MonoModReplace] public void RemoveNotifyLobbyUpdateReceived(ulong inId) { }
		[MonoModReplace] public void RemoveNotifyLobbyMemberUpdateReceived(ulong inId) { }
		[MonoModReplace] public void RemoveNotifyJoinLobbyAccepted(ulong inId) { }
		[MonoModReplace] public void RemoveNotifyLobbyInviteAccepted(ulong inId) { }
		[MonoModReplace] public void RemoveNotifyLobbyInviteReceived(ulong inId) { }
	}

	[MonoModPatch("Epic.OnlineServices.Lobby.LobbyModification")]
	class patch_LobbyModification : Handle
	{
		[MonoModReplace]
		public Result AddAttribute(ref LobbyModificationAddAttributeOptions options)
		{
			ModStage s = LobbyBridge.Mod(base.InnerHandle);
			if (s != null && options.Attribute.HasValue)
			{
				AttributeData d = options.Attribute.Value;
				s.Attrs.Add(new System.Collections.Generic.KeyValuePair<string, LanAttr>((string)d.Key, LobbyBridge.FromEos(d)));
			}
			return Result.Success;
		}

		[MonoModReplace]
		public Result AddMemberAttribute(ref LobbyModificationAddMemberAttributeOptions options)
		{
			ModStage s = LobbyBridge.Mod(base.InnerHandle);
			if (s != null && options.Attribute.HasValue)
			{
				AttributeData d = options.Attribute.Value;
				s.MemberAttrs.Add(new System.Collections.Generic.KeyValuePair<string, LanAttr>((string)d.Key, LobbyBridge.FromEos(d)));
			}
			return Result.Success;
		}

		[MonoModReplace]
		public Result SetBucketId(ref LobbyModificationSetBucketIdOptions options)
		{
			ModStage s = LobbyBridge.Mod(base.InnerHandle);
			if (s != null) s.Bucket = options.BucketId;
			return Result.Success;
		}

		[MonoModReplace]
		public Result SetMaxMembers(ref LobbyModificationSetMaxMembersOptions options)
		{
			ModStage s = LobbyBridge.Mod(base.InnerHandle);
			if (s != null) s.Max = options.MaxMembers;
			return Result.Success;
		}

		[MonoModReplace] public Result SetPermissionLevel(ref LobbyModificationSetPermissionLevelOptions options) { return Result.Success; }
		[MonoModReplace] public Result SetInvitesAllowed(ref LobbyModificationSetInvitesAllowedOptions options) { return Result.Success; }
		[MonoModReplace] public Result SetAllowedPlatformIds(ref LobbyModificationSetAllowedPlatformIdsOptions options) { return Result.Success; }
		[MonoModReplace] public Result RemoveAttribute(ref LobbyModificationRemoveAttributeOptions options) { return Result.Success; }
		[MonoModReplace] public Result RemoveMemberAttribute(ref LobbyModificationRemoveMemberAttributeOptions options) { return Result.Success; }
	}

	[MonoModPatch("Epic.OnlineServices.Lobby.LobbyDetails")]
	class patch_LobbyDetails : Handle
	{
		LanMember FindMember(LanLobbyInfo li, ProductUserId puid)
		{
			string id = (puid != null) ? MciLan.IdForHandle(puid.InnerHandle) : null;
			if (li == null || id == null) return null;
			return li.Members.Find(delegate (LanMember x) { return x.Id == id; });
		}

		[MonoModReplace]
		public Result CopyInfo(ref LobbyDetailsCopyInfoOptions options, out LobbyDetailsInfo? outLobbyDetailsInfo)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			if (li == null) { outLobbyDetailsInfo = null; return Result.NotFound; }
			outLobbyDetailsInfo = new LobbyDetailsInfo
			{
				LobbyId = li.LobbyId,
				LobbyOwnerUserId = new ProductUserId(MciLan.HandleForId(li.HostId)),
				PermissionLevel = LobbyPermissionLevel.Publicadvertised,
				AvailableSlots = (li.MaxMembers > (uint)li.Members.Count) ? (li.MaxMembers - (uint)li.Members.Count) : 0U,
				MaxMembers = li.MaxMembers,
				AllowInvites = true,
				BucketId = li.Bucket,
				AllowHostMigration = false,
				RTCRoomEnabled = false
			};
			return Result.Success;
		}

		[MonoModReplace]
		public uint GetMemberCount(ref LobbyDetailsGetMemberCountOptions options)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			return (li != null) ? (uint)li.Members.Count : 0U;
		}

		[MonoModReplace]
		public ProductUserId GetMemberByIndex(ref LobbyDetailsGetMemberByIndexOptions options)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			if (li == null || options.MemberIndex >= li.Members.Count) return new ProductUserId(IntPtr.Zero);
			return new ProductUserId(MciLan.HandleForId(li.Members[(int)options.MemberIndex].Id));
		}

		[MonoModReplace]
		public ProductUserId GetLobbyOwner(ref LobbyDetailsGetLobbyOwnerOptions options)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			return new ProductUserId(MciLan.HandleForId((li != null) ? li.HostId : ""));
		}

		[MonoModReplace]
		public Result CopyAttributeByKey(ref LobbyDetailsCopyAttributeByKeyOptions options, out Attribute? outAttribute)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			string key = (string)options.AttrKey;
			LanAttr a = (li != null && li.Attributes.ContainsKey(key)) ? li.Attributes[key] : null;
			outAttribute = LobbyBridge.ToEosAttr(key, a);
			return (a != null) ? Result.Success : Result.NotFound;
		}

		[MonoModReplace]
		public uint GetAttributeCount(ref LobbyDetailsGetAttributeCountOptions options)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			return (li != null) ? (uint)li.Attributes.Count : 0U;
		}

		[MonoModReplace]
		public Result CopyAttributeByIndex(ref LobbyDetailsCopyAttributeByIndexOptions options, out Attribute? outAttribute)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			outAttribute = null;
			if (li == null) return Result.NotFound;
			int i = 0;
			foreach (System.Collections.Generic.KeyValuePair<string, LanAttr> kv in li.Attributes)
			{
				if (i++ == options.AttrIndex) { outAttribute = LobbyBridge.ToEosAttr(kv.Key, kv.Value); return Result.Success; }
			}
			return Result.NotFound;
		}

		[MonoModReplace]
		public Result CopyMemberInfo(ref LobbyDetailsCopyMemberInfoOptions options, out LobbyDetailsMemberInfo? outLobbyDetailsMemberInfo)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			LanMember m = FindMember(li, options.TargetUserId);
			outLobbyDetailsMemberInfo = new LobbyDetailsMemberInfo
			{
				UserId = options.TargetUserId,
				Platform = (uint)((m != null) ? m.Platform : 0),
				AllowsCrossplay = true
			};
			return Result.Success;
		}

		[MonoModReplace]
		public uint GetMemberAttributeCount(ref LobbyDetailsGetMemberAttributeCountOptions options)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			LanMember m = FindMember(li, options.TargetUserId);
			return (m != null) ? (uint)m.Attributes.Count : 0U;
		}

		[MonoModReplace]
		public Result CopyMemberAttributeByKey(ref LobbyDetailsCopyMemberAttributeByKeyOptions options, out Attribute? outAttribute)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			LanMember m = FindMember(li, options.TargetUserId);
			string key = (string)options.AttrKey;
			outAttribute = null;
			if (m == null) return Result.NotFound;
			LanAttr a;
			if (m.Attributes.TryGetValue(key, out a)) { outAttribute = LobbyBridge.ToEosAttr(key, a); return Result.Success; }
			// built-in fallbacks (always known even before the first member-attr commit)
			if (key == "NAME") { outAttribute = LobbyBridge.ToEosAttr("NAME", LanAttr.Str(m.Name)); return Result.Success; }
			if (key == "PLATFORM") { outAttribute = LobbyBridge.ToEosAttr("PLATFORM", LanAttr.Int(m.Platform)); return Result.Success; }
			return Result.NotFound;
		}

		[MonoModReplace]
		public Result CopyMemberAttributeByIndex(ref LobbyDetailsCopyMemberAttributeByIndexOptions options, out Attribute? outAttribute)
		{
			LanLobbyInfo li = LobbyBridge.DetailsInfo(base.InnerHandle);
			LanMember m = FindMember(li, options.TargetUserId);
			outAttribute = null;
			if (m == null) return Result.NotFound;
			int i = 0;
			foreach (System.Collections.Generic.KeyValuePair<string, LanAttr> kv in m.Attributes)
			{
				if (i++ == options.AttrIndex) { outAttribute = LobbyBridge.ToEosAttr(kv.Key, kv.Value); return Result.Success; }
			}
			return Result.NotFound;
		}

		[MonoModReplace] public void Release() { }
	}

	[MonoModPatch("Epic.OnlineServices.Lobby.LobbySearch")]
	class patch_LobbySearch : Handle
	{
		[MonoModReplace]
		public Result SetLobbyId(ref LobbySearchSetLobbyIdOptions options)
		{
			LobbyBridge.SetSearchFilter(base.InnerHandle, options.LobbyId);
			return Result.Success;
		}

		[MonoModReplace] public Result SetParameter(ref LobbySearchSetParameterOptions options) { return Result.Success; }
		[MonoModReplace] public Result RemoveParameter(ref LobbySearchRemoveParameterOptions options) { return Result.Success; }
		[MonoModReplace] public Result SetMaxResults(ref LobbySearchSetMaxResultsOptions options) { return Result.Success; }
		[MonoModReplace] public Result SetTargetUserId(ref LobbySearchSetTargetUserIdOptions options) { return Result.Success; }

		[MonoModReplace]
		public void Find(ref LobbySearchFindOptions options, object clientData, LobbySearchOnFindCallback completionDelegate)
		{
			string filter = LobbyBridge.SearchFilter(base.InnerHandle);
			LobbyBridge.Net.StartSearch(filter);
			LobbyBridge.PostDelayed(1600, delegate
			{
				Console.WriteLine("[EOSLAN] Find" + (filter != null ? "(" + filter + ")" : "") + " -> " + LobbyBridge.Net.SearchResults().Count + " lobby(ies)");
				LobbySearchFindCallbackInfo info = new LobbySearchFindCallbackInfo { ResultCode = Result.Success, ClientData = clientData };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public uint GetSearchResultCount(ref LobbySearchGetSearchResultCountOptions options)
		{
			return (uint)LobbyBridge.Net.SearchResults().Count;
		}

		[MonoModReplace]
		public Result CopySearchResultByIndex(ref LobbySearchCopySearchResultByIndexOptions options, out LobbyDetails outLobbyDetailsHandle)
		{
			System.Collections.Generic.List<LanLobbyInfo> results = LobbyBridge.Net.SearchResults();
			if (options.LobbyIndex >= results.Count) { outLobbyDetailsHandle = null; return Result.NotFound; }
			outLobbyDetailsHandle = new LobbyDetails(LobbyBridge.NewDetailsFrozen(results[(int)options.LobbyIndex]));
			return Result.Success;
		}

		[MonoModReplace] public void Release() { }
	}
}

namespace Epic.OnlineServices.Presence
{
	[MonoModPatch("Epic.OnlineServices.Presence.PresenceInterface")]
	class patch_PresenceInterface : Handle
	{
		[MonoModReplace]
		public Result CreatePresenceModification(ref CreatePresenceModificationOptions options, out PresenceModification outPresenceModificationHandle)
		{
			outPresenceModificationHandle = new PresenceModification(Paris.Engine.EOSLan.MciLan.FakeHandle);
			return Result.Success;
		}
		[MonoModReplace] public void SetPresence(ref SetPresenceOptions options, object clientData, SetPresenceCompleteCallback completionDelegate) { }
		[MonoModReplace] public ulong AddNotifyOnPresenceChanged(ref AddNotifyOnPresenceChangedOptions options, object clientData, OnPresenceChangedCallback notificationHandler) { return 1UL; }
		[MonoModReplace] public ulong AddNotifyJoinGameAccepted(ref AddNotifyJoinGameAcceptedOptions options, object clientData, OnJoinGameAcceptedCallback notificationFn) { return 2UL; }
		[MonoModReplace] public void QueryPresence(ref QueryPresenceOptions options, object clientData, OnQueryPresenceCompleteCallback completionDelegate) { }
		[MonoModReplace] public bool HasPresence(ref HasPresenceOptions options) { return false; }
		[MonoModReplace] public void RemoveNotifyOnPresenceChanged(ulong notificationId) { }
		[MonoModReplace] public void RemoveNotifyJoinGameAccepted(ulong inId) { }
	}

	[MonoModPatch("Epic.OnlineServices.Presence.PresenceModification")]
	class patch_PresenceModification : Handle
	{
		[MonoModReplace] public Result SetData(ref PresenceModificationSetDataOptions options) { return Result.Success; }
		[MonoModReplace] public Result SetJoinInfo(ref PresenceModificationSetJoinInfoOptions options) { return Result.Success; }
		[MonoModReplace] public Result SetStatus(ref PresenceModificationSetStatusOptions options) { return Result.Success; }
		[MonoModReplace] public Result SetRawRichText(ref PresenceModificationSetRawRichTextOptions options) { return Result.Success; }
		[MonoModReplace] public Result DeleteData(ref PresenceModificationDeleteDataOptions options) { return Result.Success; }
		[MonoModReplace] public void Release() { }
	}
}

namespace Epic.OnlineServices.P2P
{
	[MonoModPatch("Epic.OnlineServices.P2P.P2PInterface")]
	class patch_P2PInterface : Handle
	{
		// Real transport over the LAN core: unicast UDP to the member's address.
		[MonoModReplace]
		public Result ReceivePacket(ref ReceivePacketOptions options, ref ProductUserId outPeerId, ref SocketId outSocketId, out byte outChannel, ArraySegment<byte> outData, out uint outBytesWritten)
		{
			outChannel = 0; outBytesWritten = 0;
			LanPacket p = LobbyBridge.Net.DequeuePacket();
			if (p == null) return Result.NotFound;
			LobbyBridge.NotePacketReceived(p.FromId, p.Socket);
			outPeerId = new ProductUserId(MciLan.HandleForId(p.FromId));
			outSocketId = new SocketId { SocketName = p.Socket };
			outChannel = p.Channel;
			int n = p.Data.Length;
			if (outData.Array != null)
			{
				if (n > outData.Count) n = outData.Count;
				Array.Copy(p.Data, 0, outData.Array, outData.Offset, n);
			}
			outBytesWritten = (uint)n;
			return Result.Success;
		}

		[MonoModReplace]
		public Result GetNextReceivedPacketSize(ref GetNextReceivedPacketSizeOptions options, out uint outPacketSizeBytes)
		{
			LanPacket p = LobbyBridge.Net.PeekPacket();
			outPacketSizeBytes = (p != null) ? (uint)p.Data.Length : 0U;
			return (p != null) ? Result.Success : Result.NotFound;
		}

		[MonoModReplace]
		public Result SendPacket(ref SendPacketOptions options)
		{
			string to = (options.RemoteUserId != null) ? MciLan.IdForHandle(options.RemoteUserId.InnerHandle) : null;
			string sock = options.SocketId.HasValue ? (string)options.SocketId.Value.SocketName : "";
			byte[] data = new byte[options.Data.Count];
			if (options.Data.Array != null) Array.Copy(options.Data.Array, options.Data.Offset, data, 0, options.Data.Count);
			bool reliable = options.Reliability != PacketReliability.UnreliableUnordered;
			bool ok = reliable
				? LobbyBridge.Net.SendPacketReliable(to, options.Channel, sock, data)
				: LobbyBridge.Net.SendPacket(to, options.Channel, sock, data);
			if (!ok) return Result.NotFound;
			LobbyBridge.NotePacketSent(to, sock);
			return Result.Success;
		}
		[MonoModReplace] public Result AcceptConnection(ref AcceptConnectionOptions options) { return Result.Success; }
		[MonoModReplace] public Result CloseConnection(ref CloseConnectionOptions options) { return Result.Success; }
		[MonoModReplace] public Result CloseConnections(ref CloseConnectionsOptions options) { return Result.Success; }
		[MonoModReplace]
		public ulong AddNotifyPeerConnectionRequest(ref AddNotifyPeerConnectionRequestOptions options, object clientData, OnIncomingConnectionRequestCallback connectionRequestHandler)
		{
			LobbyBridge.SetConnReqCb(connectionRequestHandler, clientData);
			return 1UL;
		}
		[MonoModReplace] public ulong AddNotifyPeerConnectionClosed(ref AddNotifyPeerConnectionClosedOptions options, object clientData, OnRemoteConnectionClosedCallback connectionClosedHandler) { return 2UL; }
		[MonoModReplace]
		public ulong AddNotifyPeerConnectionEstablished(ref AddNotifyPeerConnectionEstablishedOptions options, object clientData, OnPeerConnectionEstablishedCallback connectionEstablishedHandler)
		{
			LobbyBridge.SetConnEstCb(connectionEstablishedHandler, clientData);
			return 3UL;
		}
		[MonoModReplace] public ulong AddNotifyPeerConnectionInterrupted(ref AddNotifyPeerConnectionInterruptedOptions options, object clientData, OnPeerConnectionInterruptedCallback connectionInterruptedHandler) { return 4UL; }
		[MonoModReplace] public void RemoveNotifyPeerConnectionRequest(ulong notificationId) { }
		[MonoModReplace] public void RemoveNotifyPeerConnectionClosed(ulong notificationId) { }
		[MonoModReplace] public void RemoveNotifyPeerConnectionEstablished(ulong notificationId) { }
		[MonoModReplace] public void RemoveNotifyPeerConnectionInterrupted(ulong notificationId) { }
	}
}

namespace Epic.OnlineServices.Sanctions
{
	// HostGame gates lobby creation behind a sanctions check. No sanctions on a LAN.
	[MonoModPatch("Epic.OnlineServices.Sanctions.SanctionsInterface")]
	class patch_SanctionsInterface : Handle
	{
		[MonoModReplace]
		public void QueryActivePlayerSanctions(ref QueryActivePlayerSanctionsOptions options, object clientData, OnQueryActivePlayerSanctionsCallback completionDelegate)
		{
			ProductUserId target = options.TargetUserId;
			ProductUserId local = options.LocalUserId;
			MciLan.Post(delegate
			{
				QueryActivePlayerSanctionsCallbackInfo info = new QueryActivePlayerSanctionsCallbackInfo
				{ ResultCode = Result.Success, ClientData = clientData, TargetUserId = target, LocalUserId = local };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public uint GetPlayerSanctionCount(ref GetPlayerSanctionCountOptions options)
		{
			return 0U;
		}

		[MonoModReplace]
		public Result CopyPlayerSanctionByIndex(ref CopyPlayerSanctionByIndexOptions options, out PlayerSanction? outSanction)
		{
			outSanction = null;
			return Result.NotFound;
		}
	}
}

namespace Epic.OnlineServices.Friends
{
	// No friends list on LAN; empty results keep the friends UI harmless.
	[MonoModPatch("Epic.OnlineServices.Friends.FriendsInterface")]
	class patch_FriendsInterface : Handle
	{
		[MonoModReplace]
		public void QueryFriends(ref QueryFriendsOptions options, object clientData, OnQueryFriendsCallback completionDelegate)
		{
			EpicAccountId local = options.LocalUserId;
			MciLan.Post(delegate
			{
				QueryFriendsCallbackInfo info = new QueryFriendsCallbackInfo
				{ ResultCode = Result.Success, ClientData = clientData, LocalUserId = local };
				completionDelegate(ref info);
			});
		}

		[MonoModReplace]
		public int GetFriendsCount(ref GetFriendsCountOptions options)
		{
			return 0;
		}
	}
}

namespace Paris.Engine.Networking
{
	// Stock GetLocalName needs Steam or a resolved Epic account - neither exists on LAN,
	// so it returns "" and every player shows up nameless. Use the device name instead.
	class patch_NetworkManager : NetworkManager
	{
		[MonoModReplace]
		private string GetLocalName()
		{
			return MciLan.DisplayName;
		}
	}
}

namespace Paris.Engine
{
	// Not Steam/Epic sessions - suppress the platform icons (items hide unknown names).
	[MonoModPatch("Paris.Engine.PlatformsExtraInfo")]
	static class patch_PlatformsExtraInfo
	{
		[MonoModReplace]
		public static string GetPlatformIcon(Platforms platform)
		{
			return "";
		}
	}
}

namespace Paris.Engine.Localisation
{
	// Swap display strings at the localization choke point (covers both lookup paths).
	class patch_LocManager : LocManager
	{
		private static string MciLanText(string s)
		{
			switch (s)
			{
				case "Online": return "LAN";
				case "ONLINE": return "LAN";
				default: return s;
			}
		}

		public extern string orig_GetString(int stringIndex);
		public new string GetString(int stringIndex)
		{
			return MciLanText(orig_GetString(stringIndex));
		}

		public extern string orig_GetString(string locID);
		public new string GetString(string locID)
		{
			return MciLanText(orig_GetString(locID));
		}
	}
}
