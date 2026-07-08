// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jeod
//
// libEOSSDK-LAN - LAN lobby + transport core behind the EOS shim.
// Kept free of Epic types so it can become a native lib shared by other EOS ports.
//
// One UDP socket does everything:
//   host    broadcasts a lobby snapshot beacon every 1s (id, members, attributes)
//   client  unicasts a JOIN heartbeat to the host every 1s (name, platform, member attrs)
//   both    exchange game packets (PKT unreliable, RPK/ACK reliable-ordered)
//
// Wire messages are "MCILAN1:" + ':'-delimited fields, base64 where content is free-form:
//   LOBBY:<lobbyId>:<hostId>:<snapshotB64>
//   JOIN:<lobbyId>:<clientId>:<nameB64>:<plat>:<attrsB64>
//   LEAVE:<lobbyId>:<clientId>
//   PKT:<fromId>:<channel>:<socketB64>:<payloadB64>
//   RPK:<fromId>:<channel>:<socketB64>:<seq>:<payloadB64>
//   ACK:<ackerId>:<seq>
// Snapshot records: H|max|bucket  M|id|name|plat|addr|attrs  A|key|type|value
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Net.NetworkInformation;
using System.Text;
using System.Threading;

namespace Paris.Engine.EOSLan
{
	// A typed lobby/attribute value mirroring EOS's int64/bool/double/string union.
	// Only the field matching Type is meaningful.
	class LanAttr
	{
		public char Type;   // 'i' int64, 'b' bool, 'd' double, 's' string
		public long IntValue;
		public bool BoolValue;
		public double DoubleValue;
		public string StringValue;

		public static LanAttr Int(long value) { return new LanAttr { Type = 'i', IntValue = value }; }
		public static LanAttr Bool(bool value) { return new LanAttr { Type = 'b', BoolValue = value }; }
		public static LanAttr Dbl(double value) { return new LanAttr { Type = 'd', DoubleValue = value }; }
		public static LanAttr Str(string value) { return new LanAttr { Type = 's', StringValue = value ?? "" }; }

		// Culture-invariant textual form for the wire.
		public string ToWireString()
		{
			switch (Type)
			{
				case 'i': return IntValue.ToString(CultureInfo.InvariantCulture);
				case 'b': return BoolValue ? "1" : "0";
				case 'd': return DoubleValue.ToString("R", CultureInfo.InvariantCulture);
				default: return StringValue ?? "";
			}
		}

		public static LanAttr Parse(char type, string text)
		{
			CultureInfo invariant = CultureInfo.InvariantCulture;
			switch (type)
			{
				case 'i':
				{
					long value;
					long.TryParse(text, NumberStyles.Integer, invariant, out value);
					return Int(value);
				}
				case 'b':
					return Bool(text == "1" || text == "true");
				case 'd':
				{
					double value;
					double.TryParse(text, NumberStyles.Float, invariant, out value);
					return Dbl(value);
				}
				default:
					return Str(text);
			}
		}
	}

	class LanMember
	{
		public string Id;
		public string Name = "";
		public int Platform;
		public IPEndPoint Endpoint;    // where this member lives (host learns from JOINs; clients from the snapshot)
		public long LastSeenMs;        // host-side: for timeout eviction
		// Member attributes (GUESTS/CHANNEL/NAME/PLATFORM). GUESTS gates the game's member sync.
		public readonly Dictionary<string, LanAttr> Attributes = new Dictionary<string, LanAttr>();
	}

	// A received P2P payload, consumed by the EOS P2PInterface shim.
	class LanPacket
	{
		public string FromId;
		public byte Channel;
		public string Socket;
		public byte[] Data;
	}

	// Reliable-ordered state per peer: resend until acked, deliver in order exactly once.
	class ReliableStream
	{
		public int NextOutgoingSeq = 1;
		public readonly Dictionary<int, PendingSend> Unacked = new Dictionary<int, PendingSend>();
		public int NextExpectedSeq = 1;
		public readonly Dictionary<int, LanPacket> OutOfOrder = new Dictionary<int, LanPacket>();
	}

	class PendingSend
	{
		public string ToId;
		public string Message;
		public long LastSentMs;
	}

