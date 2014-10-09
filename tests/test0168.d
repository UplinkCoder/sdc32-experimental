//T compiles:yes
//T has-passed:yes
//T retval:42
//? Tests TernaryOperator

int main() {
	auto s = 0;
	ubyte right = cast(ubyte) 42;
	bool b_wrong = cast(bool) 0;
	int i_wrong;
	uint ui_wrong = 0;	
	return cast(int) (i_wrong?right:b_wrong)?ui_wrong:right;
}
