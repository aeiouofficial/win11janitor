using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace Win11Janitor {
    public sealed class ProcessStateSnapshot {
        public int ProcessId { get; set; }
        public long CreationFileTimeUtc { get; set; }
        public string ImagePath { get; set; }
        public uint PowerControlMask { get; set; }
        public uint PowerStateMask { get; set; }
        public uint[] DefaultCpuSets { get; set; }
        public uint SessionId { get; set; }
        public bool IsCritical { get; set; }
    }

    public sealed class CpuSetRecord {
        public uint Id { get; set; }
        public ushort Group { get; set; }
        public byte LogicalProcessorIndex { get; set; }
        public byte CoreIndex { get; set; }
        public byte LastLevelCacheIndex { get; set; }
        public byte NumaNodeIndex { get; set; }
        public byte EfficiencyClass { get; set; }
        public bool Parked { get; set; }
        public bool Allocated { get; set; }
        public bool AllocatedToTargetProcess { get; set; }
        public bool RealTime { get; set; }
    }
    public static class ProcessSessionNative {
        private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
        private const uint PROCESS_SET_INFORMATION = 0x0200;
        private const int ERROR_INSUFFICIENT_BUFFER = 122;
        private const int PROCESS_POWER_THROTTLING = 4;
        private const uint POWER_VERSION = 1;

        [StructLayout(LayoutKind.Sequential)]
        private struct FILETIME {
            public uint Low;
            public uint High;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct PROCESS_POWER_THROTTLING_STATE {
            public uint Version;
            public uint ControlMask;
            public uint StateMask;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr OpenProcess(
            uint desiredAccess, bool inheritHandle, uint processId);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseHandle(IntPtr handle);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessTimes(
            IntPtr process, out FILETIME creation, out FILETIME exit,
            out FILETIME kernel, out FILETIME user);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool QueryFullProcessImageName(
            IntPtr process, uint flags, StringBuilder exeName, ref uint size);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessInformation(
            IntPtr process, int infoClass,
            ref PROCESS_POWER_THROTTLING_STATE info, uint infoSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetProcessInformation(
            IntPtr process, int infoClass,
            ref PROCESS_POWER_THROTTLING_STATE info, uint infoSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ProcessIdToSessionId(
            uint processId, out uint sessionId);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool IsProcessCritical(
            IntPtr process, [MarshalAs(UnmanagedType.Bool)] out bool critical);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetProcessDefaultCpuSets(
            IntPtr process, [Out] uint[] ids, uint idCount, out uint requiredCount);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetSystemCpuSetInformation(
            IntPtr information, uint bufferLength, out uint returnedLength,
            IntPtr process, uint flags);

        private static void ThrowLast(string operation) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), operation);
        }

        private static long ToLong(FILETIME value) {
            return ((long)value.High << 32) | value.Low;
        }

        private static long ReadCreationTime(IntPtr process) {
            FILETIME creation, exit, kernel, user;
            if (!GetProcessTimes(process, out creation, out exit, out kernel, out user))
                ThrowLast("GetProcessTimes");
            return ToLong(creation);
        }

        private static string ReadImagePath(IntPtr process) {
            uint capacity = 32768;
            StringBuilder path = new StringBuilder((int)capacity);
            if (!QueryFullProcessImageName(process, 0, path, ref capacity))
                ThrowLast("QueryFullProcessImageName");
            return path.ToString();
        }

        private static uint[] ReadDefaultCpuSets(IntPtr process) {
            uint required;
            bool first = GetProcessDefaultCpuSets(process, null, 0, out required);
            if (first && required == 0) return new uint[0];
            if (!first && Marshal.GetLastWin32Error() != ERROR_INSUFFICIENT_BUFFER)
                ThrowLast("GetProcessDefaultCpuSets(size)");
            if (required == 0) return new uint[0];
            uint[] ids = new uint[required];
            uint actual;
            if (!GetProcessDefaultCpuSets(process, ids, required, out actual))
                ThrowLast("GetProcessDefaultCpuSets(data)");
            if (actual == ids.Length) return ids;
            uint[] trimmed = new uint[actual];
            Array.Copy(ids, trimmed, actual);
            return trimmed;
        }

        public static ProcessStateSnapshot ReadProcessState(int pid) {
            IntPtr process = OpenProcess(
                PROCESS_QUERY_LIMITED_INFORMATION, false, (uint)pid);
            if (process == IntPtr.Zero) ThrowLast("OpenProcess(query)");
            try {
                PROCESS_POWER_THROTTLING_STATE power =
                    new PROCESS_POWER_THROTTLING_STATE();
                power.Version = POWER_VERSION;
                uint size = (uint)Marshal.SizeOf(typeof(PROCESS_POWER_THROTTLING_STATE));
                if (!GetProcessInformation(
                    process, PROCESS_POWER_THROTTLING, ref power, size))
                    ThrowLast("GetProcessInformation(ProcessPowerThrottling)");
                uint sessionId;
                if (!ProcessIdToSessionId((uint)pid, out sessionId))
                    ThrowLast("ProcessIdToSessionId");
                bool critical;
                if (!IsProcessCritical(process, out critical))
                    ThrowLast("IsProcessCritical");
                ProcessStateSnapshot result = new ProcessStateSnapshot();
                result.ProcessId = pid;
                result.CreationFileTimeUtc = ReadCreationTime(process);
                result.ImagePath = ReadImagePath(process);
                result.PowerControlMask = power.ControlMask;
                result.PowerStateMask = power.StateMask;
                result.DefaultCpuSets = ReadDefaultCpuSets(process);
                result.SessionId = sessionId;
                result.IsCritical = critical;
                return result;
            } finally {
                CloseHandle(process);
            }
        }

        public static void SetPowerState(
            int pid, long expectedCreationFileTimeUtc,
            uint controlMask, uint stateMask) {
            IntPtr process = OpenProcess(
                PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_SET_INFORMATION,
                false, (uint)pid);
            if (process == IntPtr.Zero) ThrowLast("OpenProcess(set)");
            try {
                long currentCreation = ReadCreationTime(process);
                if (currentCreation != expectedCreationFileTimeUtc)
                    throw new InvalidOperationException(
                        "Process creation time changed; PID was reused.");
                PROCESS_POWER_THROTTLING_STATE power =
                    new PROCESS_POWER_THROTTLING_STATE();
                power.Version = POWER_VERSION;
                power.ControlMask = controlMask;
                power.StateMask = stateMask;
                uint size = (uint)Marshal.SizeOf(typeof(PROCESS_POWER_THROTTLING_STATE));
                if (!SetProcessInformation(
                    process, PROCESS_POWER_THROTTLING, ref power, size))
                    ThrowLast("SetProcessInformation(ProcessPowerThrottling)");
            } finally {
                CloseHandle(process);
            }
        }

        public static CpuSetRecord[] ReadCpuSetTopology() {
            uint length;
            bool probe = GetSystemCpuSetInformation(
                IntPtr.Zero, 0, out length, IntPtr.Zero, 0);
            if (probe && length == 0) return new CpuSetRecord[0];
            if (!probe && Marshal.GetLastWin32Error() != ERROR_INSUFFICIENT_BUFFER)
                ThrowLast("GetSystemCpuSetInformation(size)");
            if (length == 0) return new CpuSetRecord[0];

            IntPtr buffer = Marshal.AllocHGlobal((int)length);
            try {
                uint actual;
                if (!GetSystemCpuSetInformation(
                    buffer, length, out actual, IntPtr.Zero, 0))
                    ThrowLast("GetSystemCpuSetInformation(data)");
                List<CpuSetRecord> result = new List<CpuSetRecord>();
                int offset = 0;
                while (offset + 8 <= actual) {
                    IntPtr row = IntPtr.Add(buffer, offset);
                    int size = Marshal.ReadInt32(row, 0);
                    int type = Marshal.ReadInt32(row, 4);
                    if (size < 8 || offset + size > actual)
                        throw new InvalidOperationException(
                            "Malformed SYSTEM_CPU_SET_INFORMATION buffer.");
                    if (type == 0 && size >= 24) {
                        CpuSetRecord item = new CpuSetRecord();
                        item.Id = unchecked((uint)Marshal.ReadInt32(row, 8));
                        item.Group = unchecked((ushort)Marshal.ReadInt16(row, 12));
                        item.LogicalProcessorIndex = Marshal.ReadByte(row, 14);
                        item.CoreIndex = Marshal.ReadByte(row, 15);
                        item.LastLevelCacheIndex = Marshal.ReadByte(row, 16);
                        item.NumaNodeIndex = Marshal.ReadByte(row, 17);
                        item.EfficiencyClass = Marshal.ReadByte(row, 18);
                        byte flags = Marshal.ReadByte(row, 19);
                        item.Parked = (flags & 0x01) != 0;
                        item.Allocated = (flags & 0x02) != 0;
                        item.AllocatedToTargetProcess = (flags & 0x04) != 0;
                        item.RealTime = (flags & 0x08) != 0;
                        result.Add(item);
                    }
                    offset += size;
                }
                return result.ToArray();
            } finally {
                Marshal.FreeHGlobal(buffer);
            }
        }
    }
}
