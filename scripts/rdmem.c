/* rdmem: 32-bit MMIO reader/writer, freestanding (no libc). usage: rdmem ADDR [ADDR...] | rdmem -w ADDR VAL (hex) */
typedef unsigned long u64; typedef unsigned int u32;
static long sc(long n, long a, long b, long c, long d, long e, long f) {
	register long x8 asm("x8") = n, x0 asm("x0") = a, x1 asm("x1") = b, x2 asm("x2") = c,
		x3 asm("x3") = d, x4 asm("x4") = e, x5 asm("x5") = f;
	asm volatile("svc 0" : "+r"(x0) : "r"(x8), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5) : "memory");
	return x0;
}
static void out(const char *s, int n) { sc(64, 1, (long)s, n, 0, 0, 0); }
static void hex(u64 v, int digits) { char b[16]; for (int i = digits - 1; i >= 0; i--) { b[i] = "0123456789abcdef"[v & 15]; v >>= 4; } out(b, digits); }
static u64 parse(const char *s) { u64 v = 0; if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) s += 2;
	for (; *s; s++) { char c = *s; v = v * 16 + (c <= '9' ? c - '0' : (c | 32) - 'a' + 10); } return v; }
void main2(long *sp) {
	int argc = sp[0]; char **argv = (char **)(sp + 1);
	if (argc == 4 && argv[1][0] == '-' && argv[1][1] == 'w') {
		int wfd = sc(56, -100, (long)"/dev/mem", 0x101002 /* O_RDWR|O_SYNC */, 0, 0, 0);
		if (wfd < 0) { out("open failed\n", 12); sc(93, 1, 0, 0, 0, 0, 0); }
		u64 a = parse(argv[2]) & ~3UL, base = a & ~0xfffUL;
		long m = sc(222, 0, 0x1000, 3 /* PROT_READ|PROT_WRITE */, 1, wfd, base);
		if (m < 0 && m > -4096) { out("mmap failed\n", 12); sc(93, 1, 0, 0, 0, 0, 0); }
		*(volatile u32 *)(m + (a - base)) = (u32)parse(argv[3]);
		out("0x", 2); hex(a, 8); out(" <- 0x", 6); hex((u32)parse(argv[3]), 8);
		out(" now 0x", 7); hex(*(volatile u32 *)(m + (a - base)), 8); out("\n", 1);
		sc(93, 0, 0, 0, 0, 0, 0);
	}
	int fd = sc(56, -100, (long)"/dev/mem", 0x101000 /* O_RDONLY|O_SYNC */, 0, 0, 0);
	if (fd < 0) { out("open failed\n", 12); sc(93, 1, 0, 0, 0, 0, 0); }
	for (int i = 1; i < argc; i++) {
		u64 a = parse(argv[i]) & ~3UL, base = a & ~0xfffUL;
		long m = sc(222, 0, 0x1000, 1 /* PROT_READ */, 1 /* MAP_SHARED */, fd, base);
		if (m < 0 && m > -4096) { out("mmap failed\n", 12); continue; }
		u32 v = *(volatile u32 *)(m + (a - base));
		out("0x", 2); hex(a, 8); out(" = 0x", 5); hex(v, 8); out("\n", 1);
		sc(215, m, 0x1000, 0, 0, 0, 0);
	}
	sc(93, 0, 0, 0, 0, 0, 0);
}
asm(".global _start\n_start:\n mov x0, sp\n bl main2\n");
