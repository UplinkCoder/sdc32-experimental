//T compiles:yes
//T has-passed:yes
//T retval:42

// Tests VRP, .min and .max 

struct S {
	ubyte l = 42;
	alias l this;
	uint ui;
}

void main() {
	assert (byte.min == -128);
	assert (short.min == -32768);
	auto lmn = long.min;
	auto ulmx = ulong.max;
	S s;
	ubyte ub = s;	
	byte b = -128;
	short sh = b;
	ushort ush = ub;
	int i = b+b+b+b+b+b+b-ush;
	
	ush = cast(int) ushort.max;
	byte b2 = ub+ushort.max-short.max+short.min-128;
	return b2+128;
}

