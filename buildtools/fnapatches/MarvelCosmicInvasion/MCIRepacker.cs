using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// Re-encodes MCI's RGBA textures in place for low-memory devices
// R8 for palette-indexed art and small fonts, ASTC for everything else
namespace MCIRepacker
{
    class SkippedAssetFile : Exception
    {
        public SkippedAssetFile(string msg) : base(msg) {}
    }

    class TextureData
    {
        public int format;
        public int width;
        public int height;
        public byte[] level0;
    }

    class Program
    {
        // XNB SurfaceFormat indices. 0-24 are stock XNA/FNA; 25-28 are
        // JohnnyonFlame's ASTC convention; 29 is the RHH R8 extension. The
        // bundled libFNA3D maps all four ASTC block sizes (see fna3d-astc-r8.patch).
        const int FMT_COLOR   = 0;
        const int FMT_ASTC4x4 = 25;
        const int FMT_ASTC5x5 = 26;
        const int FMT_ASTC6x6 = 27;
        const int FMT_ASTC8x8 = 28;
        const int FMT_R8      = 29;

        public static int count_done = 0;
        public static int total;
        public static string assetPath;

        [DllImport("astcUtil.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int convert_texture(int w, int h, int len, uint blk_w, uint blk_h, IntPtr in_tex, IntPtr out_tex);

        static int Read7Bit(BinaryReader r)
        {
            int result = 0, shift = 0;
            while (true)
            {
                byte b = r.ReadByte();
                result |= (b & 0x7F) << shift;
                if ((b & 0x80) == 0)
                    return result;
                shift += 7;
            }
        }

        static void Write7Bit(BinaryWriter w, int value)
        {
            uint v = (uint)value;
            while (v >= 0x80)
            {
                w.Write((byte)(v | 0x80));
                v >>= 7;
            }
            w.Write((byte)v);
        }

        // Parse an uncompressed XNB stream into TextureData.
        // Throws SkippedAssetFile for non-textures and already-encoded files.
        static TextureData ReadTextureAsset(Stream stream)
        {
            var r = new BinaryReader(stream);
            byte[] magic = r.ReadBytes(3);
            if (magic.Length != 3 || magic[0] != 'X' || magic[1] != 'N' || magic[2] != 'B')
                throw new SkippedAssetFile("Not an XNB file.");
            r.ReadByte();                       /* target platform */
            r.ReadByte();                       /* version */
            byte flags = r.ReadByte();
            r.ReadUInt32();                     /* file size */
            if ((flags & 0xC0) != 0)
                throw new SkippedAssetFile("LZX/LZ4-compressed XNB unsupported (MCI has none).");

            int readerCount = Read7Bit(r);
            bool isTexture = false;
            for (int i = 0; i < readerCount; i++)
            {
                string reader = r.ReadString();
                r.ReadInt32();                  /* reader version */
                if (i == 0 && reader.Contains("Texture2DReader"))
                    isTexture = true;
            }
            if (!isTexture)
                throw new SkippedAssetFile("Not a Texture2D asset.");
            Read7Bit(r);                        /* shared resource count */
            Read7Bit(r);                        /* primary type id */

            var t = new TextureData();
            t.format = r.ReadInt32();
            t.width  = r.ReadInt32();
            t.height = r.ReadInt32();
            r.ReadInt32();                      /* mip count */
            if (t.format != FMT_COLOR)
                throw new SkippedAssetFile("Texture already encoded.");
            uint len = r.ReadUInt32();
            t.level0 = r.ReadBytes((int)len);   /* extra mips are dropped, like FNARepacker */
            if (t.level0.Length != len || len != (uint)t.width * (uint)t.height * 4)
                throw new SkippedAssetFile("Unexpected Color payload size.");
            return t;
        }

        // Same layout FNARepacker emits: XNB v5, 'w' platform, uncompressed,
        // one Texture2DReader, single mip
        static void WriteTextureXNB(Stream output, int format, int width, int height, byte[] payload)
        {
            var w = new BinaryWriter(output);
            w.Write(Encoding.ASCII.GetBytes("XNBw"));
            w.Write((byte)5);
            w.Write((byte)0x00);
            w.Write((UInt32)0);                 /* patched with real size below */
            Write7Bit(w, 1);
            w.Write("Microsoft.Xna.Framework.Content.Texture2DReader");
            w.Write((Int32)0);
            Write7Bit(w, 0);
            Write7Bit(w, 1);
            w.Write((Int32)format);
            w.Write((Int32)width);
            w.Write((Int32)height);
            w.Write((Int32)1);
            w.Write((UInt32)payload.Length);
            w.Write(payload);

            UInt32 size = (UInt32)output.Position;
            output.Seek(0x6, SeekOrigin.Begin);
            w.Write(size);
            w.Flush();
        }

        static byte[] EncodeR8(TextureData t)
        {
            // Keep only the red channel - bit-exact for the palette shaders,
            // and the RRRR swizzle in libFNA3D restores .y/.z/.w for fonts.
            byte[] outp = new byte[t.width * t.height];
            byte[] src = t.level0;
            for (int i = 0, j = 0; i < outp.Length; i++, j += 4)
                outp[i] = src[j];
            return outp;
        }

        unsafe static byte[] EncodeASTC(TextureData t, uint blk)
        {
            long blocks = ((t.width + blk - 1) / blk) * ((t.height + blk - 1) / blk);
            byte[] astc = new byte[16 * blocks];
            int ret;
            fixed (byte* src = t.level0)
            fixed (byte* dst = astc)
            {
                ret = convert_texture(t.width, t.height, astc.Length, blk, blk, (IntPtr)src, (IntPtr)dst);
            }
            if (ret != 1)
                throw new Exception("Failed to encode ASTC!");
            return astc;
        }

        // Classification: a directory is "indexed" when a palette strip lives there
        // and some animation blob references it (the engine's real is-indexed signal)
        static bool IsPaletteStrip(string file)
        {
            string n = Path.GetFileName(file);
            return n.EndsWith("Palette.zxnb") || n.EndsWith("Palette.xnb");
        }

        static bool DirIsIndexed(string dir)
        {
            string palBase = null;
            foreach (var f in Directory.GetFiles(dir))
                if (IsPaletteStrip(f)) { palBase = Path.GetFileNameWithoutExtension(f); break; }
            if (palBase == null)
                return false;                       // no palette here at all
            foreach (var f in Directory.GetFiles(dir))
            {
                string ext = Path.GetExtension(f).ToLower();
                if (ext != ".zpbn" && ext != ".pbn")
                    continue;
                byte[] anim;
                try { anim = ReadAnimBytes(f, ext == ".zpbn"); }
                catch { continue; }
                if (ContainsAscii(anim, palBase))    // ShaderPaletteFile -> "<...>Palette"
                    return true;
            }
            return false;
        }

        // ParisSerializer animation blobs: .zpbn is raw-DEFLATE compressed
        // (same as the .zxnb textures), .pbn is stored plain.
        static byte[] ReadAnimBytes(string file, bool compressed)
        {
            using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read))
            using (var ms = new MemoryStream())
            {
                if (compressed)
                {
                    using (var d = new DeflateStream(fs, CompressionMode.Decompress))
                        d.CopyTo(ms);
                }
                else
                {
                    fs.CopyTo(ms);
                }
                return ms.ToArray();
            }
        }