	// A discovered lobby (search result / joined snapshot).
	class LanLobbyInfo
	{
		public string LobbyId;
		public string HostId;
		public uint MaxMembers = 4;
		public string Bucket = "";
		public readonly List<LanMember> Members = new List<LanMember>();   // ordered
		public readonly Dictionary<string, LanAttr> Attributes = new Dictionary<string, LanAttr>();
	}

	class MciLanNet
	{
		public const int PORT = 55123;
		const string Prefix = "MCILAN1:";
		const int TxTickMs = 200;          // resend granularity
		const int HeartbeatMs = 1000;      // beacon / JOIN heartbeat cadence
		const int MemberTimeoutMs = 5000;
		const int ResendMs = 250;
		const int OutOfOrderBufferCap = 256;
		const int InboxFloodCap = 512;

		readonly object stateLock = new object();
		UdpClient socket;
		List<IPEndPoint> broadcastTargets;
		long clockBaseTicks;    // Environment.TickCount can wrap; we only need deltas

		// local identity
		public string LocalId, LocalName = "Player";
		public int LocalPlatform = 258;

		// current lobby (host or joined-as-client)
		public bool IsHost, InLobby;
		public string LobbyId, HostId;
		public uint MaxMembers = 4;
		public string Bucket = "";
		readonly List<LanMember> members = new List<LanMember>();          // ordered, host is authoritative
		readonly Dictionary<string, LanAttr> lobbyAttributes = new Dictionary<string, LanAttr>();

		// client-side: host endpoint we heartbeat to, and whether we've been acknowledged
		IPEndPoint hostEndpoint;
		public bool JoinAcknowledged;

		// last-known endpoint per peer, learned from any datagram - replies must not
		// have to wait for membership to propagate
		readonly Dictionary<string, IPEndPoint> peerEndpoints = new Dictionary<string, IPEndPoint>();

		// search
		bool searching;
		string searchFilterId;    // non-null => join-by-code
		readonly Dictionary<string, LanLobbyInfo> searchResults = new Dictionary<string, LanLobbyInfo>();

		// raised on the Rx thread; the adapter re-posts onto Platform.Tick
		public event Action<LanMember> MemberJoined;
		public event Action<string> MemberLeft;
		public event Action LobbyChanged;
		public event Action<string> MemberChanged;   // a member's attributes changed

		// our member attributes, carried by JOIN heartbeats and beacons
		readonly Dictionary<string, LanAttr> localMemberAttributes = new Dictionary<string, LanAttr>();

		// inbound game packets waiting for the shim, and reliable-delivery state per peer
		readonly Queue<LanPacket> inbox = new Queue<LanPacket>();
		readonly Dictionary<string, ReliableStream> reliableStreams = new Dictionary<string, ReliableStream>();

		long NowMs() { return (Environment.TickCount - clockBaseTicks) & 0x7fffffffL; }

		public void Start()
		{
			clockBaseTicks = Environment.TickCount;
			socket = new UdpClient();
			socket.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
			socket.EnableBroadcast = true;
			socket.Client.Bind(new IPEndPoint(IPAddress.Any, PORT));
			broadcastTargets = FindBroadcastTargets(PORT);
			new Thread(ReceiveLoop) { IsBackground = true, Name = "MciLanRx" }.Start();
			new Thread(SendLoop) { IsBackground = true, Name = "MciLanTx" }.Start();
		}

		// Host-side lobby management
		public string CreateLobby(string lobbyId, uint maxMembers, string bucket)
		{
			lock (stateLock)
			{
				IsHost = true; InLobby = true;
				LobbyId = string.IsNullOrEmpty(lobbyId) ? GenerateLobbyCode() : lobbyId;
				HostId = LocalId;
				MaxMembers = maxMembers > 0 ? maxMembers : 4;
				Bucket = bucket ?? "";
				members.Clear(); lobbyAttributes.Clear(); peerEndpoints.Clear(); reliableStreams.Clear(); inbox.Clear();
				LanMember self = new LanMember { Id = LocalId, Name = LocalName, Platform = LocalPlatform };
				foreach (var attr in localMemberAttributes) self.Attributes[attr.Key] = attr.Value;
				members.Add(self);
			}
			return LobbyId;
		}

