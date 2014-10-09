//T compiles:yes
//T has-passed:yes
//T retval:42
//? .length property of static arrays.
int main() {
	int[39] arr;
	auto alen = arr.length;
	
	auto stringlit = "SDC";
	auto slen = stringlit.length;

	return cast(int) (alen+slen);	
}
