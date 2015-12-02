//T compiles:yes
//T has-passed:yes
//T retval:42
//Parsing of ValueTemplateParameters
int main() {
	return vpT!42(12) + 12;
}


int vpT(int I)(int c) {
	return I - c;
}

//FIXME enable this as soon as the overload can be resolved :)
/+int vpT(string s)(int c) {
	return string.length - c;
}+/