		public void SetLobbyAttr(string key, LanAttr value) { lock (stateLock) lobbyAttributes[key] = value; }
		public void SetMaxMembers(uint max) { lock (stateLock) MaxMembers = max; }
		public void SetBucket(string bucket) { lock (stateLock) Bucket = bucket ?? ""; }

		public void SetLocalName(string name)
		{
			if (string.IsNullOrEmpty(name)) return;
			lock (stateLock)
			{
				LocalName = name;
				LanMember self = members.Find(candidate => candidate.Id == LocalId);
				if (self != null) self.Name = name;   // host: beacon snapshot picks it up
			}
		}

		public void SetLocalMemberAttrs(List<KeyValuePair<string, LanAttr>> pairs)
		{
			if (pairs == null || pairs.Count == 0) return;
			lock (stateLock)
			{
				foreach (var pair in pairs) localMemberAttributes[pair.Key] = pair.Value;
				LanMember self = members.Find(candidate => candidate.Id == LocalId);
				if (self != null)
					foreach (var pair in pairs) self.Attributes[pair.Key] = pair.Value;
			}
		}

		public LanAttr GetMemberAttr(string memberId, string key)
		{
			lock (stateLock)
			{
				LanMember member = members.Find(candidate => candidate.Id == memberId);
				if (member == null) return null;
				LanAttr value;
				return member.Attributes.TryGetValue(key, out value) ? value : null;
			}
		}

		// Client-side search and join
		public void StartSearch(string filterLobbyId)
		{
			lock (stateLock) { searching = true; searchFilterId = filterLobbyId; searchResults.Clear(); }
		}

		public List<LanLobbyInfo> SearchResults()
		{
			lock (stateLock) { return new List<LanLobbyInfo>(searchResults.Values); }
		}

		public bool Join(string lobbyId)
		{
			LanLobbyInfo info;
			lock (stateLock) { if (!searchResults.TryGetValue(lobbyId, out info)) return false; }
			return Join(info);
		}

		// Join from a snapshot (frozen search result) so a search refresh can't invalidate it.
		public bool Join(LanLobbyInfo info)
		{
			if (info == null || string.IsNullOrEmpty(info.LobbyId)) return false;
			IPEndPoint host;
			string joinMessage;
			lock (stateLock)
			{
				IsHost = false; InLobby = true; JoinAcknowledged = false;
				LobbyId = info.LobbyId; HostId = info.HostId;
				MaxMembers = info.MaxMembers; Bucket = info.Bucket;
				hostEndpoint = info.Members.Count > 0 ? info.Members[0].Endpoint : null;
				// seed member/attr view from the snapshot; refreshed by beacons
				members.Clear(); lobbyAttributes.Clear(); peerEndpoints.Clear(); reliableStreams.Clear(); inbox.Clear();
				foreach (var source in info.Members)
				{
					var copy = new LanMember { Id = source.Id, Name = source.Name, Platform = source.Platform, Endpoint = source.Endpoint };
					foreach (var attr in source.Attributes) copy.Attributes[attr.Key] = attr.Value;
					members.Add(copy);
					if (copy.Endpoint != null) peerEndpoints[copy.Id] = copy.Endpoint;
				}
				foreach (var attr in info.Attributes) lobbyAttributes[attr.Key] = attr.Value;
				searching = false;
				host = hostEndpoint;
				joinMessage = Prefix + "JOIN:" + LobbyId + ":" + LocalId + ":" + ToBase64(LocalName) + ":" + LocalPlatform + ":" + SerializeAttributes(localMemberAttributes);
			}
			// announce now - the game sends packets right after joining
			if (host != null) Send(joinMessage, new List<IPEndPoint> { host });
			return true;
		}

		public void Leave()
		{
			IPEndPoint host; string lobbyId, myId;
			lock (stateLock)
			{
				if (!InLobby) return;
				host = hostEndpoint; lobbyId = LobbyId; myId = LocalId;
				InLobby = false; IsHost = false; JoinAcknowledged = false;
				members.Clear(); lobbyAttributes.Clear(); peerEndpoints.Clear(); reliableStreams.Clear(); inbox.Clear();
				LobbyId = null; HostId = null; hostEndpoint = null;
			}
			if (host != null) Send(Prefix + "LEAVE:" + lobbyId + ":" + myId, new List<IPEndPoint> { host });
		}

