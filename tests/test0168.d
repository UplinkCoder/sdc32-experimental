//T compiles:yes
//T has-passed:yes
//T retval:42
//? Tests TernaryOperator

import std.stdio;

int main() {
	auto s = 0;
	ubyte right = cast(ubyte) 42;
	bool b_wrong = cast(bool) 0;
	int i_wrong;
	uint ui_wrong = 0;

	bool[12] bs;
	for(int i=0;i<bs.length;i++) {
		*(&bs[0]+i) = cast(bool) (i%2);
	}

	int ret=18;

	foreach(b;bs) {
		(b||(true&&false))?(ret+=7):(ret-=3);
	}
	
	if ((i_wrong?right:b_wrong)?5:ret != 42) {
		ret=0;
	}

	return ret;
}
