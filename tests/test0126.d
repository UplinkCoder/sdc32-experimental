//T compiles:yes
//T has-passed:yes
//T retval:17
// Test template argument deduction.

template Foo(T : U[], U) {
	enum Foo = U.sizeof;
}

int main() {
	return Foo!(long[]) + Foo!string + Foo!(string[]);
}