		// Snapshots for the EOS adapter
		public List<LanMember> Members() { lock (stateLock) { return new List<LanMember>(members); } }
		public Dictionary<string, LanAttr> Attributes() { lock (stateLock) { return new Dictionary<string, LanAttr>(lobbyAttributes); } }
		public LanAttr GetAttr(string key) { lock (stateLock) { LanAttr value; return lobbyAttributes.TryGetValue(key, out value) ? value : null; } }
		public int MemberCount() { lock (stateLock) { return members.Count; } }

		// P2P packets - the EOS SendPacket/ReceivePacket back-end
		IPEndPoint ResolveEndpoint(string peerId)   // caller holds stateLock
		{
			LanMember member = members.Find(candidate => candidate.Id == peerId);
			if (member != null && member.Endpoint != null) return member.Endpoint;
			IPEndPoint known;
			if (peerEndpoints.TryGetValue(peerId, out known)) return known;
			if (!IsHost && peerId == HostId) return hostEndpoint;
			return null;
		}

		ReliableStream StreamFor(string peerId)   // caller holds stateLock
		{
			ReliableStream stream;
			if (!reliableStreams.TryGetValue(peerId, out stream)) { stream = new ReliableStream(); reliableStreams[peerId] = stream; }
			return stream;
		}

		public bool SendPacket(string toId, byte channel, string socketName, byte[] data)
		{
			if (string.IsNullOrEmpty(toId) || data == null) return false;
			IPEndPoint dest;
			lock (stateLock) { dest = ResolveEndpoint(toId); }
			if (dest == null) return false;
			string message = Prefix + "PKT:" + LocalId + ":" + channel + ":" + ToBase64(socketName ?? "") + ":" + Convert.ToBase64String(data);
			Send(message, new List<IPEndPoint> { dest });
			return true;
		}

		// Reliable-ordered: sequence + buffer for resend until the peer acks.
		public bool SendPacketReliable(string toId, byte channel, string socketName, byte[] data)
		{
			if (string.IsNullOrEmpty(toId) || data == null) return false;
			IPEndPoint dest; string message;
			lock (stateLock)
			{
				dest = ResolveEndpoint(toId);
				if (dest == null) return false;
				ReliableStream stream = StreamFor(toId);
				int seq = stream.NextOutgoingSeq++;
				message = Prefix + "RPK:" + LocalId + ":" + channel + ":" + ToBase64(socketName ?? "") + ":" + seq + ":" + Convert.ToBase64String(data);
				stream.Unacked[seq] = new PendingSend { ToId = toId, Message = message, LastSentMs = NowMs() };
			}
			Send(message, new List<IPEndPoint> { dest });
			return true;
		}

		void ResendUnacked()   // called from SendLoop
		{
			List<PendingSend> due = null;
			lock (stateLock)
			{
				long now = NowMs();
				foreach (var stream in reliableStreams.Values)
				{
					foreach (var pending in stream.Unacked.Values)
					{
						if (now - pending.LastSentMs >= ResendMs)
						{
							pending.LastSentMs = now;
							if (due == null) due = new List<PendingSend>();
							due.Add(pending);
						}
					}
				}
			}
			if (due == null) return;
			foreach (var pending in due)
			{
				IPEndPoint dest;
				lock (stateLock) { dest = ResolveEndpoint(pending.ToId); }
				if (dest != null) Send(pending.Message, new List<IPEndPoint> { dest });
			}
		}

