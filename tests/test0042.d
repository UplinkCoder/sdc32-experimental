//T compiles:yes
//T has-passed:yes
//T dependency:test0042_import1.d
//T retval:8

import test0042_import1;

int main() {
	auto foo = new Foo();
	foo.dummy = 8;
	
	return foo.bar();
}

