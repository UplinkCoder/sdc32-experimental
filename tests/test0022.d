//T compiles:yes
//T retval:33
//T has-passed:yes
//T dependency:test0022_import1.d

import test0022_import1;

int begin() {
	return 1 + tenptr()() + addOne(&twelve) + 8;
}

int twelve() {
	return 12;
}

int main() {
	return start();
}