		void HandleReliablePacket(string body, IPEndPoint from)
		{
			// RPK:<fromId>:<channel>:<socketB64>:<seq>:<payloadB64>
			string[] fields = body.Split(new char[] { ':' }, 6);
			if (fields.Length < 6) return;
			byte channel; byte.TryParse(fields[2], out channel);
			int seq; if (!int.TryParse(fields[4], out seq)) return;
			byte[] payload;
			try { payload = Convert.FromBase64String(fields[5]); } catch { return; }
			// always ack - a duplicate means our previous ack was lost
			Send(Prefix + "ACK:" + LocalId + ":" + seq, new List<IPEndPoint> { new IPEndPoint(from.Address, PORT) });
			var packet = new LanPacket { FromId = fields[1], Channel = channel, Socket = FromBase64(fields[3]), Data = payload };
			lock (stateLock)
			{
				if (!InLobby) return;
				peerEndpoints[packet.FromId] = new IPEndPoint(from.Address, PORT);
				LanMember member = members.Find(candidate => candidate.Id == packet.FromId);
				if (member != null) member.LastSeenMs = NowMs();
				ReliableStream stream = StreamFor(packet.FromId);
				if (seq < stream.NextExpectedSeq) return;   // duplicate of something already delivered
				if (seq == stream.NextExpectedSeq)
				{
					inbox.Enqueue(packet);
					stream.NextExpectedSeq++;
					LanPacket buffered;
					while (stream.OutOfOrder.TryGetValue(stream.NextExpectedSeq, out buffered))   // drain any buffered run
					{
						stream.OutOfOrder.Remove(stream.NextExpectedSeq);
						inbox.Enqueue(buffered);
						stream.NextExpectedSeq++;
					}
					return;
				}
				if (stream.OutOfOrder.Count < OutOfOrderBufferCap) stream.OutOfOrder[seq] = packet;   // out of order - hold
			}
		}

		void HandleAck(string body)
		{
			// ACK:<ackerId>:<seq>
			string[] fields = body.Split(':');
			if (fields.Length < 3) return;
			int seq; if (!int.TryParse(fields[2], out seq)) return;
			lock (stateLock)
			{
				ReliableStream stream;
				if (reliableStreams.TryGetValue(fields[1], out stream)) stream.Unacked.Remove(seq);
			}
		}

		public LanPacket PeekPacket() { lock (stateLock) { return inbox.Count > 0 ? inbox.Peek() : null; } }
		public LanPacket DequeuePacket() { lock (stateLock) { return inbox.Count > 0 ? inbox.Dequeue() : null; } }

		void HandlePacket(string body, IPEndPoint from)
		{
			// PKT:<fromId>:<channel>:<socketB64>:<payloadB64>
			string[] fields = body.Split(new char[] { ':' }, 5);
			if (fields.Length < 5) return;
			byte channel; byte.TryParse(fields[2], out channel);
			byte[] payload;
			try { payload = Convert.FromBase64String(fields[4]); } catch { return; }
			var packet = new LanPacket { FromId = fields[1], Channel = channel, Socket = FromBase64(fields[3]), Data = payload };
			lock (stateLock)
			{
				if (!InLobby) return;
				if (inbox.Count > InboxFloodCap) inbox.Dequeue();   // drop oldest under flood
				inbox.Enqueue(packet);
				// any datagram teaches us the sender's endpoint and counts as a heartbeat
				peerEndpoints[packet.FromId] = new IPEndPoint(from.Address, PORT);
				LanMember member = members.Find(candidate => candidate.Id == packet.FromId);
				if (member != null) { member.LastSeenMs = NowMs(); if (member.Endpoint == null) member.Endpoint = new IPEndPoint(from.Address, PORT); }
			}
		}

		// Networking threads
		void SendLoop()
		{
			int ticksSinceHeartbeat = 0;
			while (true)
			{
				try
				{
					ResendUnacked();   // reliable resends need finer granularity than the heartbeat
					if (++ticksSinceHeartbeat * TxTickMs >= HeartbeatMs)
					{
						ticksSinceHeartbeat = 0;
						string message = null; List<IPEndPoint> destinations = null;
						lock (stateLock)
						{
							// don't advertise until the lobby attributes are committed -
							// clients validate VERSION/DLC/bucket from the snapshot
							if (InLobby && IsHost && lobbyAttributes.Count > 0)
							{
								message = Prefix + "LOBBY:" + LobbyId + ":" + HostId + ":" + BuildSnapshot();
								destinations = broadcastTargets;
							}
							else if (InLobby && !IsHost && hostEndpoint != null)
							{
								message = Prefix + "JOIN:" + LobbyId + ":" + LocalId + ":" + ToBase64(LocalName) + ":" + LocalPlatform + ":" + SerializeAttributes(localMemberAttributes);
								destinations = new List<IPEndPoint> { hostEndpoint };
							}
							if (IsHost) EvictStaleMembers();
						}
						if (message != null) Send(message, destinations);
					}
				}
				catch { }
				Thread.Sleep(TxTickMs);
			}
		}