        static bool ContainsAscii(byte[] hay, string needle)
        {
            byte[] n = Encoding.ASCII.GetBytes(needle);
            if (n.Length == 0 || hay.Length < n.Length)
                return false;
            for (int i = 0; i <= hay.Length - n.Length; i++)
            {
                int j = 0;
                while (j < n.Length && hay[i + j] == n[j]) j++;
                if (j == n.Length)
                    return true;
            }
            return false;
        }

        static bool AlphaAllOpaque(TextureData t)
        {
            byte[] s = t.level0;
            for (int i = 3; i < s.Length; i += 4)
                if (s[i] == 0)
                    return false;
            return true;
        }

        static bool IsFontPath(string file)
        {
            return file.Replace('\\', '/').Contains("/Fonts/");
        }

        static uint AstcBlock(string file)
        {
            string f = file.Replace('\\', '/');

            if (f.Contains("/Menu/") || f.Contains("/HUD/") || f.Contains("Menu"))
                return 4;
            if (f.Contains("/Players/") || f.Contains("/Bosses/"))
                return 5;
            if (f.Contains("/BG/") || f.Contains("Level") || f.Contains("Tileset") ||
                f.Contains("/Enemies/") || f.Contains("Cutscene") ||
                f.Contains("/FX/") || f.Contains("/Particles/") || f.Contains("/Trap/") ||
                f.Contains("/Hazard/") || f.Contains("/Spawn/") || f.Contains("/Breakable/"))
                return 6;
            return 4;
        }

