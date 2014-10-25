//T compiles:yes
//T retval:84
//T has-passed:yes
// Tests simple literal expressions.

int main() {
	assert(0, "Regression! DOh");
	return 42 + 21 * 2;
}