		void ReceiveLoop()
		{
			while (true)
			{
				try
				{
					var from = new IPEndPoint(IPAddress.Any, 0);
					string message = Encoding.UTF8.GetString(socket.Receive(ref from));
					if (!message.StartsWith(Prefix)) continue;
					string body = message.Substring(Prefix.Length);
					int firstColon = body.IndexOf(':');
					string verb = firstColon < 0 ? body : body.Substring(0, firstColon);
					if (verb == "PKT") HandlePacket(body, from);
					else if (verb == "RPK") HandleReliablePacket(body, from);
					else if (verb == "ACK") HandleAck(body);
					else if (verb == "LOBBY") HandleBeacon(body, from);
					else if (verb == "JOIN") HandleJoin(body, from);
					else if (verb == "LEAVE") HandleLeave(body);
				}
				catch (Exception) { Thread.Sleep(200); }
			}
		}

		void HandleBeacon(string body, IPEndPoint from)
		{
			// LOBBY:<lobbyId>:<hostId>:<snapshotB64>
			string[] fields = body.Split(new char[] { ':' }, 4);
			if (fields.Length < 4) return;
			string lobbyId = fields[1], hostId = fields[2];
			if (hostId == LocalId) return;   // our own beacon (host) - ignore
			LanLobbyInfo info = ParseSnapshot(lobbyId, hostId, fields[3], from);
			bool joinJustAcknowledged = false;
			var changedMembers = new List<string>();
			lock (stateLock)
			{
				if (searching && (searchFilterId == null || searchFilterId == lobbyId))
					searchResults[lobbyId] = info;
				if (InLobby && !IsHost && lobbyId == LobbyId)
				{
					// diff member attrs so the adapter can fire member-update notifies
					var previousById = new Dictionary<string, LanMember>();
					foreach (var member in members) previousById[member.Id] = member;
					foreach (var member in info.Members)
					{
						LanMember previous;
						if (previousById.TryGetValue(member.Id, out previous) && !AttributesEqual(previous.Attributes, member.Attributes))
							changedMembers.Add(member.Id);
					}
					// refresh our view from the host's authoritative snapshot
					members.Clear(); foreach (var member in info.Members) members.Add(member);
					lobbyAttributes.Clear(); foreach (var attr in info.Attributes) lobbyAttributes[attr.Key] = attr.Value;
					MaxMembers = info.MaxMembers; Bucket = info.Bucket;
					if (info.Members.Count > 0) hostEndpoint = info.Members[0].Endpoint ?? hostEndpoint;
					// keep our own freshest attrs (heartbeat may lag a beacon)
					LanMember self = members.Find(candidate => candidate.Id == LocalId);
					if (self != null)
						foreach (var attr in localMemberAttributes) self.Attributes[attr.Key] = attr.Value;
					bool amMember = info.Members.Exists(member => member.Id == LocalId);
					if (amMember && !JoinAcknowledged) { JoinAcknowledged = true; joinJustAcknowledged = true; }
				}
			}
			if (LobbyChanged != null) LobbyChanged();
			if (joinJustAcknowledged && LobbyChanged != null) LobbyChanged();
			if (MemberChanged != null)
				foreach (string id in changedMembers) MemberChanged(id);
		}