        static void ProcessFile(string file, bool indexDir)
        {
            if (IsPaletteStrip(file))
                throw new SkippedAssetFile("Palette strip, kept as RGBA.");
            if (file.Replace('\\', '/').Contains("/Global/"))
                throw new SkippedAssetFile("Global support texture, kept as RGBA.");

            bool wasZ = file.EndsWith(".zxnb");
            TextureData t;
            using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read))
            {
                if (wasZ)
                {
                    using (var deflate = new DeflateStream(fs, CompressionMode.Decompress))
                    using (var ms = new MemoryStream())
                    {
                        deflate.CopyTo(ms);
                        ms.Position = 0;
                        t = ReadTextureAsset(ms);
                    }
                }
                else
                {
                    t = ReadTextureAsset(fs);
                }
            }

            string kind;
            int format;
            byte[] payload;
            bool isFont = IsFontPath(file);
            bool bigFont = isFont && (t.width >= 1024 || t.height >= 1024);
            bool r8 = (isFont && !bigFont) || (!isFont && indexDir && AlphaAllOpaque(t));
            if (r8)
            {
                kind = isFont ? "R8/font" : "R8/index";
                format = FMT_R8;
                payload = EncodeR8(t);
            }
            else
            {
                if (t.width < 128 || t.height < 128)
                    throw new SkippedAssetFile("Asset too small!");
                uint blk = bigFont ? 6u : AstcBlock(file);
                kind = "ASTC" + blk + "x" + blk + (isFont ? "/font" : "");
                switch (blk)
                {
                    case 8:  format = FMT_ASTC8x8; break;
                    case 6:  format = FMT_ASTC6x6; break;
                    case 5:  format = FMT_ASTC5x5; break;
                    default: format = FMT_ASTC4x4; break;
                }
                payload = EncodeASTC(t, blk);
            }

            string outPath = wasZ ? Path.ChangeExtension(file, ".xnb") : file;
            string tmpPath = outPath + "_tmp";
            float percent = (float)count_done / (float)total * 100.0f;
            Console.Out.WriteLine("'" + RelPath(outPath) + "' [" + (int)percent + "%] " + kind + " -> w: " + t.width + ", h: " + t.height);
            try
            {
                using (var output = File.Open(tmpPath, FileMode.Create))
                    WriteTextureXNB(output, format, t.width, t.height, payload);
                if (File.Exists(outPath))
                    File.Delete(outPath);
                File.Move(tmpPath, outPath);
            }
            catch
            {
                File.Delete(tmpPath);
                throw;
            }
            // conversion is atomic: only drop the source once the .xnb is in place
            if (wasZ)
                File.Delete(file);
        }

        static string RelPath(string p)
        {
            string root = assetPath.TrimEnd('/', '\\');
            if (p.StartsWith(root))
                return p.Substring(root.Length).TrimStart('/', '\\');
            return p;
        }

        static void Main(string[] args)
        {
            assetPath = args[0];
            var work = new List<KeyValuePair<string, bool>>();
            var dirs = new Stack<string>();
            dirs.Push(assetPath);
            while (dirs.Count > 0)
            {
                string dir = dirs.Pop();
                bool indexDir = DirIsIndexed(dir);
                foreach (var f in Directory.GetFiles(dir))
                {
                    string ext = Path.GetExtension(f).ToLower();
                    if (ext == ".xnb" || ext == ".zxnb")
                        work.Add(new KeyValuePair<string, bool>(f, indexDir));
                }
                foreach (var d in Directory.GetDirectories(dir))
                    dirs.Push(d);
            }

            total = work.Count;
            int failed = 0;
            foreach (var item in work)
            {
                try
                {
                    ProcessFile(item.Key, item.Value);
                }
                catch (SkippedAssetFile)
                {
                    // kept as-is by design
                }
                catch (Exception e)
                {
                    failed++;
                    Console.Out.WriteLine("File " + item.Key + " failed to be re-encoded:");
                    Console.Out.WriteLine(e.ToString());
                }
                finally
                {
                    count_done++;
                    GC.Collect();
                }
            }
            Console.Out.WriteLine("Repack finished: " + count_done + " files visited, " + failed + " failures.");
            if (failed > 0)
                Environment.Exit(1);
        }
    }
}
