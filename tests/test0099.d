//T compiles:yes
//T has-passed:yes
//T retval:12

int main() {
	return Foo!Bar.baz + Foo!Fizz.get7();
}

template Foo(T) {
	T Foo;
}

struct Fizz {
	Qux!Bar buzz;
	
	auto get7() {
		return buzz.baz + 2;
	}
}

struct Bar {
	Qux!int baz = 5;
}

template Qux(T) {
	alias Qux = T;
}