		void HandleJoin(string body, IPEndPoint from)
		{
			// JOIN:<lobbyId>:<clientId>:<nameB64>:<plat>[:<attrsB64>]
			string[] fields = body.Split(':');
			if (fields.Length < 5) return;
			string lobbyId = fields[1], clientId = fields[2], name = FromBase64(fields[3]);
			int platform; int.TryParse(fields[4], out platform);
			Dictionary<string, LanAttr> memberAttributes = (fields.Length >= 6) ? ParseAttributes(fields[5]) : new Dictionary<string, LanAttr>();
			LanMember joined = null; bool attributesChanged = false;
			lock (stateLock)
			{
				if (!IsHost || !InLobby || lobbyId != LobbyId) return;
				peerEndpoints[clientId] = new IPEndPoint(from.Address, PORT);
				LanMember member = members.Find(candidate => candidate.Id == clientId);
				if (member == null)
				{
					if (members.Count >= MaxMembers) return;   // full
					member = new LanMember { Id = clientId, Name = name, Platform = platform };
					member.Endpoint = new IPEndPoint(from.Address, PORT);
					member.LastSeenMs = NowMs();
					foreach (var attr in memberAttributes) member.Attributes[attr.Key] = attr.Value;
					members.Add(member);
					joined = member;
				}
				else
				{
					member.LastSeenMs = NowMs(); member.Name = name; member.Endpoint = new IPEndPoint(from.Address, PORT);
					if (!AttributesEqual(member.Attributes, memberAttributes))
					{
						member.Attributes.Clear();
						foreach (var attr in memberAttributes) member.Attributes[attr.Key] = attr.Value;
						attributesChanged = true;
					}
				}
			}
			if (joined != null && MemberJoined != null) MemberJoined(joined);
			if (joined != null && LobbyChanged != null) LobbyChanged();
			if (attributesChanged && MemberChanged != null) MemberChanged(clientId);
		}

		void HandleLeave(string body)
		{
			string[] fields = body.Split(':');
			if (fields.Length < 3) return;
			string lobbyId = fields[1], clientId = fields[2]; bool removed = false;
			lock (stateLock)
			{
				if (!IsHost || lobbyId != LobbyId) return;
				int index = members.FindIndex(candidate => candidate.Id == clientId);
				if (index >= 0) { members.RemoveAt(index); removed = true; reliableStreams.Remove(clientId); peerEndpoints.Remove(clientId); }
			}
			if (removed && MemberLeft != null) MemberLeft(clientId);
			if (removed && LobbyChanged != null) LobbyChanged();
		}

		void EvictStaleMembers()   // caller holds stateLock
		{
			long now = NowMs();
			for (int i = members.Count - 1; i >= 1; i--)   // never evict host (index 0)
			{
				if (now - members[i].LastSeenMs > MemberTimeoutMs)
				{
					string goneId = members[i].Id;
					members.RemoveAt(i);
					reliableStreams.Remove(goneId); peerEndpoints.Remove(goneId);
					if (MemberLeft != null) ThreadPool.QueueUserWorkItem(delegate { MemberLeft(goneId); });
				}
			}
		}

		// Snapshot (de)serialization
		string BuildSnapshot()   // caller holds stateLock
		{
			var builder = new StringBuilder();
			builder.Append("H|").Append(MaxMembers).Append('|').Append(ToBase64(Bucket)).Append('\n');
			foreach (var member in members)
				builder.Append("M|").Append(member.Id).Append('|').Append(ToBase64(member.Name)).Append('|').Append(member.Platform)
				       .Append('|').Append(member.Endpoint != null ? member.Endpoint.Address.ToString() : "-")
				       .Append('|').Append(SerializeAttributes(member.Attributes)).Append('\n');
			foreach (var attr in lobbyAttributes)
				builder.Append("A|").Append(attr.Key).Append('|').Append(attr.Value.Type).Append('|').Append(ToBase64(attr.Value.ToWireString())).Append('\n');
			return ToBase64(builder.ToString());
		}

		LanLobbyInfo ParseSnapshot(string lobbyId, string hostId, string snapshotB64, IPEndPoint from)
		{
			var info = new LanLobbyInfo { LobbyId = lobbyId, HostId = hostId };
			string snapshot = FromBase64(snapshotB64);
			bool firstMember = true;
			foreach (string line in snapshot.Split('\n'))
			{
				if (line.Length == 0) continue;
				string[] parts = line.Split('|');
				if (parts[0] == "H" && parts.Length >= 3)
				{
					uint.TryParse(parts[1], out info.MaxMembers);
					info.Bucket = FromBase64(parts[2]);
				}
				else if (parts[0] == "M" && parts.Length >= 4)
				{
					int platform; int.TryParse(parts[3], out platform);
					var member = new LanMember { Id = parts[1], Name = FromBase64(parts[2]), Platform = platform };
					if (parts.Length >= 5 && parts[4] != "-")   // host publishes each member's address for peer P2P
					{
						try { member.Endpoint = new IPEndPoint(IPAddress.Parse(parts[4]), PORT); } catch { }
					}
					if (parts.Length >= 6)
						foreach (var attr in ParseAttributes(parts[5])) member.Attributes[attr.Key] = attr.Value;
					if (firstMember) { member.Endpoint = new IPEndPoint(from.Address, PORT); firstMember = false; }   // member[0] is the host (beacon source is authoritative)
					info.Members.Add(member);
				}
				else if (parts[0] == "A" && parts.Length >= 4)
					info.Attributes[parts[1]] = LanAttr.Parse(parts[2][0], FromBase64(parts[3]));
			}
			return info;
		}

		static string ToBase64(string text) { return Convert.ToBase64String(Encoding.UTF8.GetBytes(text ?? "")); }
		static string FromBase64(string base64) { try { return Encoding.UTF8.GetString(Convert.FromBase64String(base64)); } catch { return ""; } }

		// member-attr blob: newline-separated "key|type|valueB64" records, base64'd as a whole
		static string SerializeAttributes(Dictionary<string, LanAttr> attributes)
		{
			if (attributes == null || attributes.Count == 0) return ToBase64("");
			var builder = new StringBuilder();
			foreach (var attr in attributes)
				builder.Append(attr.Key).Append('|').Append(attr.Value.Type).Append('|').Append(ToBase64(attr.Value.ToWireString())).Append('\n');
			return ToBase64(builder.ToString());
		}

		static Dictionary<string, LanAttr> ParseAttributes(string blobB64)
		{
			var result = new Dictionary<string, LanAttr>();
			foreach (string line in FromBase64(blobB64).Split('\n'))
			{
				if (line.Length == 0) continue;
				string[] parts = line.Split('|');
				if (parts.Length >= 3 && parts[1].Length > 0)
					result[parts[0]] = LanAttr.Parse(parts[1][0], FromBase64(parts[2]));
			}
			return result;
		}

		static bool AttributesEqual(Dictionary<string, LanAttr> a, Dictionary<string, LanAttr> b)
		{
			if (a.Count != b.Count) return false;
			foreach (var entry in a)
			{
				LanAttr other;
				if (!b.TryGetValue(entry.Key, out other) || other.Type != entry.Value.Type || other.ToWireString() != entry.Value.ToWireString())
					return false;
			}
			return true;
		}

		void Send(string message, List<IPEndPoint> destinations)
		{
			byte[] bytes = Encoding.UTF8.GetBytes(message);
			foreach (var dest in destinations) { try { socket.Send(bytes, bytes.Length, dest); } catch { } }
		}

		string GenerateLobbyCode()
		{
			// short, human-typeable party code (for "Join Party Code")
			const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
			var builder = new StringBuilder();
			int seed = Environment.TickCount ^ (LocalId != null ? LocalId.GetHashCode() : 0);
			for (int i = 0; i < 6; i++)
			{
				seed = seed * 1103515245 + 12345;
				builder.Append(Alphabet[((seed >> 16) & 0x7fff) % Alphabet.Length]);
			}
			return builder.ToString();
		}

		// Every up, non-loopback IPv4 interface's directed broadcast, plus the global
		// 255.255.255.255 - covers multi-subnet setups and odd adapters alike.
		static List<IPEndPoint> FindBroadcastTargets(int port)
		{
			var targets = new List<IPEndPoint> { new IPEndPoint(IPAddress.Broadcast, port) };
			try
			{
				foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
				{
					if (nic.OperationalStatus != OperationalStatus.Up || nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
					foreach (var unicast in nic.GetIPProperties().UnicastAddresses)
					{
						if (unicast.Address.AddressFamily != AddressFamily.InterNetwork) continue;
						byte[] address = unicast.Address.GetAddressBytes();
						byte[] mask;
						try { mask = unicast.IPv4Mask.GetAddressBytes(); } catch { continue; }
						if (mask == null || mask.Length != 4 || (mask[0] | mask[1] | mask[2] | mask[3]) == 0) continue;
						byte[] broadcast = new byte[4];
						for (int i = 0; i < 4; i++) broadcast[i] = (byte)(address[i] | (~mask[i] & 0xff));
						targets.Add(new IPEndPoint(new IPAddress(broadcast), port));
					}
				}
			}
			catch { }
			return targets;
		}
	}
}
